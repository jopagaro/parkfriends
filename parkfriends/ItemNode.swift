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

    var shopDescription: String {
        switch self {
        case .parkWater:    "Restores 15 HP"
        case .staleChip:    "Restores 20 HP (kinda gross)"
        case .warmCola:     "Restores 25 HP + 5 PP"
        case .berry:        "Restores 30 HP"
        case .juiceBox:     "Restores 35 HP + 10 PP"
        case .granolaBar:   "Restores 40 HP"
        case .energyDrink:  "Restores 20 PP + 10 HP"
        case .antidote:     "Cures poison"
        case .comfortSnack: "Restores 50 HP"
        case .superBerry:   "Restores 80 HP"
        case .megaBerry:    "Fully restores HP to one member"
        case .mysteryBag:   "Contents unknown. Cheap though."
        default: ""
        }
    }

    var isConsumable: Bool {
        switch self {
        case .parkToken, .cityHallKey, .constructionPass,
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
