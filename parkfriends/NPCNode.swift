import SpriteKit

enum NPCKind: String, CaseIterable {
    case jogger, child, birdwatcher, dogwalker, gardener
    case shopkeeper   // Opens the corner store shop overlay — not used in random NPC cycling

    var emoji: String {
        switch self {
        case .jogger:      "🏃"
        case .child:       "🧒"
        case .birdwatcher: "👩‍🦳"
        case .dogwalker:   "🧑‍🦱"
        case .gardener:    "👨‍🌾"
        case .shopkeeper:  "🧑‍💼"
        }
    }

    var displayName: String {
        switch self {
        case .jogger:      "Jogger"
        case .child:       "Kid"
        case .birdwatcher: "Birdwatcher"
        case .dogwalker:   "Dog Walker"
        case .gardener:    "Gardener"
        case .shopkeeper:  "Corner Store"
        }
    }

    /// Shopkeeper NPCs open the shop UI; regular NPCs go to AI dialogue.
    var isShopkeeper: Bool { self == .shopkeeper }

    /// System-prompt seed given to the LLM for this NPC's personality.
    var persona: String {
        switch self {
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
        let bubble = SKLabelNode(text: "💬")
        bubble.fontSize = 18
        bubble.position = CGPoint(x: 0, y: 32)
        bubble.zPosition = 1
        bubble.name = "chatIndicator"
        let up = SKAction.moveBy(x: 0, y: 3, duration: 0.5)
        up.timingMode = .easeInEaseOut
        bubble.run(.repeatForever(.sequence([up, up.reversed()])))
        addChild(bubble)
    }
}
