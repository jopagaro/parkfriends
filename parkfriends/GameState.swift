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
        case .parkNorth:  return "Bellwether Pond"
        case .parkCenter: return "Bellwether Fountain"
        case .citySouth:  return "City South"
        case .cityCenter: return "City Center"
        case .cityNorth:  return "Construction Edge"
        }
    }

    var zoneSubtitle: String {
        switch self {
        case .parkNorth:  return "Pond  ·  Meadow  ·  Broken Quiet"
        case .parkCenter: return "Entrance  ·  Fountain Plaza  ·  Strange Birds"
        case .citySouth:  return "Alleys  ·  Corner Store  ·  Spillover"
        case .cityCenter: return "Main Street  ·  Records  ·  Subway Gate"
        case .cityNorth:  return "Construction Zone  ·  Warehouses  ·  Deep Roots"
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

enum StoryProgress: String, Codable {
    case introCheckFountain
    case talkedToRanger
    case acceptedLostAcorn
    case foundLostAcorn
    case hazelJoined
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
    var storyProgressRaw:   String
    var quackCluesRaw:      [String]        // QuackClue.rawValue set
    var defeatedBossesRaw:  [String]        // EnemyKind.rawValue set
    var encounterClearsRaw: [String: TimeInterval]

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
        storyProgressRaw = (try? c.decode(String.self,        forKey: .storyProgressRaw)) ?? StoryProgress.introCheckFountain.rawValue
        quackCluesRaw   = try c.decode([String].self,         forKey: .quackCluesRaw)
        defeatedBossesRaw = (try? c.decode([String].self, forKey: .defeatedBossesRaw)) ?? []
        encounterClearsRaw = (try? c.decode([String: TimeInterval].self, forKey: .encounterClearsRaw)) ?? [:]
    }

    init(party: [PartyMember], activeIndex: Int, inventoryRaw: [String: Int],
         score: Int, coins: Int, enemiesDefeated: Int, zone: GameZone, storyProgressRaw: String,
         quackCluesRaw: [String], defeatedBossesRaw: [String], encounterClearsRaw: [String: TimeInterval]) {
        self.party              = party
        self.activeIndex        = activeIndex
        self.inventoryRaw       = inventoryRaw
        self.score              = score
        self.coins              = coins
        self.enemiesDefeated    = enemiesDefeated
        self.zone               = zone
        self.storyProgressRaw   = storyProgressRaw
        self.quackCluesRaw      = quackCluesRaw
        self.defeatedBossesRaw  = defeatedBossesRaw
        self.encounterClearsRaw = encounterClearsRaw
    }
}

// MARK: - GameState

@Observable
@MainActor
final class GameState {

    var party:           [PartyMember]   = PartyMember.startingParty
    var activeIndex:     Int             = 0
    var inventory:       [ItemKind: Int] = [:]
    var score:           Int             = 0
    var coins:           Int             = 0
    var enemiesDefeated: Int             = 0
    var isPaused:        Bool            = false
    var shopOpen:        Bool            = false   // corner store overlay
    var statsOpen:       Bool            = false   // party stats / inventory screen
    var queueTitleReturn: Bool           = false   // signal GameView to fade back to title
    var currentZone:     GameZone        = .parkCenter
    var storyProgress:   StoryProgress   = .introCheckFountain

    // MARK: - "Find Quack" story
    var quackClues:      Set<QuackClue>  = []

    // MARK: - Defeated bosses (no respawn)
    var defeatedBosses:  Set<EnemyKind>  = []
    var encounterClears: [String: TimeInterval] = [:]

    static let encounterRespawnInterval: TimeInterval = 180

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

    /// Number of clues found before rescue (0-7 scale for NPC hints).
    var quackClueCount: Int { quackClues.subtracting([.quackRescued]).count }

    /// Pending level-up notifications for BattleNode to display.
    var pendingLevelUps: [(name: String, level: Int, summary: String)] = []

    /// Timestamp of last attack per species (overworld attack cooldown).
    var lastAttackTime: [Species: TimeInterval] = [:]

    var activeSpecies: Species    { party[activeIndex].species }
    var activeMember: PartyMember { party[activeIndex] }
    var hasHazelJoined: Bool { party.contains { $0.species == .squirrel } }

    func advanceStory(to progress: StoryProgress) {
        storyProgress = progress
        save()
    }

    func unlockPartyMember(_ species: Species) {
        guard !party.contains(where: { $0.species == species }) else { return }
        party.append(PartyMember(species: species))
        save()
    }

    // MARK: - Overworld item use

    /// Use a consumable item from inventory.
    /// Heals the most-injured living member (prefers active).
    /// Returns `(hp, pp, memberName)` on success, nil if nothing happened.
    @discardableResult
    func useConsumable(_ kind: ItemKind) -> (hp: Int, pp: Int, name: String)? {
        guard kind.isUsable,
              (inventory[kind] ?? 0) > 0 else { return nil }

        // Antidote: cure poison on active member (or first poisoned member)
        if kind.curesPoison {
            let poisonedIdx = party.indices.first {
                party[$0].isAlive && (party[$0].isPoisoned || party[$0].isBadlyPoisoned)
            }
            guard let idx = poisonedIdx else { return nil }  // nobody needs it
            party[idx].clearStatus(.poison)
            party[idx].clearStatus(.strongPoison)
            consumeOne(kind)
            return (0, 0, party[idx].species.displayName)
        }

        // Pick the living member who needs HP most; tie-break to active
        var target = activeIndex
        if kind.healHP > 0 {
            let neediest = party.indices
                .filter { party[$0].isAlive }
                .max { (party[$0].maxHP - party[$0].hp) < (party[$1].maxHP - party[$1].hp) }
            target = neediest ?? activeIndex
        }

        // Mystery bag: random effect on active member
        if kind == .mysteryBag {
            return applyMysteryBag(target: activeIndex)
        }

        let hpBefore = party[target].hp
        let ppBefore = party[target].pp
        // Clamp megaBerry to maxHP
        let effectiveHP = kind == .megaBerry ? party[target].maxHP : kind.healHP
        party[target].hp = min(party[target].maxHP, party[target].hp + effectiveHP)
        party[target].pp = min(party[target].maxPP, party[target].pp + kind.healPP)

        let hpGained = party[target].hp - hpBefore
        let ppGained = party[target].pp - ppBefore
        guard hpGained > 0 || ppGained > 0 else { return nil }

        consumeOne(kind)
        return (hpGained, ppGained, party[target].species.displayName)
    }

    private func consumeOne(_ kind: ItemKind) {
        inventory[kind, default: 1] -= 1
        if inventory[kind] == 0 { inventory.removeValue(forKey: kind) }
    }

    private func applyMysteryBag(target: Int) -> (hp: Int, pp: Int, name: String)? {
        consumeOne(.mysteryBag)
        let roll = Int.random(in: 0...3)
        let name = party[target].species.displayName
        switch roll {
        case 0:  // decent HP heal
            let gain = min(party[target].maxHP - party[target].hp, Int.random(in: 20...50))
            party[target].hp += gain
            return (gain, 0, name)
        case 1:  // PP + small HP
            let ppGain = min(party[target].maxPP - party[target].pp, Int.random(in: 10...20))
            let hpGain = min(party[target].maxHP - party[target].hp, 8)
            party[target].pp += ppGain; party[target].hp += hpGain
            return (hpGain, ppGain, name)
        case 2:  // party small heal
            let gain = Int.random(in: 8...16)
            healParty(hp: gain)
            return (gain, 0, "everyone")
        default: // tiny individual heal
            let gain = min(party[target].maxHP - party[target].hp, Int.random(in: 5...15))
            party[target].hp += gain
            return (gain, 0, name)
        }
    }

    // MARK: - Collect

    func collect(_ kind: ItemKind) {
        inventory[kind, default: 0] += 1
        score += 10
        // Auto-advance story clues for story items
        switch kind {
        case .lostAcorn:
            if storyProgress == .acceptedLostAcorn {
                storyProgress = .foundLostAcorn
            }
        case .quackFeather:    quackClues.insert(.foundFeather)
        case .duckTag:         quackClues.insert(.raccoonDroppedTag)
        case .breadcrumbTrail: quackClues.insert(.pigeonCityClue)
        default: break
        }
        save()
    }

    // MARK: - Damage (overworld — used for environment hazards etc.)

    func takeDamage(_ amount: Int) {
        let effective = max(1, amount - party[activeIndex].def / 4)
        party[activeIndex].hp = max(0, party[activeIndex].hp - effective)
        if party[activeIndex].hp == 0 { ensureActiveMemberAlive() }
    }

    func ensureActiveMemberAlive() {
        guard !party[activeIndex].isAlive else { return }
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
        // Pigeon has a 40% chance to drop the breadcrumb trail clue
        if kind == .pigeon,
           !quackClues.contains(.pigeonCityClue),
           Double.random(in: 0...1) < 0.40 {
            collect(.breadcrumbTrail)   // collect() auto-inserts pigeonCityClue
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

    func recoverFromWipe() {
        for i in party.indices {
            party[i].hp = max(1, party[i].maxHP / 2)
            party[i].pp = max(0, party[i].maxPP / 2)
            party[i].statusEffects.removeAll()
        }
        activeIndex = party.firstIndex(where: \.isAlive) ?? 0
        save()
    }

    func markEncounterCleared(_ id: String, at now: TimeInterval = Date().timeIntervalSince1970) {
        encounterClears[id] = now
        save()
    }

    func isEncounterTemporarilyCleared(_ id: String, at now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard let clearedAt = encounterClears[id] else { return false }
        if now - clearedAt < Self.encounterRespawnInterval {
            return true
        }
        encounterClears.removeValue(forKey: id)
        save()
        return false
    }

    func pruneExpiredEncounterClears(at now: TimeInterval = Date().timeIntervalSince1970) {
        let before = encounterClears.count
        encounterClears = encounterClears.filter { now - $0.value < Self.encounterRespawnInterval }
        if encounterClears.count != before {
            save()
        }
    }

    var isGameOver: Bool { party.allSatisfy { $0.hp == 0 } }

    // MARK: - Reset

    func reset() {
        party = PartyMember.startingParty
        activeIndex = 0
        inventory.removeAll()
        score = 0
        coins = 0
        enemiesDefeated = 0
        isPaused          = false
        shopOpen          = false
        statsOpen         = false
        queueTitleReturn  = false
        lastAttackTime.removeAll()
        currentZone = .parkCenter
        storyProgress = .introCheckFountain
        pendingLevelUps.removeAll()
        quackClues.removeAll()
        defeatedBosses.removeAll()
        encounterClears.removeAll()
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
            storyProgressRaw:   storyProgress.rawValue,
            quackCluesRaw:      quackClues.map(\.rawValue),
            defeatedBossesRaw:  defeatedBosses.map(\.rawValue),
            encounterClearsRaw: encounterClears
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
        storyProgress   = StoryProgress(rawValue: data.storyProgressRaw) ?? .introCheckFountain
        quackClues      = Set(data.quackCluesRaw.compactMap { QuackClue(rawValue: $0) })
        defeatedBosses  = Set(data.defeatedBossesRaw.compactMap { EnemyKind(rawValue: $0) })
        encounterClears = data.encounterClearsRaw
        pruneExpiredEncounterClears()
    }

    var hasSave: Bool {
        UserDefaults.standard.data(forKey: Self.saveKey) != nil
    }

    func deleteSave() {
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
    }

    // MARK: - Narrative presentation

    var storyArcTitle: String {
        if quackRescued {
            return "The Park Is Listening"
        }

        switch currentZone {
        case .parkCenter:
            return hasHazelJoined ? "Act I · The Park Is Wrong" : "Prologue"
        case .parkNorth:
            return "Act I · The Park Is Wrong"
        case .citySouth, .cityCenter:
            return "Act II · The City Is Connected"
        case .cityNorth:
            return "Act III · The Park Under The Park"
        }
    }

    var currentObjectiveText: String {
        if quackRescued {
            return "Objective: Follow the roots of the disturbance and protect the park."
        }

        switch currentZone {
        case .parkCenter:
            switch storyProgress {
            case .introCheckFountain:
                return "Objective: Talk to the ranger and check the fountain."
            case .talkedToRanger:
                return "Objective: Find out why Hazel is shouting by the fountain tree."
            case .acceptedLostAcorn:
                return "Objective: Find Hazel's lost acorn near the trash cans."
            case .foundLostAcorn:
                return "Objective: Return Steven the acorn to Hazel."
            case .hazelJoined:
                return "Objective: Follow Hazel north toward the pond."
            }
        case .parkNorth:
            if !quackClues.contains(.foundFeather) {
                return "Objective: Search the pond for what scared the park's missing duck."
            }
            return "Objective: Bring the feather back through the park and ask who saw Quack last."
        case .citySouth:
            return "Objective: Track the breadcrumb trail through the alleys and chip bags."
        case .cityCenter:
            return "Objective: Push toward the records district and find out why the city paperwork feels wrong."
        case .cityNorth:
            return "Objective: Reach the construction site and uncover what woke up beneath the concrete."
        }
    }

    var storyBeatText: String {
        if quackRescued {
            return "The park is not lashing out anymore. It is waiting to see if anyone finally understood it."
        }

        switch currentZone {
        case .parkCenter:
            switch storyProgress {
            case .introCheckFountain:
                return "The ranger is trying to sound official about the weirdness, which only makes the goose warning worse."
            case .talkedToRanger:
                return "The fountain plaza should feel normal. Instead a squirrel is treating it like an emergency desk."
            case .acceptedLostAcorn:
                return "Hazel's missing reserve acorn sounds small until you notice the pigeons are acting like organized thieves."
            case .foundLostAcorn:
                return "One acorn recovered. One very suspicious pattern of animal behavior confirmed."
            case .hazelJoined:
                return "Hazel joining makes the park feel less random and more like it is trying to recruit help."
            }
        case .parkNorth:
            if !quackClues.contains(.foundFeather) {
                return "The pond should be loud. Instead it feels paused, like the whole north side is listening for something underground."
            }
            return "A single feather turns the problem into a trail. Someone, or something, pushed the park's panic out toward the city."
        case .citySouth:
            return "The alleys smell like fryer oil and wet cardboard. Even here, the park's trouble has already spilled past the fence."
        case .cityCenter:
            return "Downtown acts like paperwork can explain anything. The older the records get, the stranger that confidence feels."
        case .cityNorth:
            return "Concrete, fencing, floodlights, and roots too thick to belong under any modern street. This is where the city started digging into the wrong memory."
        }
    }

    var storyPanelSignature: String {
        [storyArcTitle, currentZone.rawValue, currentObjectiveText, storyBeatText].joined(separator: "|")
    }

    var zoneArrivalText: String {
        switch currentZone {
        case .parkCenter:
            return "Bellwether Park feels friendly until you stop and notice how carefully everything is staring back."
        case .parkNorth:
            return "The pond air is wrong. Even the quiet feels territorial."
        case .citySouth:
            return "City South catches whatever the park and downtown both fail to hold on to."
        case .cityCenter:
            return "The city center still believes lines on paper matter more than roots under pavement."
        case .cityNorth:
            return "The construction fence hides machinery, old maps, and a very bad city decision."
        }
    }

    var shopNarrativeTitle: String {
        switch currentZone {
        case .parkCenter, .parkNorth:
            return "South Gate Supplies"
        case .citySouth:
            return "Corner Store"
        case .cityCenter:
            return "Records District Mini Mart"
        case .cityNorth:
            return "Worker's Canteen"
        }
    }

    var shopNarrativeText: String {
        switch currentZone {
        case .parkCenter, .parkNorth:
            return "The clerk keeps the radio low. Everyone has heard the geese already."
        case .citySouth:
            return "Open late. No refunds. The owner pretends not to notice which chip bags keep moving on their own."
        case .cityCenter:
            return "Someone behind the counter is tracking city rumors with a marker on the cigarette cabinet."
        case .cityNorth:
            return "Coffee, batteries, headache medicine. Everything here feels priced for people pretending the drilling is normal."
        }
    }
}
