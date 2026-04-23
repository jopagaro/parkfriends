import SpriteKit

enum EnemyKind: String, CaseIterable {
    case ranger, sternAdult, wasp

    var emoji: String {
        switch self {
        case .ranger:     "👮"
        case .sternAdult: "🧑‍💼"
        case .wasp:       "🐝"
        }
    }

    var displayName: String {
        switch self {
        case .ranger:     "Park Ranger"
        case .sternAdult: "Stern Adult"
        case .wasp:       "Angry Wasp"
        }
    }

    var maxHP: Int {
        switch self {
        case .ranger:     6
        case .sternAdult: 4
        case .wasp:       2
        }
    }

    var speed: CGFloat {
        switch self {
        case .ranger:     80
        case .sternAdult: 70
        case .wasp:       130
        }
    }

    var visionRadius: CGFloat {
        switch self {
        case .ranger:     180
        case .sternAdult: 150
        case .wasp:       120
        }
    }

    var contactDamage: Int {
        switch self {
        case .ranger:     2
        case .sternAdult: 1
        case .wasp:       1
        }
    }

    var defeatScore: Int {
        switch self {
        case .ranger:     50
        case .sternAdult: 30
        case .wasp:       15
        }
    }
}

@MainActor
final class EnemyNode: SKSpriteNode {
    let kind: EnemyKind
    var patrolOrigin: CGPoint = .zero

    private(set) var hp: Int
    var isDead: Bool { hp <= 0 }

    private var nextMoveTime: TimeInterval = 0
    private var hpBarBg: SKSpriteNode!
    private var hpBarFill: SKSpriteNode!

    init(kind: EnemyKind) {
        self.kind = kind
        self.hp = kind.maxHP

        let tex = SpriteFactory.emojiTexture(kind.emoji, size: 96)
        super.init(texture: tex, color: .clear, size: CGSize(width: 48, height: 48))
        name = "enemy"
        zPosition = GameConstants.ZPos.entity

        let body = SKPhysicsBody(circleOfRadius: 20)
        body.allowsRotation = false
        body.linearDamping = 4
        body.categoryBitMask   = GameConstants.Category.enemy
        body.collisionBitMask  = GameConstants.Category.wall
        body.contactTestBitMask =
            GameConstants.Category.player |
            GameConstants.Category.attack
        physicsBody = body

        buildHPBar()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - HP bar

    private func buildHPBar() {
        let barW: CGFloat = 38
        let barH: CGFloat = 5

        hpBarBg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.5),
                               size: CGSize(width: barW, height: barH))
        hpBarBg.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBarBg.position = CGPoint(x: -barW / 2, y: 30)
        hpBarBg.zPosition = 1
        addChild(hpBarBg)

        hpBarFill = SKSpriteNode(color: .green,
                                 size: CGSize(width: barW, height: barH))
        hpBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpBarFill.position = .zero
        hpBarFill.zPosition = 1
        hpBarBg.addChild(hpBarFill)
    }

    private func refreshHPBar() {
        let frac = CGFloat(max(hp, 0)) / CGFloat(kind.maxHP)
        let barW: CGFloat = 38
        hpBarFill.size.width = barW * frac
        hpBarFill.color = frac > 0.5 ? .green : (frac > 0.25 ? .yellow : .red)
    }

    // MARK: - Combat

    /// Returns true if the enemy should be removed (dead).
    func takeDamage(_ amount: Int) -> Bool {
        guard !isDead else { return true }
        hp = max(0, hp - amount)
        refreshHPBar()

        // Hit flash
        removeAction(forKey: "hitFlash")
        let flash = SKAction.sequence([
            .colorize(with: .white, colorBlendFactor: 0.9, duration: 0.04),
            .colorize(withColorBlendFactor: 0, duration: 0.12)
        ])
        run(flash, withKey: "hitFlash")

        return isDead
    }

    func playDeathAndRemove(completion: @escaping () -> Void) {
        physicsBody = nil
        let die = SKAction.sequence([
            .group([
                .scale(to: 1.5, duration: 0.15),
                .fadeOut(withDuration: 0.15)
            ]),
            .removeFromParent(),
            .run(completion)
        ])
        run(die)
    }

    // MARK: - AI

    func tick(now: TimeInterval, playerPos: CGPoint) {
        guard !isDead, let body = physicsBody else { return }

        let dx = playerPos.x - position.x
        let dy = playerPos.y - position.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < kind.visionRadius {
            let len = max(dist, 0.001)
            body.velocity = CGVector(
                dx: dx / len * kind.speed,
                dy: dy / len * kind.speed
            )
            xScale = dx < 0 ? -1 : 1
        } else {
            if now >= nextMoveTime {
                nextMoveTime = now + Double.random(in: 1.5...3.5)
                let angle = CGFloat.random(in: 0 ..< 2 * .pi)
                body.velocity = CGVector(
                    dx: cos(angle) * kind.speed * 0.4,
                    dy: sin(angle) * kind.speed * 0.4
                )
            }
            let homeDx = position.x - patrolOrigin.x
            let homeDy = position.y - patrolOrigin.y
            if homeDx * homeDx + homeDy * homeDy > 200 * 200 {
                body.velocity = CGVector(dx: -homeDx * 0.5, dy: -homeDy * 0.5)
            }
        }
    }
}
