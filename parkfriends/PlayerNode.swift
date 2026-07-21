import SpriteKit

@MainActor
final class PlayerNode: SKSpriteNode {
    private(set) var species: Species

    /// Last non-zero movement direction — used to aim attacks.
    private(set) var facing: CGVector = CGVector(dx: 0, dy: -1)

    private var isWalking = false

    private var walkDirection: CharacterSprites.GenDirection = .south

    init(species: Species) {
        self.species = species
        let texture = CharacterSprites.standingTexture(species: species)
        super.init(texture: texture, color: .clear,
                   size: CharacterSprites.overworldSize(species: species))
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
        texture = CharacterSprites.standingTexture(species: s)
        size = CharacterSprites.overworldSize(species: s)
    }

    // MARK: - Movement

    /// Apply velocity from a normalised direction vector (−1…1 on each axis).
    func move(direction: CGVector) {
        guard let body = physicsBody else { return }
        let len = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        let moving = len > 0.05

        if moving {
            facing = CGVector(dx: direction.dx / len, dy: direction.dy / len)
            // Dominant axis picks the sprite direction (SpriteKit y-up).
            let dir: CharacterSprites.GenDirection =
                abs(direction.dx) >= abs(direction.dy)
                    ? (direction.dx < 0 ? .west : .east)
                    : (direction.dy < 0 ? .south : .north)
            if !isWalking || dir != walkDirection {
                walkDirection = dir
                startWalkCycle()
            }
        } else {
            if isWalking { stopWalkCycle() }
        }

        body.velocity = CGVector(
            dx: direction.dx * species.baseSpeed,
            dy: direction.dy * species.baseSpeed
        )
    }

    // MARK: - Walk cycle

    private func startWalkCycle() {
        isWalking = true
        removeAction(forKey: "walk")
        let frames = CharacterSprites.generatedWalkFrames(species: species, direction: walkDirection)
        if frames.count == 4 {
            run(.repeatForever(.animate(with: frames, timePerFrame: 0.12, resize: false, restore: false)),
                withKey: "walk")
        } else {
            // Legacy fallback: 2-frame procedural toggle.
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
    }

    private func stopWalkCycle() {
        isWalking = false
        removeAction(forKey: "walk")
        let idle = CharacterSprites.generatedIdleFrames(species: species)
        if idle.count == 2 {
            // Mostly-still idle with an occasional blink.
            run(.repeatForever(.sequence([
                .setTexture(idle[0], resize: false),
                .wait(forDuration: 2.6),
                .setTexture(idle[1], resize: false),
                .wait(forDuration: 0.14),
            ])), withKey: "walk")
        } else {
            texture = CharacterSprites.texture(species: species, frame: .a)
        }
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
