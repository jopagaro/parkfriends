import SpriteKit

/// Short-lived physics node that represents a player attack.
/// - Melee attacks: placed in front of player, static, removed after `lifetime`.
/// - Projectiles: given velocity, removed on impact or after `range` distance.
@MainActor
final class AttackNode: SKSpriteNode {

    let damage: Int
    /// Set of enemies already hit this swing — prevents multi-hitting.
    var hitEnemies: Set<ObjectIdentifier> = []

    private let isProjectile: Bool
    private let startPosition: CGPoint
    private let maxRange: CGFloat

    init(species: Species, at position: CGPoint, facing: CGVector) {
        let dmg   = species.attackDamage
        let proj  = species.attackIsProjectile
        let glyph = species.attackGlyph

        self.damage      = dmg
        self.isProjectile = proj
        self.startPosition = position
        self.maxRange    = proj ? 220 : 55

        let tex = SpriteFactory.emojiTexture(glyph, size: 64)
        super.init(texture: tex, color: .clear, size: CGSize(width: 36, height: 36))

        name        = "attack"
        zPosition   = GameConstants.ZPos.effect

        // Position: in front for melee, at player for projectile launch
        let offset: CGFloat = proj ? 10 : 26
        self.position = CGPoint(
            x: position.x + facing.dx * offset,
            y: position.y + facing.dy * offset
        )

        // Flip to match direction
        if abs(facing.dx) > 0.1 { xScale = facing.dx < 0 ? -1 : 1 }

        let radius: CGFloat = species == .hedgehog ? 32 : (proj ? 10 : 20)
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic           = proj
        body.affectedByGravity   = false
        body.allowsRotation      = false
        body.linearDamping       = 0
        body.categoryBitMask     = GameConstants.Category.attack
        body.collisionBitMask    = 0   // pass through everything
        body.contactTestBitMask  = GameConstants.Category.enemy
        physicsBody = body

        if proj {
            let speed: CGFloat = 380
            body.velocity = CGVector(dx: facing.dx * speed, dy: facing.dy * speed)
        }

        setupLifecycle(species: species, facing: facing)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func setupLifecycle(species: Species, facing: CGVector) {
        let lifetime = species.attackCooldown * 0.35

        // Hedgehog spins in a circle
        if species == .hedgehog {
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: lifetime)
            run(.repeatForever(spin))
        }

        // Squirrel acorn tumbles
        if species == .squirrel {
            run(.repeatForever(.rotate(byAngle: .pi, duration: 0.25)))
        }

        // Remove after lifetime
        run(.sequence([
            .wait(forDuration: lifetime),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }

    /// Call every frame for projectiles to auto-remove when out of range.
    func checkRange() {
        guard isProjectile else { return }
        let dx = position.x - startPosition.x
        let dy = position.y - startPosition.y
        if dx * dx + dy * dy > maxRange * maxRange {
            removeFromParent()
        }
    }
}
