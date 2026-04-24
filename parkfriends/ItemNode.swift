import SpriteKit

enum ItemKind: String, CaseIterable {
    case berry
    case granolaBar
    case juiceBox
    case antidote
    case energyDrink
    case warmCola
    case comfortSnack
    case parkWater
    case mysteryBag
    case superBerry
    case megaBerry
    case parkToken
    case cityHallKey
    case constructionPass
    case lostAcorn
    // Drop-only items (§5.1)
    case feather
    case staleChip
    case gooseFeather
    case parkPermit
    case shinyThing
    case parkWhistle
    case officialForm
    case stingSac
    case businessCard
    case machinePart
    case oldSticker
    // Key drops
    case geraldSash
    case parkNewspaper
    case officerBadge
    case constructionBadge
    case workerThermos
    // "Find Quack" story items
    case quackFeather       // blue-tipped feather near empty pond (Park North)
    case duckTag            // Quack's ID tag, dropped by raccoon
    case breadcrumbTrail    // bag of crumbs, pigeon clue in City South

    var emoji: String {
        switch self {
        case .berry:            "🫐"
        case .granolaBar:       "🍫"
        case .juiceBox:         "🧃"
        case .antidote:         "🧴"
        case .energyDrink:      "🥤"
        case .warmCola:         "🥫"
        case .comfortSnack:     "🍪"
        case .parkWater:        "💧"
        case .mysteryBag:       "🛍️"
        case .superBerry:       "🍓"
        case .megaBerry:        "✨"
        case .parkToken:        "🪙"
        case .cityHallKey:      "🗝️"
        case .constructionPass: "🪪"
        case .lostAcorn:        "🌰"
        case .feather:          "🪶"
        case .staleChip:        "🥨"
        case .gooseFeather:     "🪶"
        case .parkPermit:       "📋"
        case .shinyThing:       "✨"
        case .parkWhistle:      "📢"
        case .officialForm:     "📄"
        case .stingSac:         "💉"
        case .businessCard:     "📇"
        case .machinePart:      "⚙️"
        case .oldSticker:       "🏷️"
        case .geraldSash:       "🎖️"
        case .parkNewspaper:    "📰"
        case .officerBadge:     "🏅"
        case .constructionBadge: "🪪"
        case .workerThermos:    "☕"
        case .quackFeather:     "🪶"
        case .duckTag:          "🏷️"
        case .breadcrumbTrail:  "🥖"
        }
    }

    var displayName: String {
        switch self {
        case .berry:            "Berry"
        case .granolaBar:       "Granola Bar"
        case .juiceBox:         "Juice Box"
        case .antidote:         "Antidote"
        case .energyDrink:      "Energy Drink"
        case .warmCola:         "Warm Cola"
        case .comfortSnack:     "Comfort Snack"
        case .parkWater:        "Park Water"
        case .mysteryBag:       "Mystery Bag"
        case .superBerry:       "Super Berry"
        case .megaBerry:        "Mega Berry"
        case .parkToken:        "Park Token"
        case .cityHallKey:      "City Hall Key"
        case .constructionPass: "Construction Pass"
        case .lostAcorn:        "Lost Acorn"
        case .feather:          "Feather"
        case .staleChip:        "Stale Chip"
        case .gooseFeather:     "Goose Feather"
        case .parkPermit:       "Park Permit"
        case .shinyThing:       "Shiny Thing"
        case .parkWhistle:      "Park Whistle"
        case .officialForm:     "Official Form"
        case .stingSac:         "Sting Sac"
        case .businessCard:     "Business Card"
        case .machinePart:      "Machine Part"
        case .oldSticker:       "Old Sticker"
        case .geraldSash:       "Gerald's Sash"
        case .parkNewspaper:    "Park Newspaper"
        case .officerBadge:     "Officer's Badge"
        case .constructionBadge: "Construction Badge"
        case .workerThermos:    "Worker's Thermos"
        case .quackFeather:     "Quack's Feather"
        case .duckTag:          "Duck Tag"
        case .breadcrumbTrail:  "Breadcrumb Trail"
        }
    }

    var hudLabel: String {
        switch self {
        case .berry: return "BER"
        case .granolaBar: return "BAR"
        case .juiceBox: return "JCE"
        case .antidote: return "ANT"
        case .energyDrink: return "NRG"
        case .warmCola: return "COL"
        case .comfortSnack: return "SNK"
        case .parkWater: return "WTR"
        case .mysteryBag: return "BAG"
        case .superBerry: return "SBR"
        case .megaBerry: return "MBR"
        case .parkToken: return "TOK"
        case .cityHallKey: return "KEY"
        case .constructionPass: return "PASS"
        case .lostAcorn: return "ACRN"
        case .feather, .gooseFeather, .quackFeather: return "FTH"
        case .staleChip: return "CHP"
        case .parkPermit: return "PRM"
        case .shinyThing: return "SHN"
        case .parkWhistle: return "WHL"
        case .officialForm: return "FRM"
        case .stingSac: return "STG"
        case .businessCard: return "CRD"
        case .machinePart: return "PRT"
        case .oldSticker: return "STK"
        case .geraldSash: return "SASH"
        case .parkNewspaper: return "NEWS"
        case .officerBadge: return "BDG"
        case .constructionBadge: return "BDG"
        case .workerThermos: return "THR"
        case .duckTag: return "TAG"
        case .breadcrumbTrail: return "BRD"
        }
    }

    // MARK: - Shop

    /// Non-nil → item appears in corner store at this coin price.
    var buyPrice: Int? {
        switch self {
        case .parkWater:    4
        case .staleChip:    3
        case .warmCola:     6
        case .berry:        8
        case .juiceBox:     10
        case .granolaBar:   12
        case .energyDrink:  15
        case .antidote:     20
        case .comfortSnack: 18
        case .superBerry:   25
        case .megaBerry:    40
        case .mysteryBag:   5
        default: nil
        }
    }

    /// Human-readable description — used in shop, inventory, and stats screens.
    var itemDescription: String {
        switch self {
        // Consumables
        case .parkWater:          "Restores 15 HP"
        case .staleChip:          "Restores 20 HP (kinda gross)"
        case .warmCola:           "Restores 25 HP + 5 PP"
        case .berry:              "Restores 30 HP"
        case .juiceBox:           "Restores 35 HP + 10 PP"
        case .granolaBar:         "Restores 40 HP"
        case .energyDrink:        "Restores 20 PP + 10 HP"
        case .antidote:           "Cures poison and strong poison"
        case .comfortSnack:       "Restores 50 HP"
        case .superBerry:         "Restores 80 HP"
        case .megaBerry:          "Fully restores one member's HP"
        case .mysteryBag:         "Random effect. Could be great. Could be a nap."
        // Key / currency
        case .parkToken:          "Used in park vending areas"
        case .cityHallKey:        "Opens something in City Hall"
        case .constructionPass:   "Access pass for the construction site"
        case .lostAcorn:          "Hazel's reserve acorn. She named it Steven."
        // Drops — junk / lore
        case .feather:            "A small bird feather. Soft."
        case .gooseFeather:       "Long grey feather. Slightly menacing."
        case .parkPermit:         "Official permit stamp. Expired."
        case .shinyThing:         "The raccoon thought it was treasure."
        case .parkWhistle:        "Ranger's whistle. Very loud."
        case .officialForm:       "Form 27B/6. Nobody knows what it's for."
        case .stingSac:           "Wasp venom sac. Handle carefully."
        case .businessCard:       "\"DALE, Compliance Officer.\""
        case .machinePart:        "Gears and springs. Mechanical origin."
        case .oldSticker:         "\"RAD\" — from a different era."
        // Boss drops
        case .geraldSash:         "Gerald's ceremonial pond-ruler sash."
        case .parkNewspaper:      "\"GOOSE DETHRONED.\" — Park Bugle."
        case .officerBadge:       "Grumble's badge. Heavy. Scratched."
        case .constructionBadge:  "Rex's site manager badge."
        case .workerThermos:      "Rex's thermos. Still warm."
        // Story items
        case .quackFeather:       "A blue-tipped feather from Quack's wing."
        case .duckTag:            "An ID tag: 'QUACK — if found, call pond.'"
        case .breadcrumbTrail:    "A trail of bread crumbs leading cityward."
        }
    }

    /// Backwards-compat alias used in ShopView (same as itemDescription).
    var shopDescription: String { itemDescription }

    // MARK: - Healing effects
    // These are the SINGLE SOURCE OF TRUTH used by both battle and overworld.
    // BattleNode reads these directly — never hardcode heal amounts there.

    /// HP restored when used. 0 = no HP effect.
    var healHP: Int {
        switch self {
        case .parkWater:    15
        case .staleChip:    20
        case .warmCola:     25
        case .berry:        30
        case .juiceBox:     35
        case .granolaBar:   40
        case .energyDrink:  10
        case .comfortSnack: 50
        case .superBerry:   80
        case .megaBerry:    9999  // full restore — clamped to maxHP at use-site
        case .mysteryBag:   25    // fixed "expected value"; actual effect is random in useMysteryBag
        default: 0
        }
    }

    /// PP restored when used. 0 = no PP effect.
    var healPP: Int {
        switch self {
        case .warmCola:     5
        case .juiceBox:     10
        case .energyDrink:  20
        default: 0
        }
    }

    /// True if this item cures a poison status effect.
    var curesPoison: Bool { self == .antidote }

    /// True if this item can be used outside of battle.
    var isUsable: Bool { isConsumable && (healHP > 0 || healPP > 0 || curesPoison) }

    // MARK: - World spawn pools (never include story/boss-drop items)

    /// Items that may appear as random pickups in Park zones (easy tier).
    static let parkSpawnPool: [ItemKind] = [
        .parkWater, .parkWater,          // most common
        .berry, .berry,
        .staleChip,
        .mysteryBag,
        .warmCola,
        .parkToken, .parkToken,
    ]

    /// Items that may appear as random pickups in City South / City Center (mid tier).
    static let citySpawnPool: [ItemKind] = [
        .warmCola, .warmCola,
        .berry, .granolaBar,
        .juiceBox,
        .energyDrink,
        .antidote,
        .mysteryBag,
        .comfortSnack,
        .parkToken,
    ]

    /// Items that may appear in City North (hard / final tier).
    static let cityNorthSpawnPool: [ItemKind] = [
        .granolaBar, .juiceBox,
        .comfortSnack, .comfortSnack,
        .superBerry,
        .energyDrink,
        .antidote,
        .mysteryBag,
    ]

    var isConsumable: Bool {
        switch self {
        case .parkToken, .cityHallKey, .constructionPass,
             .lostAcorn,
             .geraldSash, .parkNewspaper, .officerBadge,
             .constructionBadge, .workerThermos,
             .parkPermit, .officialForm, .businessCard,
             .machinePart, .stingSac, .feather, .gooseFeather,
             .shinyThing, .oldSticker,
             .quackFeather, .duckTag, .breadcrumbTrail:
            false
        default:
            true
        }
    }

    static func random() -> ItemKind { allCases.randomElement()! }
}

@MainActor
final class ItemNode: SKSpriteNode {
    let kind: ItemKind

    init(kind: ItemKind) {
        self.kind = kind
        let tex = SpriteFactory.emojiTexture(kind.emoji, size: 64)
        super.init(texture: tex, color: .clear, size: CGSize(width: 32, height: 32))
        name = "item"
        zPosition = GameConstants.ZPos.item

        let body = SKPhysicsBody(circleOfRadius: 14)
        body.isDynamic = false
        body.categoryBitMask = GameConstants.Category.item
        body.contactTestBitMask = GameConstants.Category.player
        body.collisionBitMask = 0
        physicsBody = body

        // Gentle bobbing animation so items feel alive.
        let up = SKAction.moveBy(x: 0, y: 4, duration: 0.6)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        run(.repeatForever(.sequence([up, down])))
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}
