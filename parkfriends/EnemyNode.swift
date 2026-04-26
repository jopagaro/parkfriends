import SpriteKit

// MARK: - Enemy action primitives (§5.1)

enum EnemyAction: Sendable {
    // Physical
    case attack(mult: Double, status: StatusEffect? = nil, statusChance: Double = 0)
    case aoeAttack(mult: Double)
    case flatDamage(Int, ignoresDEF: Bool = false)
    case aoeFlat(Int)
    // Status
    case aoeStatus(StatusEffect, chance: Double)
    // Resource / field effects
    case steal
    case selfBuff(atk: Int = 0, def: Int = 0, spd: Int = 0, turns: Int = 2)
    case targetDebuff(atk: Int = 0, def: Int = 0, turns: Int = 2)
    case selfHeal(Int)
    case selfDamage(Int)
    case halfDamageLecture          // sternAdult: target half-dmg for 2 turns
    case charge                     // ranger Procedure: next turn ATK ×2
    case givePlayerItem             // vending Actually Works
    case coinDebuff                 // vending Price Hike
    case enemyFlee                  // skate Just Leaves (30% chance)
    case nothing
}

struct EnemyActionChoice: Sendable {
    let weight: Int
    let action: EnemyAction
    let name: String
    let message: String
}

// MARK: - EnemyKind

enum EnemyKind: String, CaseIterable, Codable, Sendable {
    // Zone 1 — Park
    case pigeon, goose, raccoon, wasp, ranger, sternAdult
    // Zone 1B mid-boss
    case flockLeader
    // Zone 2 — City
    case vendingMachine, skateboardKid
    // Bosses
    case grandGooseGerald, officerGrumble, foremanRex

    var displayName: String {
        switch self {
        case .pigeon:           "City Pigeon"
        case .goose:            "Territorial Goose"
        case .raccoon:          "Shifty Raccoon"
        case .wasp:             "Angry Wasp"
        case .ranger:           "Park Ranger"
        case .sternAdult:       "Stern Adult"
        case .flockLeader:      "Pigeon Flock Leader"
        case .vendingMachine:   "Possessed Vending Machine"
        case .skateboardKid:    "Skateboard Kid"
        case .grandGooseGerald: "Grand Goose Gerald"
        case .officerGrumble:   "Officer Grumble"
        case .foremanRex:       "Foreman Rex"
        }
    }

    // MARK: - Battle Stats (§5.1)

    var maxHP: Int {
        switch self {
        case .pigeon:           22
        case .goose:            48
        case .raccoon:          32
        case .wasp:             14
        case .ranger:           38
        case .sternAdult:       30
        case .flockLeader:      80
        case .vendingMachine:   60
        case .skateboardKid:    26
        case .grandGooseGerald: 140
        case .officerGrumble:   180
        case .foremanRex:       240
        }
    }

    var attackPower: Int {
        switch self {
        case .pigeon:           6
        case .goose:            18
        case .raccoon:          11
        case .wasp:             9
        case .ranger:           15
        case .sternAdult:       12
        case .flockLeader:      14
        case .vendingMachine:   13
        case .skateboardKid:    10
        case .grandGooseGerald: 22
        case .officerGrumble:   20
        case .foremanRex:       26
        }
    }

    var defense: Int {
        switch self {
        case .pigeon:           2
        case .goose:            10
        case .raccoon:          5
        case .wasp:             1
        case .ranger:           9
        case .sternAdult:       7
        case .flockLeader:      6
        case .vendingMachine:   14
        case .skateboardKid:    4
        case .grandGooseGerald: 12
        case .officerGrumble:   16
        case .foremanRex:       20
        }
    }

    var battleSPD: Int {
        switch self {
        case .pigeon:           14
        case .goose:            8
        case .raccoon:          16
        case .wasp:             22
        case .ranger:           6
        case .sternAdult:       5
        case .flockLeader:      12
        case .vendingMachine:   2
        case .skateboardKid:    20
        case .grandGooseGerald: 10
        case .officerGrumble:   7
        case .foremanRex:       5
        }
    }

    var battleLCK: Int {
        switch self {
        case .pigeon:           8
        case .goose:            4
        case .raccoon:          14
        case .wasp:             6
        case .ranger:           7
        case .sternAdult:       5
        case .flockLeader:      10
        case .vendingMachine:   3
        case .skateboardKid:    12
        case .grandGooseGerald: 6
        case .officerGrumble:   10
        case .foremanRex:       4
        }
    }

    var expReward: Int {
        switch self {
        case .pigeon:           12
        case .goose:            38
        case .raccoon:          28
        case .wasp:             14
        case .ranger:           32
        case .sternAdult:       22
        case .flockLeader:      80
        case .vendingMachine:   45
        case .skateboardKid:    20
        case .grandGooseGerald: 200
        case .officerGrumble:   350
        case .foremanRex:       600
        }
    }

    var defeatScore: Int {
        switch self {
        case .pigeon:           15
        case .goose:            55
        case .raccoon:          42
        case .wasp:             18
        case .ranger:           50
        case .sternAdult:       32
        case .flockLeader:      110
        case .vendingMachine:   60
        case .skateboardKid:    28
        case .grandGooseGerald: 300
        case .officerGrumble:   500
        case .foremanRex:       900
        }
    }

    var coinRange: ClosedRange<Int> {
        switch self {
        case .pigeon:           1...3
        case .goose:            4...8
        case .raccoon:          3...6
        case .wasp:             0...2
        case .ranger:           5...10
        case .sternAdult:       3...7
        case .flockLeader:      12...20
        case .vendingMachine:   8...15
        case .skateboardKid:    2...5
        case .grandGooseGerald: 30...45
        case .officerGrumble:   40...60
        case .foremanRex:       80...120
        }
    }

    var isBoss: Bool {
        switch self {
        case .grandGooseGerald, .officerGrumble, .foremanRex: true
        default: false
        }
    }

    // MARK: - Boss intro presentation

    var bossEmoji: String {
        switch self {
        case .grandGooseGerald: "🦢"
        case .officerGrumble:   "👮"
        case .foremanRex:       "👷"
        default: ""
        }
    }

    /// Short dramatic subtitle shown on the boss title card.
    var bossIntroTitle: String {
        switch self {
        case .grandGooseGerald: "Ruler of the Pond"
        case .officerGrumble:   "12 Years on the Force. Zero Tolerance for Fun."
        case .foremanRex:       "The Man Behind the Construction"
        default: ""
        }
    }

    /// One-line flavor text shown beneath the title card.
    var bossIntroFlavor: String {
        switch self {
        case .grandGooseGerald: "Gerald didn't ask to be this way. The pond just makes him this way."
        case .officerGrumble:   "He has a clipboard. He has been waiting to use it."
        case .foremanRex:       "He doesn't know what's under the site. He doesn't care."
        default: ""
        }
    }

    var bossPhase2HPThreshold: Int {
        switch self {
        case .grandGooseGerald: 80
        case .officerGrumble:   Int(Double(maxHP) * 0.60)
        case .foremanRex:       Int(Double(maxHP) * 0.50)
        default: 0
        }
    }

    // MARK: - Immunities

    var immunities: Set<StatusEffect> {
        switch self {
        case .goose, .grandGooseGerald:
            [.sleep, .confusion]
        case .foremanRex:
            []
        default:
            []
        }
    }

    // MARK: - Battle Background

    var battleBackground: BattleBackground {
        switch self {
        case .goose, .pigeon, .flockLeader, .grandGooseGerald:
            .fountain
        case .raccoon, .wasp:
            .forest
        case .ranger, .foremanRex:
            .grass
        case .sternAdult, .vendingMachine, .skateboardKid,
             .officerGrumble:
            .cityStreet
        }
    }

    // MARK: - Drop table (§5.1)

    var dropTable: [(ItemKind, Double)] {
        switch self {
        case .pigeon:
            [(.feather, 0.80), (.staleChip, 0.20)]
        case .goose:
            [(.gooseFeather, 0.70), (.parkPermit, 0.05)]
        case .raccoon:
            [(.shinyThing, 0.90)]
        case .wasp:
            [(.stingSac, 0.50)]
        case .ranger:
            [(.parkWhistle, 0.40), (.officialForm, 0.60)]
        case .sternAdult:
            [(.granolaBar, 0.60), (.businessCard, 0.40)]
        case .flockLeader:
            [(.parkToken, 1.0)]
        case .vendingMachine:
            [(.warmCola, 0.80), (.machinePart, 0.20)]
        case .skateboardKid:
            [(.energyDrink, 0.70), (.oldSticker, 0.30)]
        case .grandGooseGerald:
            [(.geraldSash, 1.0), (.parkNewspaper, 1.0)]
        case .officerGrumble:
            [(.officerBadge, 1.0), (.cityHallKey, 1.0)]
        case .foremanRex:
            [(.constructionBadge, 1.0), (.workerThermos, 1.0)]
        }
    }

    func rollDrop() -> ItemKind? {
        for (item, chance) in dropTable {
            if Double.random(in: 0...1) < chance { return item }
        }
        return nil
    }

    // MARK: - Overworld

    var speed: CGFloat {
        switch self {
        case .ranger:           80
        case .sternAdult:       70
        case .wasp:             130
        case .goose:            90
        case .raccoon:          95
        case .pigeon:           110
        case .flockLeader:      100
        case .vendingMachine:   20
        case .skateboardKid:    120
        case .grandGooseGerald: 60
        case .officerGrumble:   55
        case .foremanRex:       40
        }
    }

    var visionRadius: CGFloat {
        switch self {
        case .ranger:           180
        case .sternAdult:       150
        case .wasp:             120
        case .goose:            200
        case .raccoon:          140
        case .pigeon:           100
        case .flockLeader:      180
        case .vendingMachine:   60
        case .skateboardKid:    100
        case .grandGooseGerald: 240
        case .officerGrumble:   200
        case .foremanRex:       160
        }
    }

    // MARK: - Weighted Actions (§5.1)

    struct ActionContext {
        let playerHPFraction: Double
        let hasStolenItem: Bool
        let isCharging: Bool
        let bossPhase: Int
        let turn: Int
        let wingBeatLastTurn: Int
    }

    func selectAction(_ ctx: ActionContext) -> EnemyActionChoice {
        let pool = buildPool(ctx)
        let total = pool.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return pool[0] }
        var roll = Int.random(in: 0..<total)
        for choice in pool {
            roll -= choice.weight
            if roll < 0 { return choice }
        }
        return pool[0]
    }

    private func buildPool(_ ctx: ActionContext) -> [EnemyActionChoice] {
        switch self {

        // ── City Pigeon ────────────────────────────────────────────────────────
        case .pigeon, .flockLeader:
            let flockATK = (self == .flockLeader) ? 1.3 : 1.0
            return [
                .init(weight: 60, action: .attack(mult: 1.0 * flockATK, status: .distraction, statusChance: 0.5),
                      name: "Peck", message: "pecks relentlessly!"),
                .init(weight: 20, action: .aoeAttack(mult: 0.6 * flockATK),
                      name: "Scatter", message: "the flock scatters in all directions!"),
                .init(weight: 10, action: .nothing,
                      name: "Stare", message: "just stares. Deeply."),
                .init(weight: 10, action: .selfBuff(spd: 3, turns: 2),
                      name: "Flap Panic", message: "flaps into high gear!"),
            ]

        // ── Territorial Goose ──────────────────────────────────────────────────
        case .goose:
            let canWingBeat = ctx.turn - ctx.wingBeatLastTurn >= 3
            return [
                .init(weight: 45, action: .attack(mult: 1.2, status: .embarrassment, statusChance: 0.30),
                      name: "Honk Strike", message: "launches a devastating honk strike!"),
                .init(weight: canWingBeat ? 25 : 0, action: .attack(mult: 1.5),
                      name: "Wing Beat", message: "delivers a bone-rattling wing beat!"),
                .init(weight: !canWingBeat ? 25 : 0, action: .aoeStatus(.distraction, chance: 0.4),
                      name: "Chase", message: "aggressively honks at everyone!"),
                .init(weight: 20, action: .selfBuff(atk: 3, turns: 2),
                      name: "Territorial Hiss", message: "asserts territorial dominance!"),
                .init(weight: 10, action: .attack(mult: 0.8, status: .distraction, statusChance: 0.6),
                      name: "Chase", message: "honks directly at you. Personally."),
            ]

        // ── Shifty Raccoon ─────────────────────────────────────────────────────
        case .raccoon:
            let rummageWeight = ctx.playerHPFraction < 0.30 ? 45 : 25
            let eatWeight     = ctx.hasStolenItem ? 5 : 0
            return [
                .init(weight: 35, action: .attack(mult: 0.9),
                      name: "Scratch", message: "scratches with suspicious purpose!"),
                .init(weight: rummageWeight, action: .steal,
                      name: "Rummage", message: "digs through your stuff!"),
                .init(weight: 20, action: .aoeAttack(mult: 0.5),
                      name: "Scatter Trash", message: "flings garbage everywhere!"),
                .init(weight: 15, action: .selfBuff(def: 5, turns: 1),
                      name: "Dodge", message: "becomes suspiciously evasive!"),
                .init(weight: eatWeight, action: .selfHeal(12),
                      name: "Eating", message: "eats your stolen item. Looks smug."),
            ]

        // ── Park Ranger ────────────────────────────────────────────────────────
        case .ranger:
            let chargeAction: EnemyAction = ctx.isCharging
                ? .attack(mult: 2.0, status: .embarrassment, statusChance: 0.5)
                : .charge
            let chargeMsg = ctx.isCharging ? "issues the citation! (charged)" : "is filling out a form…"
            return [
                .init(weight: 40, action: .attack(mult: 1.0, status: .embarrassment, statusChance: 0.6),
                      name: "Citation", message: "issues a citation with authority!"),
                .init(weight: 25, action: .selfBuff(atk: 4, turns: 1),
                      name: "Radio for Backup", message: "radios for backup! (ATK buffed)"),
                .init(weight: 20, action: chargeAction,
                      name: "Procedure", message: chargeMsg),
                .init(weight: 10, action: .aoeStatus(.fear, chance: 0.30),
                      name: "Warning", message: "issues a formal warning!"),
                .init(weight: 5, action: .givePlayerItem,
                      name: "Actually Nice", message: "is… actually being helpful? Ranger looks conflicted."),
            ]

        // ── Stern Adult ────────────────────────────────────────────────────────
        case .sternAdult:
            return [
                .init(weight: 35, action: .aoeStatus(.embarrassment, chance: 1.0),
                      name: "Disapproving Look", message: "looks at you with profound disappointment."),
                .init(weight: 30, action: .halfDamageLecture,
                      name: "Lecture", message: "begins to explain why you're wrong. Extensively."),
                .init(weight: 20, action: .flatDamage(8, ignoresDEF: true),
                      name: "Passive Comment", message: "asks \'Is that what you\'re wearing?\' (8 psychic damage)"),
                .init(weight: 15, action: .aoeStatus(.fear, chance: 0.50),
                      name: "Sigh", message: "sighs. The sigh echoes."),
            ]

        // ── Angry Wasp ─────────────────────────────────────────────────────────
        case .wasp:
            return [
                .init(weight: 55, action: .attack(mult: 1.0, status: .poison, statusChance: 0.25),
                      name: "Sting", message: "stings! Poison chance!"),
                .init(weight: 30, action: .flatDamage(attackPower / 2, ignoresDEF: true),
                      name: "Dive Bomb", message: "dive bombs — ignores your defense!"),
                .init(weight: 15, action: .aoeStatus(.fear, chance: 0.20),
                      name: "Intimidate", message: "swarms menacingly!"),
            ]

        // ── Possessed Vending Machine ──────────────────────────────────────────
        case .vendingMachine:
            return [
                .init(weight: 35, action: .attack(mult: 1.2),
                      name: "Dispense Projectile", message: "hurls a projectile at you!"),
                .init(weight: 25, action: .aoeFlat(6),
                      name: "Static Shock", message: "BZZZT. 6 flat damage, everyone."),
                .init(weight: 20, action: .coinDebuff,
                      name: "Price Hike", message: "adjusts pricing dynamically. Your coins this battle are halved."),
                .init(weight: 15, action: .selfDamage(8),
                      name: "Malfunction", message: "BRRZZZT. It damaged itself? BRRZZZT."),
                .init(weight: 5, action: .givePlayerItem,
                      name: "Actually Works", message: "dispenses something. A lukewarm sports drink, but still."),
            ]

        // ── Skateboard Kid ─────────────────────────────────────────────────────
        case .skateboardKid:
            return [
                .init(weight: 40, action: .attack(mult: 1.0),
                      name: "Kickflip", message: "kickflips directly into your face. Cannot miss."),
                .init(weight: 25, action: .attack(mult: 1.5),
                      name: "Grind", message: "grinds. Deals bonus damage if they went first."),
                .init(weight: 20, action: .selfDamage(4),
                      name: "Bail", message: "bails. Eats pavement. Still here though."),
                .init(weight: 15, action: .enemyFlee,
                      name: "Just Leaves", message: "may just… leave."),
            ]

        // ── Grand Goose Gerald (Boss) ──────────────────────────────────────────
        case .grandGooseGerald:
            if ctx.bossPhase == 2 {
                return [
                    .init(weight: 40, action: .aoeAttack(mult: 1.4),
                          name: "Chaos Honk", message: "HONK. (The dialogue box just says HONK.)"),
                    .init(weight: 35, action: .selfBuff(atk: 2, turns: 999),
                          name: "Unrelenting", message: "Gerald takes an extra action!"),
                    .init(weight: 25, action: .aoeFlat(10),
                          name: "Desperate Flap", message: "flaps with absolute desperation — ignores DEF!"),
                ]
            } else {
                return [
                    .init(weight: 40, action: .aoeAttack(mult: 0.8),
                          name: "Honk Storm", message: "releases a terrifying honk storm!"),
                    .init(weight: 35, action: .selfBuff(atk: 4, turns: 1),
                          name: "Neck Extend", message: "neck extends menacingly (+4 ATK next turn)"),
                    .init(weight: 25, action: .attack(mult: 1.2, status: .embarrassment, statusChance: 0.4),
                          name: "Territorial", message: "honks territorially. It's Gerald's park."),
                ]
            }

        // ── Officer Grumble (Boss) ─────────────────────────────────────────────
        case .officerGrumble:
            if ctx.bossPhase == 2 {
                return [
                    .init(weight: 40, action: .flatDamage(Int(Double(attackPower) * 1.8), ignoresDEF: false),
                          name: "Donut Smash", message: "This. Is. Personal."),
                    .init(weight: 35, action: .selfBuff(atk: 5, def: 3, turns: 999),
                          name: "Full Authority", message: "invokes Full Authority!"),
                    .init(weight: 25, action: .aoeStatus(.embarrassment, chance: 1.0),
                          name: "Report Filed", message: "He's filing a report. Even if you win, the report exists."),
                ]
            } else {
                return [
                    .init(weight: 40, action: .attack(mult: 1.0, status: .embarrassment, statusChance: 0.6),
                          name: "By The Book", message: "By the book. Citation issued."),
                    .init(weight: 35, action: .selfBuff(atk: 3, turns: 2),
                          name: "Backup Call", message: "calls for backup!"),
                    .init(weight: 25, action: .aoeStatus(.fear, chance: 0.25),
                          name: "Shout", message: "shouts with institutional authority!"),
                ]
            }

        // ── Foreman Rex (Boss) ─────────────────────────────────────────────────
        case .foremanRex:
            if ctx.bossPhase == 2 {
                return [
                    .init(weight: 40, action: .aoeFlat(20),
                          name: "Demo Order", message: "Demo Order. 20 flat. Ignores DEF. That's it."),
                    .init(weight: 35, action: .selfBuff(atk: 4, turns: 999),
                          name: "Overtime", message: "Rex is on overtime. Three actions a round."),
                    .init(weight: 25, action: .flatDamage(attackPower * 2 - defense, ignoresDEF: true),
                          name: "Hardhat Throw", message: "throws his hardhat. One-use. He immediately puts on a backup hat."),
                ]
            } else {
                return [
                    .init(weight: 40, action: .attack(mult: 1.3),
                          name: "Jackhammer", message: "JACKHAMMERS."),
                    .init(weight: 35, action: .selfBuff(atk: 6, turns: 999),
                          name: "Blueprint", message: "consults the blueprint. ATK +6. Permanent until dispelled."),
                    .init(weight: 25, action: .selfBuff(def: 4, turns: 2),
                          name: "Safety Hazard", message: "creates a safety hazard (somehow DEF buff)."),
                ]
            }
        }
    }
}

// MARK: - EnemyNode

@MainActor
final class EnemyNode: SKSpriteNode {
    let kind: EnemyKind
    var patrolOrigin: CGPoint = .zero
    var encounterID: String?

    private(set) var hp: Int
    var isDead: Bool { hp <= 0 }

    private var nextMoveTime: TimeInterval = 0
    private var hpBarBg:   SKSpriteNode!
    private var hpBarFill: SKSpriteNode!

    init(kind: EnemyKind) {
        self.kind = kind
        self.hp   = kind.maxHP

        let tex = WorldSprites.overworldTexture(enemy: kind)
        let size = kind.isBoss
            ? CGSize(width: 72, height: 72)
            : CGSize(width: 48, height: 48)
        super.init(texture: tex, color: .clear, size: size)
        name      = "enemy"
        zPosition = GameConstants.ZPos.entity

        let radius: CGFloat = kind.isBoss ? 32 : 20
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.allowsRotation    = false
        body.linearDamping     = 4
        body.categoryBitMask   = GameConstants.Category.enemy
        body.collisionBitMask  = GameConstants.Category.wall
        body.contactTestBitMask = GameConstants.Category.player
        physicsBody = body

        buildHPBar()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - HP bar

    private func buildHPBar() {
        let barW: CGFloat = kind.isBoss ? 64 : 42
        let barH: CGFloat = kind.isBoss ? 7 : 5
        hpBarBg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.5),
                                size: CGSize(width: barW, height: barH))
        hpBarBg.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBarBg.position    = CGPoint(x: -barW/2, y: (kind.isBoss ? 44 : 32))
        hpBarBg.zPosition   = 1
        addChild(hpBarBg)

        hpBarFill = SKSpriteNode(color: .green, size: CGSize(width: barW, height: barH))
        hpBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBarFill.zPosition   = 1
        hpBarBg.addChild(hpBarFill)
    }

    private func refreshHPBar() {
        let barW = hpBarBg.size.width
        let frac = CGFloat(max(hp, 0)) / CGFloat(kind.maxHP)
        hpBarFill.size.width = barW * frac
        hpBarFill.color = frac > 0.5 ? .green : (frac > 0.25 ? .yellow : .red)
    }

    // MARK: - Combat

    func takeDamage(_ amount: Int) -> Bool {
        guard !isDead else { return true }
        hp = max(0, hp - amount)
        refreshHPBar()

        removeAction(forKey: "hitFlash")
        let flash = SKAction.sequence([
            .colorize(with: .white, colorBlendFactor: 0.9, duration: 0.04),
            .colorize(withColorBlendFactor: 0, duration: 0.12)
        ])
        run(flash, withKey: "hitFlash")
        return isDead
    }

    func healHP(_ amount: Int) {
        hp = min(kind.maxHP, hp + amount)
        refreshHPBar()
    }

    func playDeathAndRemove(completion: @escaping () -> Void) {
        physicsBody = nil
        run(.sequence([
            .group([.scale(to: 1.5, duration: 0.15), .fadeOut(withDuration: 0.15)]),
            .removeFromParent(),
            .run(completion)
        ]))
    }

    // MARK: - Overworld AI

    func tick(now: TimeInterval, playerPos: CGPoint) {
        guard !isDead, let body = physicsBody else { return }

        let dx = playerPos.x - position.x
        let dy = playerPos.y - position.y
        let dist = sqrt(dx*dx + dy*dy)

        if dist < kind.visionRadius {
            let len = max(dist, 0.001)
            body.velocity = CGVector(dx: dx/len * kind.speed, dy: dy/len * kind.speed)
            xScale = dx < 0 ? -1 : 1
        } else {
            if now >= nextMoveTime {
                nextMoveTime = now + Double.random(in: 1.5...3.5)
                let angle = CGFloat.random(in: 0 ..< 2 * .pi)
                body.velocity = CGVector(dx: cos(angle)*kind.speed*0.4,
                                         dy: sin(angle)*kind.speed*0.4)
            }
            let homeDx = position.x - patrolOrigin.x
            let homeDy = position.y - patrolOrigin.y
            if homeDx*homeDx + homeDy*homeDy > 200*200 {
                body.velocity = CGVector(dx: -homeDx*0.5, dy: -homeDy*0.5)
            }
        }
    }
}
