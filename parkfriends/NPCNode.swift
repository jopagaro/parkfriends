import SpriteKit

enum NPCKind: String, CaseIterable {
    case rangerGuide, hazel
    case jogger, child, birdwatcher, dogwalker, gardener
    case worker       // Construction worker in City North — gives workerSawDuck clue
    case shopkeeper   // Opens the corner store shop overlay — not used in random NPC cycling

    var emoji: String {
        switch self {
        case .rangerGuide: "🧭"
        case .hazel:       "🌰"
        case .jogger:      "🏃"
        case .child:       "🧒"
        case .birdwatcher: "👩‍🦳"
        case .dogwalker:   "🧑‍🦱"
        case .gardener:    "👨‍🌾"
        case .worker:      "👷"
        case .shopkeeper:  "🧑‍💼"
        }
    }

    var displayName: String {
        switch self {
        case .rangerGuide: "Ranger"
        case .hazel:       "Hazel"
        case .jogger:      "Jogger"
        case .child:       "Kid"
        case .birdwatcher: "Birdwatcher"
        case .dogwalker:   "Dog Walker"
        case .gardener:    "Gardener"
        case .worker:      "Worker"
        case .shopkeeper:  "Corner Store"
        }
    }

    /// Shopkeeper NPCs open the shop UI; regular NPCs go to AI dialogue.
    var isShopkeeper: Bool { self == .shopkeeper }

    /// Fixed-placement story/shop NPCs are not part of the random rotation.
    var isFixed: Bool {
        switch self {
        case .rangerGuide, .hazel, .worker, .shopkeeper:
            true
        default:
            false
        }
    }

    /// System-prompt seed given to the LLM for this NPC's personality.
    var persona: String {
        switch self {
        case .rangerGuide:
            "You are Bellwether Park's ranger. You speak like every ridiculous problem needs to be filed correctly before anyone panics."
        case .hazel:
            "You are Hazel, a sharp squirrel with urgent opinions, fast timing, and zero patience for pigeons touching your belongings."
        case .jogger:
            "You are a breathless park jogger who speaks in clipped sentences between breaths. You've seen everything in this park but only share gossip if asked nicely."
        case .child:
            "You are a curious 7-year-old at the park. You talk in excited run-on sentences and ask lots of questions. You think the animals are magic."
        case .birdwatcher:
            "You are a soft-spoken elderly birdwatcher with encyclopedic knowledge of park wildlife. You whisper so you don't scare the birds."
        case .dogwalker:
            "You are a chatty twenty-something walking three dogs. Easily distracted by your dogs mid-sentence."
        case .gardener:
            "You are a weathered park gardener who grumbles about litter and rabbits eating the flowers, but secretly loves animals."
        case .worker:
            "You are a no-nonsense construction worker on a City North site. You're eating lunch. You give terse, practical answers and are vaguely surprised to be talking to an animal."
        case .shopkeeper:
            "You are a tired corner store owner who sells snacks. You speak only in short, dry quips."
        }
    }
}

@MainActor
final class NPCNode: SKSpriteNode {
    let kind: NPCKind

    init(kind: NPCKind) {
        self.kind = kind
        let tex = WorldSprites.texture(npc: kind)
        super.init(texture: tex, color: .clear, size: CGSize(width: 48, height: 48))
        name = "npc"
        zPosition = GameConstants.ZPos.entity

        let body = SKPhysicsBody(circleOfRadius: 22)
        body.isDynamic = false
        body.categoryBitMask = GameConstants.Category.npc
        body.contactTestBitMask = GameConstants.Category.player
        body.collisionBitMask = 0
        physicsBody = body

        // Little idle sway
        let sway = SKAction.sequence([
            .rotate(toAngle: 0.05, duration: 0.8),
            .rotate(toAngle: -0.05, duration: 0.8)
        ])
        run(.repeatForever(sway))

        addIndicator()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func addIndicator() {
        let bubble = SKShapeNode(rectOf: CGSize(width: kind.isShopkeeper ? 18 : 14, height: 14))
        bubble.fillColor = kind.isShopkeeper
            ? SKColor(red: 0.83, green: 0.69, blue: 0.19, alpha: 0.95)
            : SKColor(red: 0.93, green: 0.93, blue: 0.86, alpha: 0.95)
        bubble.strokeColor = GamePalette.outline
        bubble.lineWidth = 2
        bubble.position = CGPoint(x: 0, y: 34)
        bubble.zPosition = 1
        bubble.name = "chatIndicator"

        if kind.isShopkeeper {
            let notch = SKShapeNode(rectOf: CGSize(width: 6, height: 6))
            notch.fillColor = SKColor(red: 0.62, green: 0.36, blue: 0.14, alpha: 1)
            notch.strokeColor = .clear
            notch.position = .zero
            bubble.addChild(notch)
        } else {
            let dot = SKShapeNode(rectOf: CGSize(width: 4, height: 4))
            dot.fillColor = GamePalette.outline
            dot.strokeColor = .clear
            dot.position = .zero
            bubble.addChild(dot)
        }

        let up = SKAction.moveBy(x: 0, y: 3, duration: 0.5)
        up.timingMode = .easeInEaseOut
        bubble.run(.repeatForever(.sequence([up, up.reversed()])))
        addChild(bubble)
    }
}
