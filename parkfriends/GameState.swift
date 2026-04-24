import Foundation
import Observation

// MARK: - Zone (Part 1.1 — vertical world stack)

enum GameZone: String, CaseIterable, Sendable {
    case parkNorth
    case parkCenter
    case citySouth
    case cityCenter
    case cityNorth
}

extension GameZone: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        switch s {
        case "park": self = .parkCenter
        case "city": self = .cityCenter
        default:
            self = GameZone(rawValue: s) ?? .parkCenter
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

extension GameZone {
    var boundsSize: CGSize {
        switch self {
        case .parkNorth:  return GameConstants.parkNorthWorldSize
        case .parkCenter: return GameConstants.parkCenterWorldSize
        case .citySouth:  return GameConstants.citySouthWorldSize
        case .cityCenter: return GameConstants.cityCenterWorldSize
        case .cityNorth:  return GameConstants.cityNorthWorldSize
        }
    }

    var displayTitle: String {
        switch self {
        case .parkNorth:  return "Zone 1A · Park North"
        case .parkCenter: return "Zone 1B · Park Center"
        case .citySouth:  return "Zone 2A · City South"
        case .cityCenter: return "Zone 2 · City Center"
        case .cityNorth:  return "Zone 3 · City North"
        }
    }

    var zoneSubtitle: String {
        switch self {
        case .parkNorth:  return "The Pond  ·  Ruins  ·  Meadow"
        case .parkCenter: return "The Heart of the Park"
        case .citySouth:  return "Alleys  ·  Corner Store  ·  Plaza"
        case .cityCenter: return "Main Street  ·  Apartments  ·  Subway"
        case .cityNorth:  return "Construction Zone  ·  Warehouses"
        }
    }
}

// MARK: - Quack story progress

/// Milestone keys for the "Find Quack" story arc.
enum QuackClue: String, CaseIterable, Codable {
    case visitedNorthPond   // player entered Park North (auto-set)
    case foundFeather       // picked up Quack's feather near the empty pond
    case childSawChase      // the child NPC mentioned seeing Quack chased
    case joggerSawCity      // the jogger saw Quack heading toward the city
    case raccoonDroppedTag  // raccoon dropped Quack's ID tag
    case pigeonCityClue     // pigeon area breadcrumb clue found in City South
    case workerSawDuck      // construction worker spotted Quack in City North
    case quackRescued       // party rescued Quack!
}

// MARK: - Save data envelope

private struct SaveData: Codable {
    var party:              [PartyMember]
    var activeIndex:        Int
    var inventoryRaw:       [String: Int]   // ItemKind.rawValue → count
    var score:              Int
    var coins:              Int
    var enemiesDefeated:    Int
    var zone:               GameZone
    var quackCluesRaw:      [String]        // QuackClue.rawValue set
    var defeatedBossesRaw:  [String]        // EnemyKind.rawValue set

    // Custom decoder so old saves missing defeatedBossesRaw still load cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        party           = try c.decode([PartyMember].self,    forKey: .party)
        activeIndex     = try c.decode(Int.self,              forKey: .activeIndex)
        inventoryRaw    = try c.decode([String: Int].self,    forKey: .inventoryRaw)
        score           = try c.decode(Int.self,              forKey: .score)
        coins           = try c.decode(Int.self,              forKey: .coins)
        enemiesDefeated = try c.decode(Int.self,              forKey: .enemiesDefeated)
        zone            = try c.decode(GameZone.self,         forKey: .zone)
        quackCluesRaw   = try c.decode([String].self,         forKey: .quackCluesRaw)
        defeatedBossesRaw = (try? c.decode([String].self, forKey: .defeatedBossesRaw)) ?? []
    }

    init(party: [PartyMember], activeIndex: Int, inventoryRaw: [String: Int],
         score: Int, coins: Int, enemiesDefeated: Int, zone: GameZone,
         quackCluesRaw: [String], defeatedBossesRaw: [String]) {
        self.party              = party
        self.activeIndex        = activeIndex
        self.inventoryRaw       = inventoryRaw
        self.score              = score
        self.coins              = coins
        self.enemiesDefeated    = enemiesDefeated
        self.zone               = zone
        self.quackCluesRaw      = quackCluesRaw
        self.defeatedBossesRaw  = defeatedBossesRaw
    }
}

// MARK: - GameState

@Observable
@MainActor
final class GameState {

    var party:           [PartyMember]   = PartyMember.defaultParty
    var activeIndex:     Int             = 0
    var inventory:       [ItemKind: Int] = [:]
    var score:           Int             = 0
    var coins:           Int             = 0
    var enemiesDefeated: Int             = 0
    var isPaused:        Bool            = false
    var shopOpen:        Bool            = false   // corner store overlay
    var statsOpen:       Bool            = false   // party stats / inventory screen
    var currentZone:     GameZone        = .parkCenter

    // MARK: - "Find Quack" story
    var quackClues:      Set<QuackClue>  = []

    // MARK: - Defeated bosses (no respawn)
    var defeatedBosses:  Set<EnemyKind>  = []

    func defeatBoss(_ kind: EnemyKind) {
        defeatedBosses.insert(kind)
        score += kind.defeatScore
        gainExp(kind.expReward)
        let rawCoins = Int.random(in: kind.coinRange)
        coins += rawCoins
        if let drop = kind.rollDrop() { inventory[drop, default: 0] += 1 }
        enemiesDefeated += 1
        save()
    }

    var quackRescued: Bool { quackClues.contains(.quackRescued) }

    func addClue(_ clue: QuackClue) {
        quackClues.insert(clue)
        save()
    }

    /// Number of clues found before rescue (0-5 scale for NPC hints).
    var quackClueCount: Int { quackClues.subtracting([.quackRescued]).count }

    /// Pending level-up notifications for BattleNode to display.
    var pendingLevelUps: [(name: String, level: Int, summary: String)] = []

    /// Timestamp of last attack per species (overworld attack cooldown).
    var lastAttackTime: [Species: TimeInterval] = [:]

    var activeSpecies: Species    { party[activeIndex].species }
    var activeMember: PartyMember { party[activeIndex] }

    // MARK: - Collect

    func collect(_ kind: ItemKind) {
        inventory[kind, default: 0] += 1
        score += 10
        // Auto-advance story clues for story items
        switch kind {
        case .quackFeather:    quackClues.insert(.foundFeather)
        case .duckTag:         quackClues.insert(.raccoonDroppedTag)
        case .breadcrumbTrail: quackClues.insert(.pigeonCityClue)
        default: break
        }
    }

    // MARK: - Damage (overworld — used for environment hazards etc.)

    func takeDamage(_ amount: Int) {
        let effective = max(1, amount - party[activeIndex].def / 4)
        party[activeIndex].hp = max(0, party[activeIndex].hp - effective)
        if party[activeIndex].hp == 0 { autoSwitchActive() }
    }

    private func autoSwitchActive() {
        for step in 1..<party.count {
            let idx = (activeIndex + step) % party.count
            if party[idx].hp > 0 { activeIndex = idx; return }
        }
    }

    // MARK: - EXP & Level-up

    /// Award EXP to all living members, trigger level-ups, queue notifications.
    func gainExp(_ amount: Int) {
        for i in party.indices {
            guard party[i].isAlive else { continue }
            party[i].exp += amount
            while party[i].exp >= party[i].expToNext {
                party[i].exp -= party[i].expToNext
                let summary = party[i].applyLevelUp()
                pendingLevelUps.append((
                    name:    party[i].species.displayName,
                    level:   party[i].level,
                    summary: summary
                ))
            }
        }
    }

    // MARK: - Enemy defeat

    func defeatEnemy(kind: EnemyKind, coinMultiplier: Double = 1.0) {
        enemiesDefeated += 1
        score += kind.defeatScore
        gainExp(kind.expReward)
        let rawCoins = Int.random(in: kind.coinRange)
        coins += max(0, Int(Double(rawCoins) * coinMultiplier))
        if let drop = kind.rollDrop() {
            collect(drop)
        }
        // Raccoon has a 35% chance to drop Quack's Duck Tag (story clue)
        if kind == .raccoon,
           !quackClues.contains(.raccoonDroppedTag),
           Double.random(in: 0...1) < 0.35 {
            collect(.duckTag)   // collect() auto-inserts raccoonDroppedTag clue
        }
    }

    // MARK: - Overworld attack helpers

    func attackCharge(now: TimeInterval) -> Double {
        let cooldown = activeSpecies.attackCooldown
        let last = lastAttackTime[activeSpecies] ?? 0
        return min((now - last) / cooldown, 1.0)
    }

    func recordAttack(now: TimeInterval) {
        lastAttackTime[activeSpecies] = now
    }

    // MARK: - Party helpers

    func healParty(hp: Int = 0, pp: Int = 0) {
        for i in party.indices {
            if hp > 0 { party[i].hp = min(party[i].maxHP, party[i].hp + hp) }
            if pp > 0 { party[i].pp = min(party[i].maxPP, party[i].pp + pp) }
        }
    }

    func fullHeal() {
        for i in party.indices {
            party[i].hp = party[i].maxHP
            party[i].pp = party[i].maxPP
            party[i].statusEffects.removeAll()
        }
    }

    var isGameOver: Bool { party.allSatisfy { $0.hp == 0 } }

    // MARK: - Reset

    func reset() {
        party = PartyMember.defaultParty
        activeIndex = 0
        inventory.removeAll()
        score = 0
        coins = 0
        enemiesDefeated = 0
        isPaused  = false
        shopOpen  = false
        statsOpen = false
        lastAttackTime.removeAll()
        currentZone = .parkCenter
        pendingLevelUps.removeAll()
        quackClues.removeAll()
        defeatedBosses.removeAll()
    }

    // MARK: - Save / Load

    private static let saveKey = "parkfriends.v2.save"

    func save() {
        let raw = Dictionary(uniqueKeysWithValues: inventory.map { ($0.key.rawValue, $0.value) })
        let data = SaveData(
            party:              party,
            activeIndex:        min(activeIndex, party.count - 1),
            inventoryRaw:       raw,
            score:              score,
            coins:              coins,
            enemiesDefeated:    enemiesDefeated,
            zone:               currentZone,
            quackCluesRaw:      quackClues.map(\.rawValue),
            defeatedBossesRaw:  defeatedBosses.map(\.rawValue)
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }

    func load() {
        guard let blob = UserDefaults.standard.data(forKey: Self.saveKey),
              let data = try? JSONDecoder().decode(SaveData.self, from: blob) else { return }
        party        = data.party
        activeIndex  = min(data.activeIndex, data.party.count - 1)
        inventory    = Dictionary(uniqueKeysWithValues: data.inventoryRaw.compactMap { k, v in
            ItemKind(rawValue: k).map { ($0, v) }
        })
        score           = data.score
        coins           = data.coins
        enemiesDefeated = data.enemiesDefeated
        currentZone     = data.zone
        quackClues      = Set(data.quackCluesRaw.compactMap { QuackClue(rawValue: $0) })
        defeatedBosses  = Set(data.defeatedBossesRaw.compactMap { EnemyKind(rawValue: $0) })
    }

    var hasSave: Bool {
        UserDefaults.standard.data(forKey: Self.saveKey) != nil
    }

    func deleteSave() {
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
    }
}
