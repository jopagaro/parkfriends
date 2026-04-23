import SpriteKit

enum ItemKind: String, CaseIterable {
    case acorn, berry, coin, key, mushroom

    var emoji: String {
        switch self {
        case .acorn: "🌰"
        case .berry: "🍓"
        case .coin:  "🪙"
        case .key:   "🗝️"
        case .mushroom: "🍄"
        }
    }

    var displayName: String { rawValue.capitalized }

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
