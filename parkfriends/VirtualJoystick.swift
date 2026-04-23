import SpriteKit

/// A simple on-screen joystick. Stays pinned to the camera.
@MainActor
final class VirtualJoystick: SKNode {
    private let base: SKShapeNode
    private let knob: SKShapeNode
    private let maxRadius: CGFloat

    /// Normalized direction vector, updated while the stick is being dragged.
    /// Range is roughly -1…1 on each axis.
    private(set) var direction: CGVector = .zero

    init(radius: CGFloat = 70) {
        self.maxRadius = radius

        base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = SKColor(white: 1, alpha: 0.15)
        base.strokeColor = SKColor(white: 1, alpha: 0.4)
        base.lineWidth = 2

        knob = SKShapeNode(circleOfRadius: radius * 0.45)
        knob.fillColor = SKColor(white: 1, alpha: 0.6)
        knob.strokeColor = .white
        knob.lineWidth = 1

        super.init()
        addChild(base)
        addChild(knob)
        zPosition = GameConstants.ZPos.ui
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func updateKnob(to point: CGPoint) {
        let dx = point.x
        let dy = point.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist <= maxRadius {
            knob.position = point
        } else {
            let scale = maxRadius / dist
            knob.position = CGPoint(x: dx * scale, y: dy * scale)
        }
        direction = CGVector(
            dx: knob.position.x / maxRadius,
            dy: knob.position.y / maxRadius
        )
    }

    private func resetKnob() {
        direction = .zero
        let back = SKAction.move(to: .zero, duration: 0.08)
        back.timingMode = .easeOut
        knob.run(back)
    }

#if canImport(UIKit)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        updateKnob(to: t.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        updateKnob(to: t.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetKnob()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetKnob()
    }
#endif
}
