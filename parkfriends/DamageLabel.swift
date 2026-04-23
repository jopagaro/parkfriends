import SpriteKit

/// A floating "+10" / "-2" label that rises and fades.
@MainActor
final class DamageLabel: SKLabelNode {

    static func spawn(text: String,
                      color: SKColor = .white,
                      at position: CGPoint,
                      in parent: SKNode) {
        let label = DamageLabel(text: text)
        label.fontName        = "AvenirNext-Bold"
        label.fontSize        = 22
        label.fontColor       = color
        label.position        = position
        label.zPosition       = GameConstants.ZPos.effect
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode   = .center

        // Small shadow for readability
        let shadow = SKLabelNode(text: text)
        shadow.fontName   = "AvenirNext-Bold"
        shadow.fontSize   = 22
        shadow.fontColor  = SKColor(white: 0, alpha: 0.5)
        shadow.position   = CGPoint(x: 1.5, y: -1.5)
        shadow.zPosition  = -1
        label.addChild(shadow)

        parent.addChild(label)

        // Float up + spread out + fade
        let rise = SKAction.moveBy(x: CGFloat.random(in: -12...12),
                                   y: 38,
                                   duration: 0.7)
        rise.timingMode = .easeOut
        label.run(.sequence([
            .group([rise, .fadeOut(withDuration: 0.6)]),
            .removeFromParent()
        ]))
    }

    /// Spawn a red damage number above an enemy.
    static func damage(_ amount: Int, at pos: CGPoint, in parent: SKNode) {
        spawn(text: "-\(amount)", color: .red, at: pos, in: parent)
    }

    /// Spawn a green collection label.
    static func collect(_ text: String, at pos: CGPoint, in parent: SKNode) {
        spawn(text: text, color: SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1),
              at: pos, in: parent)
    }

    /// Spawn a yellow score popup.
    static func score(_ amount: Int, at pos: CGPoint, in parent: SKNode) {
        spawn(text: "+\(amount)", color: .yellow, at: pos, in: parent)
    }
}
