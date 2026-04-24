import Foundation
import CoreGraphics

// MARK: - Status Effects

enum StatusEffect: String, Hashable, Sendable, Codable, CaseIterable {
    case poison
    case strongPoison
    case sleep
    case confusion
    case distraction
    case embarrassment
    case fear
    case rage
    case defending

    var displayName: String {
        switch self {
        case .poison:        "Poisoned"
        case .strongPoison:  "Badly Poisoned"
        case .sleep:         "Asleep"
        case .confusion:     "Confused"
        case .distraction:   "Distracted"
        case .embarrassment: "Embarrassed"
        case .fear:          "Afraid"
        case .rage:          "Raging"
        case .defending:     "Defending"
        }
    }

    var emoji: String {
        switch self {
        case .poison:        "🟢"
        case .strongPoison:  "☣️"
        case .sleep:         "😴"
        case .confusion:     "😵"
        case .distraction:   "📱"
        case .embarrassment: "😳"
        case .fear:          "😨"
        case .rage:          "😤"
        case .defending:     "🛡️"
        }
    }
}

// MARK: - Species

enum Species: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case turtle, squirrel, hedgehog, hamster

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turtle:   "Shelly"
        case .squirrel: "Hazel"
        case .hedgehog: "Spike"
        case .hamster:  "Pip"
        }
    }

    var emoji: String {
        switch self {
        case .turtle:   "🐢"
        case .squirrel: "🐿️"
        case .hedgehog: "🦔"
        case .hamster:  "🐹"
        }
    }

    // MARK: Base stats (level 1)

    var baseHP:  Int { switch self { case .turtle: 80; case .squirrel: 45; case .hedgehog: 55; case .hamster: 60 } }
    var basePP:  Int { switch self { case .turtle: 15; case .squirrel: 30; case .hedgehog: 20; case .hamster: 40 } }
    var baseATK: Int { switch self { case .turtle: 18; case .squirrel: 14; case .hedgehog: 22; case .hamster: 16 } }
    var baseDEF: Int { switch self { case .turtle: 28; case .squirrel: 10; case .hedgehog: 16; case .hamster: 12 } }
    var baseSPD: Int { switch self { case .turtle:  4; case .squirrel: 18; case .hedgehog: 14; case .hamster: 12 } }
    var baseLCK: Int { switch self { case .turtle: 10; case .squirrel: 16; case .hedgehog:  8; case .hamster: 20 } }

    // MARK: Overworld movement speed (pixels/sec)

    var baseSpeed: CGFloat {
        switch self {
        case .turtle:   90
        case .squirrel: 170
        case .hedgehog: 110
        case .hamster:  140
        }
    }

    // MARK: Attack node (overworld projectile / melee — kept for future use)

    var attackDamage: Int       { switch self { case .turtle: 3; case .squirrel: 1; case .hedgehog: 2; case .hamster: 2 } }
    var attackCooldown: TimeInterval { switch self { case .turtle: 1.8; case .squirrel: 0.35; case .hedgehog: 1.0; case .hamster: 0.45 } }
    var attackIsProjectile: Bool { self == .squirrel }
    var attackGlyph: String     { switch self { case .turtle: "💥"; case .squirrel: "🌰"; case .hedgehog: "⭐️"; case .hamster: "⚡️" } }

    // MARK: Special skill (battle)

    var specialName: String {
        switch self {
        case .turtle:   "Shell Slam"
        case .squirrel: "Acorn Toss"
        case .hedgehog: "Curl & Roll"
        case .hamster:  "Chaos Toss"
        }
    }

    var specialPPCost: Int {
        switch self {
        case .turtle:   6
        case .squirrel: 4
        case .hedgehog: 7
        case .hamster:  4
        }
    }

    // MARK: LLM personality

    var personalityPrompt: String {
        switch self {
        case .turtle:
            "Shelly the turtle — slow, wise, overly cautious. Speaks in short deliberate sentences. Loves lettuce and naps."
        case .squirrel:
            "Hazel the squirrel — fast, sharp, and supportive. She notices details other people miss and talks like she is already halfway up a tree."
        case .hedgehog:
            "Spike the hedgehog — prickly, brave, and a little dramatic. Dry sarcasm hides how much he cares."
        case .hamster:
            "Pip the hamster — chaotic, overconfident, and weirdly lucky. Talks like every bad idea is definitely going to work."
        }
    }

    var levelUpProfile: (hp: ClosedRange<Int>, atk: ClosedRange<Int>, def: ClosedRange<Int>,
                         spd: ClosedRange<Int>, lck: ClosedRange<Int>, pp: ClosedRange<Int>) {
        switch self {
        case .turtle:
            (4...8, 1...3, 2...4, 0...2, 0...2, 1...3)
        case .hedgehog:
            (2...6, 2...4, 1...3, 1...3, 0...2, 1...3)
        case .squirrel:
            (2...4, 1...3, 0...2, 3...5, 1...3, 3...5)
        case .hamster:
            (2...6, 1...3, 0...2, 0...4, 2...4, 3...7)
        }
    }
}

// MARK: - PartyMember

struct PartyMember: Identifiable, Sendable, Codable {
    var id: UUID

    let species: Species

    // Progression
    var level: Int
    var exp:   Int
    var expToNext: Int { level * 100 }

    // HP / PP
    var maxHP: Int
    var hp:    Int
    var maxPP: Int
    var pp:    Int

    // Battle stats
    var atk: Int
    var def: Int
    var spd: Int
    var lck: Int

    // Status
    var statusEffects: Set<StatusEffect>

    var isAlive: Bool { hp > 0 }

    // MARK: Init

    init(species: Species, level: Int = 1) {
        self.id      = UUID()
        self.species = species
        self.level   = level
        self.exp     = 0

        let lvl = level - 1
        self.maxHP   = species.baseHP  + lvl * 8
        self.hp      = maxHP
        self.maxPP   = species.basePP  + lvl * 4
        self.pp      = maxPP
        self.atk     = species.baseATK + lvl * 2
        self.def     = species.baseDEF + lvl * 2
        self.spd     = species.baseSPD + lvl
        self.lck     = species.baseLCK
        self.statusEffects = []
    }

    // MARK: Level-up

    /// Applies one level-up, returns a stat-change summary string.
    mutating func applyLevelUp() -> String {
        level += 1
        let profile = species.levelUpProfile
        let hpGain  = Int.random(in: profile.hp)
        let atkGain = Int.random(in: profile.atk)
        let defGain = Int.random(in: profile.def)
        let spdGain = Int.random(in: profile.spd)
        let lckGain = Int.random(in: profile.lck)
        let ppGain  = Int.random(in: profile.pp)

        maxHP += hpGain;  hp  = min(hp + hpGain, maxHP)
        maxPP += ppGain;  pp  = min(pp + ppGain, maxPP)
        atk   += atkGain
        def   += defGain
        spd   += spdGain
        lck   += lckGain

        return "HP+\(hpGain)  ATK+\(atkGain)  DEF+\(defGain)  SPD+\(spdGain)  LCK+\(lckGain)  PP+\(ppGain)"
    }

    // MARK: Status helpers

    mutating func clearStatus(_ effect: StatusEffect) { statusEffects.remove(effect) }
    mutating func applyStatus(_ effect: StatusEffect) { statusEffects.insert(effect) }
    var isPoisoned:    Bool { statusEffects.contains(.poison) }
    var isBadlyPoisoned: Bool { statusEffects.contains(.strongPoison) }
    var isAsleep:      Bool { statusEffects.contains(.sleep) }
    var isConfused:    Bool { statusEffects.contains(.confusion) }
    var isDistracted:  Bool { statusEffects.contains(.distraction) }
    var isEmbarrassed: Bool { statusEffects.contains(.embarrassment) }
    var isAfraid:      Bool { statusEffects.contains(.fear) }
    var isRaging:      Bool { statusEffects.contains(.rage) }
    var isDefending:   Bool { statusEffects.contains(.defending) }

    // MARK: Defaults

    static let defaultParty: [PartyMember] = Species.allCases.map { PartyMember(species: $0) }
    static let startingParty: [PartyMember] = [PartyMember(species: .turtle)]
}
