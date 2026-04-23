import SpriteKit

@MainActor
final class ActionButton: SKNode {
    private let bg: SKShapeNode
    private let label: SKLabelNode

    var onTap: (() -> Void)?

    init(glyph: String, radius: CGFloat = 36, tint: SKColor = .orange) {
        bg = SKShapeNode(circleOfRadius: radius)
        bg.fillColor = tint.withAlphaComponent(0.85)
        bg.strokeColor = .white
        bg.lineWidth = 2

        label = SKLabelNode(text: glyph)
        label.fontSize = radius * 0.9
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        super.init()
        addChild(bg)
        addChild(label)
        zPosition = GameConstants.ZPos.ui
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func setGlyph(_ g: String) { label.text = g }

#if canImport(UIKit)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 0.9, duration: 0.05))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1.0, duration: 0.08))
        onTap?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1.0, duration: 0.08))
    }
#endif
}
