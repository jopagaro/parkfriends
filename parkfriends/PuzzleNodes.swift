import SpriteKit

// MARK: - Pushable Boulder

/// A heavy rock the player can shove around the park.
@MainActor
final class PushableRockNode: SKSpriteNode {

    init() {
        let tex = SpriteFactory.emojiTexture("🪨", size: 96)
        super.init(texture: tex, color: .clear, size: CGSize(width: 44, height: 44))
        name      = "pushable"
        zPosition = GameConstants.ZPos.entity - 0.5

        let body = SKPhysicsBody(circleOfRadius: 20)
        body.mass              = 8          // heavy — moves slowly
        body.linearDamping     = 12         // stops quickly when not pushed
        body.allowsRotation    = false
        body.friction          = 0.9
        body.restitution       = 0.1
        body.categoryBitMask   = GameConstants.Category.pushable
        body.collisionBitMask  =
            GameConstants.Category.wall   |
            GameConstants.Category.player |
            GameConstants.Category.pushable
        body.contactTestBitMask = GameConstants.Category.pressurePlate
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }
}

// MARK: - Pressure Plate

/// Flat stone that fires a callback when a boulder rests on it.
@MainActor
final class PressurePlateNode: SKSpriteNode {

    var onActivate: (() -> Void)?
    var onDeactivate: (() -> Void)?
    private(set) var isActivated = false

    init() {
        super.init(texture: nil, color: .clear,
                   size: CGSize(width: GameConstants.tileSize,
                                height: GameConstants.tileSize))
        name = "pressurePlate"
        zPosition = GameConstants.ZPos.ground + 2

        // Visual: grey stone slab
        let slab = SKShapeNode(rectOf: CGSize(width: 38, height: 38), cornerRadius: 6)
        slab.fillColor   = SKColor(white: 0.55, alpha: 1)
        slab.strokeColor = SKColor(white: 0.3,  alpha: 1)
        slab.lineWidth   = 2
        addChild(slab)

        // Indicator arrows
        let hint = SKLabelNode(text: "▼▼")
        hint.fontSize  = 10
        hint.fontColor = SKColor(white: 0.9, alpha: 0.7)
        hint.position  = CGPoint(x: 0, y: -2)
        hint.verticalAlignmentMode = .center
        addChild(hint)

        // Sensor body — detects contact but doesn't block movement.
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 36, height: 36))
        body.isDynamic           = false
        body.categoryBitMask     = GameConstants.Category.pressurePlate
        body.collisionBitMask    = 0
        body.contactTestBitMask  = GameConstants.Category.pushable
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func activate() {
        guard !isActivated else { return }
        isActivated = true
        // Turn green
        if let slab = children.first as? SKShapeNode {
            slab.run(.colorize(with: .green, colorBlendFactor: 0.6, duration: 0.2))
        }
        run(.sequence([.wait(forDuration: 0.05), .run { [weak self] in self?.onActivate?() }]))
    }

    func deactivate() {
        guard isActivated else { return }
        isActivated = false
        if let slab = children.first as? SKShapeNode {
            slab.run(.colorize(withColorBlendFactor: 0, duration: 0.2))
        }
        onDeactivate?()
    }
}

// MARK: - Gate

/// A barrier that blocks a path until `open()` is called.
@MainActor
final class GateNode: SKSpriteNode {

    private(set) var isOpen = false

    init(size: CGSize = CGSize(width: GameConstants.tileSize, height: GameConstants.tileSize)) {
        super.init(texture: nil, color: .clear, size: size)
        name      = "gate"
        zPosition = GameConstants.ZPos.decor

        buildVisual()

        let body = SKPhysicsBody(rectangleOf: CGSize(width: size.width - 4,
                                                      height: size.height - 4))
        body.isDynamic         = false
        body.categoryBitMask   = GameConstants.Category.gate | GameConstants.Category.wall
        body.collisionBitMask  = GameConstants.Category.player | GameConstants.Category.pushable
        body.contactTestBitMask = 0
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func buildVisual() {
        // Iron-bar look using a rounded rect
        let bar = SKShapeNode(rectOf: CGSize(width: size.width - 8, height: size.height - 4),
                              cornerRadius: 4)
        bar.fillColor   = SKColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
        bar.strokeColor = SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
        bar.lineWidth   = 3
        bar.name        = "gateBar"
        addChild(bar)

        // Padlock emoji on top
        let lock = SKLabelNode(text: "🔒")
        lock.fontSize = 18
        lock.position = CGPoint(x: 0, y: 2)
        lock.verticalAlignmentMode = .center
        lock.name = "padlock"
        addChild(lock)
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        physicsBody = nil   // stop blocking

        // Slide upward and fade
        let slide = SKAction.moveBy(x: 0, y: size.height, duration: 0.4)
        slide.timingMode = .easeIn
        run(.sequence([
            .run { [weak self] in
                // Swap lock to unlock
                (self?.childNode(withName: "padlock") as? SKLabelNode)?.text = "🔓"
            },
            .wait(forDuration: 0.1),
            .group([slide, .fadeOut(withDuration: 0.35)]),
            .removeFromParent()
        ]))
    }
}

// MARK: - Treasure Chest

/// A chest that pops open and drops items when approached.
@MainActor
final class TreasureChestNode: SKSpriteNode {

    var onOpen: ((_ position: CGPoint) -> Void)?
    private(set) var hasBeenOpened = false

    init() {
        let tex = SpriteFactory.emojiTexture("📦", size: 96)
        super.init(texture: tex, color: .clear, size: CGSize(width: 40, height: 40))
        name = "chest"
        zPosition = GameConstants.ZPos.item

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 36, height: 36))
        body.isDynamic          = false
        body.categoryBitMask    = GameConstants.Category.item
        body.contactTestBitMask = GameConstants.Category.player
        body.collisionBitMask   = 0
        physicsBody = body

        // Gentle pulse to draw attention
        let pulse = SKAction.sequence([
            .scale(to: 1.08, duration: 0.6),
            .scale(to: 1.0,  duration: 0.6)
        ])
        run(.repeatForever(pulse))
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func popOpen() {
        guard !hasBeenOpened else { return }
        hasBeenOpened = true
        physicsBody = nil
        texture = SpriteFactory.emojiTexture("🎁", size: 96)

        run(.sequence([
            .group([
                .scale(to: 1.4, duration: 0.15),
                .rotate(byAngle: 0.3, duration: 0.15)
            ]),
            .group([
                .scale(to: 1.0, duration: 0.1),
                .rotate(byAngle: -0.3, duration: 0.1)
            ]),
            .run { [weak self] in
                guard let self else { return }
                self.onOpen?(self.position)
            }
        ]))
    }
}
