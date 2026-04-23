import SpriteKit

@MainActor
final class PlayerNode: SKSpriteNode {
    private(set) var species: Species

    /// Last non-zero movement direction — used to aim attacks.
    private(set) var facing: CGVector = CGVector(dx: 0, dy: -1)

    private var isWalking = false

    init(species: Species) {
        self.species = species
        let texture = CharacterSprites.texture(species: species, frame: .a)
        super.init(texture: texture, color: .clear, size: CGSize(width: 52, height: 52))
        name = "player"
        zPosition = GameConstants.ZPos.entity

        let body = SKPhysicsBody(circleOfRadius: 18)
        body.allowsRotation = false
        body.linearDamping  = 6
        body.friction       = 0
        body.restitution    = 0
        body.categoryBitMask    = GameConstants.Category.player
        body.collisionBitMask   = GameConstants.Category.wall | GameConstants.Category.pushable
        body.contactTestBitMask =
            GameConstants.Category.item    |
            GameConstants.Category.npc     |
            GameConstants.Category.enemy   |
            GameConstants.Category.interact
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func setSpecies(_ s: Species) {
        species = s
        stopWalkCycle()
        texture = CharacterSprites.texture(species: s, frame: .a)
    }

    // MARK: - Movement

    /// Apply velocity from a normalised direction vector (−1…1 on each axis).
    func move(direction: CGVector) {
        guard let body = physicsBody else { return }
        let len = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        let moving = len > 0.05

        if moving {
            facing = CGVector(dx: direction.dx / len, dy: direction.dy / len)
            if !isWalking { startWalkCycle() }
        } else {
            if isWalking { stopWalkCycle() }
        }

        body.velocity = CGVector(
            dx: direction.dx * species.baseSpeed,
            dy: direction.dy * species.baseSpeed
        )
        if abs(direction.dx) > 0.05 {
            xScale = direction.dx < 0 ? -1 : 1
        }
    }

    // MARK: - Walk cycle

    private func startWalkCycle() {
        isWalking = true
        let cycle = SKAction.repeatForever(.sequence([
            .run { [weak self] in
                guard let self else { return }
                self.texture = CharacterSprites.texture(species: self.species, frame: .a)
            },
            .wait(forDuration: 0.16),
            .run { [weak self] in
                guard let self else { return }
                self.texture = CharacterSprites.texture(species: self.species, frame: .b)
            },
            .wait(forDuration: 0.16),
        ]))
        run(cycle, withKey: "walk")
    }

    private func stopWalkCycle() {
        isWalking = false
        removeAction(forKey: "walk")
        texture = CharacterSprites.texture(species: species, frame: .a)
    }

    // MARK: - Effects

    /// Quick visual flash when taking damage.
    func flashDamage() {
        removeAction(forKey: "flash")
        let flash = SKAction.sequence([
            .colorize(with: .red, colorBlendFactor: 0.8, duration: 0.06),
            .colorize(withColorBlendFactor: 0, duration: 0.18)
        ])
        run(flash, withKey: "flash")
    }

    /// Bounce-punch animation when attacking.
    func playAttackPunch() {
        removeAction(forKey: "punch")
        let punch = SKAction.sequence([
            .scale(to: 1.25, duration: 0.06),
            .scale(to: 1.0,  duration: 0.12)
        ])
        run(punch, withKey: "punch")
    }
}
