import Foundation
import CoreGraphics

enum Species: String, CaseIterable, Identifiable, Sendable {
    case turtle
    case squirrel
    case hedgehog
    case hamster

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turtle: "Shelly"
        case .squirrel: "Nutsy"
        case .hedgehog: "Prickle"
        case .hamster: "Biscuit"
        }
    }

    var emoji: String {
        switch self {
        case .turtle: "🐢"
        case .squirrel: "🐿️"
        case .hedgehog: "🦔"
        case .hamster: "🐹"
        }
    }

    var baseSpeed: CGFloat {
        switch self {
        case .turtle: 90
        case .squirrel: 170
        case .hedgehog: 110
        case .hamster: 140
        }
    }

    var personalityPrompt: String {
        switch self {
        case .turtle:
            "Shelly the turtle — slow, wise, overly cautious. Speaks in short deliberate sentences. Loves lettuce and naps."
        case .squirrel:
            "Nutsy the squirrel — hyper, scatterbrained, obsessed with acorns. Interrupts himself mid-sentence."
        case .hedgehog:
            "Prickle the hedgehog — grumpy but loyal. Dry sarcasm. Secretly a softie."
        case .hamster:
            "Biscuit the hamster-guy — brave to a fault, tiny adventurer energy. Tends to shout."
        }
    }

    // MARK: - Attack stats

    var attackDamage: Int {
        switch self {
        case .turtle:   3
        case .squirrel: 1
        case .hedgehog: 2
        case .hamster:  2
        }
    }

    var attackCooldown: TimeInterval {
        switch self {
        case .turtle:   1.8
        case .squirrel: 0.35
        case .hedgehog: 1.0
        case .hamster:  0.45
        }
    }

    var attackIsProjectile: Bool {
        switch self {
        case .squirrel: true
        default:        false
        }
    }

    var attackGlyph: String {
        switch self {
        case .turtle:   "💥"
        case .squirrel: "🌰"
        case .hedgehog: "⭐️"
        case .hamster:  "⚡️"
        }
    }
}

struct PartyMember: Identifiable, Sendable {
    let id = UUID()
    let species: Species
    var maxHP: Int
    var hp: Int
    var items: [String] = []

    static let defaultParty: [PartyMember] = Species.allCases.map {
        PartyMember(species: $0, maxHP: 10, hp: 10)
    }
}
