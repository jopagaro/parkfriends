import SpriteKit

#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Injected from SwiftUI
    weak var gameState: GameState?
    weak var dialogue:  DialogueManager?

    // MARK: - World nodes
    private var worldRoot:     SKNode!
    private var player:        PlayerNode!
    private var followers:     [SKSpriteNode] = []
    private var followerSpecies: [Species]    = []
    private var npcs:          [NPCNode]      = []
    private var enemies:       [EnemyNode]    = []
    private var items:         [ItemNode]     = []
    private var activeAttacks: [AttackNode]   = []

    // Puzzle
    private var pressurePlate: PressurePlateNode?
    private var gate:          GateNode?
    private var chest:         TreasureChestNode?

    // MARK: - Camera / HUD nodes (stay on cam, never rebuilt)
    private let cam = SKCameraNode()
    private var joystick:     VirtualJoystick!
    private var attackButton: ActionButton!
    private var talkButton:   ActionButton!
    private var switchButton: ActionButton!
    private var hintLabel:    SKLabelNode?

    // MARK: - State
    private weak var nearbyNPC:    NPCNode?
    private var lastDamageTime:    TimeInterval = 0
    private let damageCooldown:    TimeInterval = 0.9
    private var lastUpdate:        TimeInterval = 0
    private var pendingSpawn:      CGPoint      = .zero

    // Follower trail
    private var trail:            [CGPoint] = []
    private let trailSpacing                = 18

    // MARK: - Keyboard (macOS)
    private var pressedKeys: Set<UInt16> = []

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.47, green: 0.73, blue: 0.36, alpha: 1)
        physicsWorld.gravity         = .zero
        physicsWorld.contactDelegate = self
        physicsWorld.speed           = 1.0

        CharacterSprites.preload()

        buildWorld()
        buildPlayerAndFollowers()
        buildCameraAndControls()

#if canImport(AppKit)
        // Give the view first-responder so it receives key events.
        DispatchQueue.main.async { [weak view] in
            view?.window?.makeFirstResponder(view)
        }
#endif
    }

    func restart() {
        worldRoot?.removeFromParent()
        followers.removeAll()
        followerSpecies.removeAll()
        npcs.removeAll()
        enemies.removeAll()
        items.removeAll()
        activeAttacks.removeAll()
        pressurePlate = nil
        gate          = nil
        chest         = nil
        nearbyNPC     = nil
        trail.removeAll()
        lastUpdate    = 0
        lastDamageTime = 0
        pressedKeys.removeAll()

        buildWorld()
        buildPlayerAndFollowers()
        refreshPartySprites()
        layoutControls()
    }

    // MARK: - Build helpers

    private func buildWorld() {
        let result = ParkWorld.build()
        worldRoot      = result.root
        addChild(worldRoot)
        pendingSpawn   = result.playerSpawn

        // Items
        let kinds = ItemKind.allCases
        for (i, pos) in result.itemSpawns.enumerated() {
            let item = ItemNode(kind: kinds[i % kinds.count])
            item.position = pos
            worldRoot.addChild(item)
            items.append(item)
        }

        // NPCs
        let npcKinds = NPCKind.allCases
        for (i, pos) in result.npcSpawns.enumerated() {
            let npc = NPCNode(kind: npcKinds[i % npcKinds.count])
            npc.position = pos
            worldRoot.addChild(npc)
            npcs.append(npc)
        }

        // Enemies
        let enemyKinds: [EnemyKind] = [.ranger, .sternAdult, .wasp, .ranger]
        for (i, pos) in result.enemySpawns.enumerated() {
            let enemy        = EnemyNode(kind: enemyKinds[i % enemyKinds.count])
            enemy.position   = pos
            enemy.patrolOrigin = pos
            worldRoot.addChild(enemy)
            enemies.append(enemy)
        }

        // Puzzle wiring
        pressurePlate = result.pressurePlate
        gate          = result.gate
        chest         = result.chest

        result.pressurePlate.onActivate = { [weak self] in self?.gate?.open() }
        result.chest.onOpen             = { [weak self] pos in self?.spawnTreasure(at: pos) }
    }

    private func buildPlayerAndFollowers() {
        let state = gameState ?? GameState()
        player          = PlayerNode(species: state.activeSpecies)
        player.position = pendingSpawn
        worldRoot.addChild(player)

        followerSpecies = state.party.map(\.species).filter { $0 != state.activeSpecies }
        for spec in followerSpecies {
            let f = SKSpriteNode(texture: CharacterSprites.texture(species: spec, frame: .a))
            f.size      = CGSize(width: 48, height: 48)
            f.zPosition = GameConstants.ZPos.entity - 0.1
            f.alpha     = 0.88
            f.position  = pendingSpawn
            worldRoot.addChild(f)
            followers.append(f)
        }
    }

    private func buildCameraAndControls() {
        addChild(cam)
        camera      = cam
        cam.position = pendingSpawn

        joystick     = VirtualJoystick(radius: 65)
        cam.addChild(joystick)

        attackButton = ActionButton(glyph: "⚔️", radius: 40, tint: .orange)
        attackButton.onTap = { [weak self] in self?.fireAttack() }
        cam.addChild(attackButton)

        talkButton   = ActionButton(glyph: "💬", radius: 30, tint: .blue)
        talkButton.onTap = { [weak self] in self?.handleTalk() }
        talkButton.alpha = 0
        cam.addChild(talkButton)

        switchButton = ActionButton(glyph: gameState?.activeSpecies.emoji ?? "🐢",
                                    radius: 26, tint: .purple)
        switchButton.onTap = { [weak self] in self?.cycleParty() }
        cam.addChild(switchButton)

#if canImport(AppKit)
        // On Mac we drive everything with keyboard/mouse — hide touch controls.
        joystick.isHidden     = true
        attackButton.isHidden = true
        talkButton.isHidden   = true
        switchButton.isHidden = true

        let hint = SKLabelNode(text: "WASD / ↑↓←→  Move   ·   Space  Attack   ·   E  Talk   ·   Tab  Switch")
        hint.fontName                  = "Helvetica Neue"
        hint.fontSize                  = 12
        hint.fontColor                 = SKColor(white: 1, alpha: 0.65)
        hint.horizontalAlignmentMode   = .center
        hint.verticalAlignmentMode     = .bottom
        hint.zPosition                 = GameConstants.ZPos.ui
        cam.addChild(hint)
        hintLabel = hint
#endif

        layoutControls()
    }

    private func layoutControls() {
        guard joystick != nil else { return }
        let w = size.width, h = size.height

#if canImport(AppKit)
        hintLabel?.position = CGPoint(x: 0, y: -h / 2 + 8)
#else
        joystick.position     = CGPoint(x: -w / 2 + 100, y: -h / 2 + 100)
        attackButton.position = CGPoint(x:  w / 2 - 65,  y: -h / 2 + 80)
        talkButton.position   = CGPoint(x:  w / 2 - 65,  y: -h / 2 + 148)
        switchButton.position = CGPoint(x:  w / 2 - 38,  y:  h / 2 - 50)
#endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutControls()
    }

    // MARK: - macOS input

#if canImport(AppKit)
    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        pressedKeys.insert(event.keyCode)

        switch event.keyCode {
        case 49: fireAttack()   // Space
        case 14: handleTalk()   // E
        case 48: cycleParty()   // Tab
        default: break
        }
    }

    override func keyUp(with event: NSEvent) {
        pressedKeys.remove(event.keyCode)
    }

    override func mouseDown(with event: NSEvent) {
        fireAttack()
    }

    /// Returns a normalised direction vector from currently pressed keys.
    private func directionFromKeys() -> CGVector {
        var dx: CGFloat = 0, dy: CGFloat = 0
        // W = 13, S = 1, A = 0, D = 2
        // arrows: up = 126, down = 125, left = 123, right = 124
        if pressedKeys.contains(13)  || pressedKeys.contains(126) { dy += 1 }
        if pressedKeys.contains(1)   || pressedKeys.contains(125) { dy -= 1 }
        if pressedKeys.contains(0)   || pressedKeys.contains(123) { dx -= 1 }
        if pressedKeys.contains(2)   || pressedKeys.contains(124) { dx += 1 }
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return .zero }
        return CGVector(dx: dx / len, dy: dy / len)
    }
#endif

    // MARK: - Party management

    private func cycleParty() {
        guard let state = gameState else { return }
        let start = state.activeIndex
        for step in 1...state.party.count {
            let idx = (start + step) % state.party.count
            if state.party[idx].hp > 0 { state.activeIndex = idx; break }
        }
        refreshPartySprites()
    }

    private func refreshPartySprites() {
        guard let state = gameState else { return }
        player.setSpecies(state.activeSpecies)
        switchButton.setGlyph(state.activeSpecies.emoji)

        followerSpecies = state.party.map(\.species).filter { $0 != state.activeSpecies }
        for (i, spec) in followerSpecies.enumerated() where i < followers.count {
            followers[i].texture = CharacterSprites.texture(species: spec, frame: .a)
        }
    }

    // MARK: - Talk

    private func handleTalk() {
        guard let npc      = nearbyNPC,
              let state    = gameState,
              let dialogue = dialogue else { return }
        dialogue.startConversation(with: npc.kind, asSpecies: state.activeSpecies)
    }

    private func showTalkButton(_ visible: Bool) {
#if !canImport(AppKit)
        talkButton.run(.fadeAlpha(to: visible ? 1 : 0, duration: 0.15))
#endif
        // On Mac the button is hidden; proximity feedback comes from NPC bubble only.
        _ = visible
    }

    // MARK: - Attack

    private func fireAttack() {
        guard let state = gameState else { return }
        let now      = CACurrentMediaTime()
        let cooldown = state.activeSpecies.attackCooldown
        let last     = state.lastAttackTime[state.activeSpecies] ?? 0
        guard now - last >= cooldown else { return }

        state.recordAttack(now: now)
        player.playAttackPunch()

        let attack = AttackNode(
            species: state.activeSpecies,
            at:      player.position,
            facing:  player.facing
        )
        worldRoot.addChild(attack)
        activeAttacks.append(attack)
    }

    // MARK: - Treasure

    private func spawnTreasure(at position: CGPoint) {
        let drops: [ItemKind] = [.key, .coin, .berry]
        for (i, kind) in drops.enumerated() {
            let item  = ItemNode(kind: kind)
            let angle = CGFloat(i) / CGFloat(drops.count) * 2 * .pi
            item.position = CGPoint(
                x: position.x + cos(angle) * 28,
                y: position.y + sin(angle) * 28
            )
            worldRoot.addChild(item)
            items.append(item)
        }
        DamageLabel.spawn(text: "✨ Chest opened!", color: .yellow,
                          at: CGPoint(x: position.x, y: position.y + 30),
                          in: worldRoot)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdate, 0.05)
        lastUpdate = currentTime

        // Freeze everything during dialogue
        guard dialogue?.activeNPC == nil else {
            player.physicsBody?.velocity = .zero
            enemies.forEach { $0.physicsBody?.velocity = .zero }
            pressedKeys.removeAll()
            return
        }

        // Direction from keyboard (Mac) or joystick (iOS)
#if canImport(AppKit)
        let dir = directionFromKeys()
#else
        let dir = joystick.direction
#endif
        player.move(direction: dir)

        // Follower trail
        trail.insert(player.position, at: 0)
        let maxLen = (followers.count + 1) * trailSpacing + 1
        if trail.count > maxLen { trail.removeLast(trail.count - maxLen) }
        for (i, f) in followers.enumerated() {
            let idx = min((i + 1) * trailSpacing, trail.count - 1)
            if idx >= 0 {
                let t  = trail[idx]
                let dx = t.x - f.position.x
                let dy = t.y - f.position.y
                f.position.x += dx * 0.28
                f.position.y += dy * 0.28
                if abs(dx) > 0.5 { f.xScale = dx < 0 ? -1 : 1 }

                // Simple 2-frame walk for followers
                let moving = sqrt(dx * dx + dy * dy) > 1.5
                if moving {
                    let frameKey = Int(currentTime / 0.18) % 2
                    let spec = i < followerSpecies.count ? followerSpecies[i] : .turtle
                    f.texture = CharacterSprites.texture(
                        species: spec,
                        frame: frameKey == 0 ? .a : .b
                    )
                }
            }
        }

        // Enemies
        enemies.forEach { $0.tick(now: currentTime, playerPos: player.position) }

        // Projectile range check
        activeAttacks = activeAttacks.filter { atk in
            guard atk.parent != nil else { return false }
            atk.checkRange()
            return atk.parent != nil
        }

        // NPC proximity → show/hide talk button
        let nearNPC = npcs.first { npc in
            let dx = npc.position.x - player.position.x
            let dy = npc.position.y - player.position.y
            return dx * dx + dy * dy < 70 * 70
        }
        if nearNPC !== nearbyNPC {
            nearbyNPC = nearNPC
            showTalkButton(nearNPC != nil)
        }

        // Smooth camera lerp
        let world = GameConstants.worldSize
        let hw = size.width / 2, hh = size.height / 2
        let targetX = min(max(player.position.x, hw), world.width  - hw)
        let targetY = min(max(player.position.y, hh), world.height - hh)
        let lerp: CGFloat = 0.10
        cam.position = CGPoint(
            x: cam.position.x + (targetX - cam.position.x) * lerp,
            y: cam.position.y + (targetY - cam.position.y) * lerp
        )

        _ = dt
    }

    // MARK: - Physics contacts

    func didBegin(_ contact: SKPhysicsContact) {
        handlePair(contact.bodyA, contact.bodyB)
        handlePair(contact.bodyB, contact.bodyA)
    }

    func didEnd(_ contact: SKPhysicsContact) {}

    private func handlePair(_ first: SKPhysicsBody, _ second: SKPhysicsBody) {
        switch first.categoryBitMask {

        case GameConstants.Category.player:
            switch second.categoryBitMask {
            case GameConstants.Category.item:
                if let item = second.node as? ItemNode { collectItem(item) }
            case GameConstants.Category.enemy:
                if let enemy = second.node as? EnemyNode { playerHitByEnemy(enemy) }
            default: break
            }
            // Chest uses .item category — check by type
            if second.categoryBitMask == GameConstants.Category.item,
               let ch = second.node as? TreasureChestNode {
                ch.popOpen()
            }

        case GameConstants.Category.attack:
            if second.categoryBitMask == GameConstants.Category.enemy,
               let atk   = first.node  as? AttackNode,
               let enemy = second.node as? EnemyNode {
                attackHitEnemy(atk, enemy: enemy)
            }

        case GameConstants.Category.pushable:
            if second.categoryBitMask == GameConstants.Category.pressurePlate,
               let plate = second.node as? PressurePlateNode {
                plate.activate()
            }

        default: break
        }
    }

    // MARK: - Contact handlers

    private func collectItem(_ item: ItemNode) {
        guard item.parent != nil else { return }
        gameState?.collect(item.kind)
        DamageLabel.collect(
            "+\(item.kind.displayName)",
            at: CGPoint(x: item.position.x, y: item.position.y + 24),
            in: worldRoot
        )
        let pop = SKAction.group([
            .scale(to: 1.5, duration: 0.12),
            .fadeOut(withDuration: 0.12)
        ])
        item.run(.sequence([pop, .removeFromParent()]))
        items.removeAll { $0 === item }
    }

    private func playerHitByEnemy(_ enemy: EnemyNode) {
        let now = CACurrentMediaTime()
        guard now - lastDamageTime > damageCooldown else { return }
        lastDamageTime = now
        gameState?.takeDamage(enemy.kind.contactDamage)
        player.flashDamage()

        // Knockback
        let dx  = player.position.x - enemy.position.x
        let dy  = player.position.y - enemy.position.y
        let len = max(sqrt(dx * dx + dy * dy), 0.01)
        player.physicsBody?.applyImpulse(CGVector(dx: dx / len * 100, dy: dy / len * 100))

        if let state = gameState, state.party[state.activeIndex].hp == 0 {
            refreshPartySprites()
        }
    }

    private func attackHitEnemy(_ attack: AttackNode, enemy: EnemyNode) {
        let id = ObjectIdentifier(enemy)
        guard !attack.hitEnemies.contains(id), !enemy.isDead else { return }
        attack.hitEnemies.insert(id)

        let defeated = enemy.takeDamage(attack.damage)
        DamageLabel.damage(
            attack.damage,
            at: CGPoint(x: enemy.position.x, y: enemy.position.y + 30),
            in: worldRoot
        )

        if defeated { defeatEnemy(enemy) }
    }

    private func defeatEnemy(_ enemy: EnemyNode) {
        guard let state = gameState else { return }
        let kind = enemy.kind
        enemies.removeAll { $0 === enemy }

        enemy.playDeathAndRemove {}

        DamageLabel.score(
            kind.defeatScore,
            at: CGPoint(x: enemy.position.x, y: enemy.position.y + 44),
            in: worldRoot
        )

        state.defeatEnemy(kind: kind)

        // Respawn the same enemy kind after a delay
        let spawnPos = CGPoint(
            x: enemy.position.x + CGFloat.random(in: -60...60),
            y: enemy.position.y + CGFloat.random(in: -60...60)
        )
        run(.wait(forDuration: 12)) { [weak self] in
            guard let self, let _ = self.gameState else { return }
            let newEnemy        = EnemyNode(kind: kind)
            newEnemy.position   = spawnPos
            newEnemy.patrolOrigin = spawnPos
            self.worldRoot.addChild(newEnemy)
            self.enemies.append(newEnemy)
            DamageLabel.spawn(text: "!", color: .orange,
                              at: CGPoint(x: spawnPos.x, y: spawnPos.y + 36),
                              in: self.worldRoot)
        }
    }
}
