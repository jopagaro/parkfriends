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
    private var benchPositions: [CGPoint]    = []
    private var zoneExitNodes:  [ZoneExitNode] = []

    // Puzzle
    private var pressurePlate: PressurePlateNode?
    private var gate:          GateNode?
    private var chest:         TreasureChestNode?

    // Quack side-quest
    private var quackNode:     QuackNode?
    private var nearbyQuack:   Bool = false

    // MARK: - Camera / overlay nodes
    private let cam = SKCameraNode()
    private var joystick:     VirtualJoystick!
    private var talkButton:   ActionButton!
    private var switchButton: ActionButton!
    private var hintLabel:    SKLabelNode?
    private var battleNode:   BattleNode!
    private var fadeOverlay:  SKSpriteNode?  // zone-transition blackout

    // MARK: - State
    private weak var nearbyNPC:     NPCNode?
    private var nearbyBench:        Bool        = false
    private var lastDamageTime:     TimeInterval = 0
    private let damageCooldown:     TimeInterval = 0.9
    private var lastUpdate:         TimeInterval = 0
    private var pendingSpawn:       CGPoint      = .zero
    private var lastBattleEndTime:  TimeInterval = 0
    private let battleReengageCooldown: TimeInterval = 2.0
    private var isTransitioning:    Bool         = false

    // Follower trail
    private var trail:           [CGPoint] = []
    private let trailSpacing               = 18

    // MARK: - Keyboard (macOS)
    private var pressedKeys: Set<UInt16> = []

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = GamePalette.grassG1
        physicsWorld.gravity         = .zero
        physicsWorld.contactDelegate = self
        physicsWorld.speed           = 1.0

        CharacterSprites.preload()
        WorldSprites.preload()

        buildWorld()
        buildPlayerAndFollowers()
        buildCameraAndControls()

#if canImport(AppKit)
        DispatchQueue.main.async { [weak view] in
            view?.window?.makeFirstResponder(view)
        }
#endif
    }

    func restart() {
        tearDownWorld()
        buildWorld()
        buildPlayerAndFollowers()
        refreshPartySprites()
        layoutControls()
    }

    // MARK: - Build

    private func tearDownWorld() {
        worldRoot?.removeFromParent()
        followers.removeAll()
        followerSpecies.removeAll()
        npcs.removeAll()
        enemies.removeAll()
        items.removeAll()
        benchPositions.removeAll()
        zoneExitNodes.removeAll()
        pressurePlate = nil; gate = nil; chest = nil
        quackNode     = nil
        nearbyNPC     = nil
        nearbyBench   = false
        nearbyQuack   = false
        trail.removeAll()
        lastUpdate = 0; lastDamageTime = 0; lastBattleEndTime = 0
        pressedKeys.removeAll()
    }

    private func buildWorld() {
        let zone = gameState?.currentZone ?? .parkCenter
        switch zone {
        case .parkCenter: buildParkCenter()
        case .parkNorth:  buildParkNorth()
        case .citySouth:  buildCitySouth()
        case .cityCenter: buildCityCenter()
        case .cityNorth:  buildCityNorth()
        }
    }

    private func buildParkCenter() {
        backgroundColor = GamePalette.grassG1
        let result = ParkWorld.buildCenter()
        finishWorldBuild(
            root: result.root,
            playerSpawn: result.playerSpawn,
            itemSpawns: result.itemSpawns,
            fixedItems: result.fixedItems,
            npcSpawns: result.npcSpawns,
            enemySpawns: result.enemySpawns,
            benchPositions: result.benchPositions,
            zoneExitNodes: result.zoneExitNodes
        )
        pressurePlate = result.pressurePlate
        gate          = result.gate
        chest         = result.chest
        wirePuzzleIfNeeded(result)
    }

    private func buildParkNorth() {
        backgroundColor = GamePalette.grassG1
        let result = ParkWorld.buildNorth()
        finishWorldBuild(
            root: result.root,
            playerSpawn: result.playerSpawn,
            itemSpawns: result.itemSpawns,
            fixedItems: result.fixedItems,
            npcSpawns: result.npcSpawns,
            enemySpawns: result.enemySpawns,
            benchPositions: result.benchPositions,
            zoneExitNodes: result.zoneExitNodes
        )
        pressurePlate = result.pressurePlate
        gate          = result.gate
        chest         = result.chest
        wirePuzzleIfNeeded(result)
        // Auto-mark story clue: player arrived at the pond area
        gameState?.quackClues.insert(.visitedNorthPond)
    }

    private func wirePuzzleIfNeeded(_ result: ParkWorld.BuildResult) {
        result.pressurePlate?.onActivate = { [weak self] in self?.gate?.open() }
        result.chest?.onOpen = { [weak self] pos in self?.spawnTreasure(at: pos) }
    }

    private func buildCitySouth() {
        backgroundColor = GamePalette.asphalt1
        let result = CitySouthWorld.build()
        finishWorldBuild(
            root: result.root,
            playerSpawn: result.playerSpawn,
            itemSpawns: result.itemSpawns,
            fixedItems: [],
            npcSpawns: result.npcSpawns,
            enemySpawns: result.enemySpawns,
            benchPositions: result.benchPositions,
            zoneExitNodes: result.zoneExitNodes
        )
        pressurePlate = nil; gate = nil; chest = nil; quackNode = nil
    }

    private func buildCityCenter() {
        backgroundColor = GamePalette.asphalt1
        let result = CityWorld.build()
        finishWorldBuild(
            root: result.root,
            playerSpawn: result.playerSpawn,
            itemSpawns: result.itemSpawns,
            fixedItems: [],
            npcSpawns: result.npcSpawns,
            enemySpawns: result.enemySpawns,
            benchPositions: result.benchPositions,
            zoneExitNodes: result.zoneExitNodes
        )
        pressurePlate = nil; gate = nil; chest = nil; quackNode = nil
    }

    private func buildCityNorth() {
        backgroundColor = GamePalette.dirtD3
        let result = CityNorthWorld.build()
        finishWorldBuild(
            root: result.root,
            playerSpawn: result.playerSpawn,
            itemSpawns: result.itemSpawns,
            fixedItems: result.fixedItems,
            npcSpawns: result.npcSpawns,
            enemySpawns: result.enemySpawns,
            benchPositions: result.benchPositions,
            zoneExitNodes: result.zoneExitNodes
        )
        pressurePlate = nil; gate = nil; chest = nil
        quackNode = result.quackNode
        // Wire rescue callback
        quackNode?.onRescue = { [weak self] in self?.handleQuackRescued() }
    }

    private func finishWorldBuild(
        root: SKNode,
        playerSpawn: CGPoint,
        itemSpawns: [CGPoint],
        fixedItems: [(ItemKind, CGPoint)],
        npcSpawns: [CGPoint],
        enemySpawns: [(EnemyKind, CGPoint)],
        benchPositions: [CGPoint],
        zoneExitNodes: [ZoneExitNode]
    ) {
        worldRoot    = root
        pendingSpawn = playerSpawn
        self.benchPositions = benchPositions
        self.zoneExitNodes  = zoneExitNodes
        addChild(worldRoot)

        // Fixed story items (always same kind + position)
        for (kind, pos) in fixedItems {
            // Skip quackFeather if already collected
            if kind == .quackFeather && (gameState?.inventory[.quackFeather] ?? 0) > 0 { continue }
            let item = ItemNode(kind: kind)
            item.position = pos
            worldRoot.addChild(item)
            items.append(item)
        }

        // Random/rotating items
        let kinds = ItemKind.allCases
        for (i, pos) in itemSpawns.enumerated() {
            let item = ItemNode(kind: kinds[i % kinds.count])
            item.position = pos
            worldRoot.addChild(item)
            items.append(item)
        }

        let npcKinds = NPCKind.allCases
        for (i, pos) in npcSpawns.enumerated() {
            let npc = NPCNode(kind: npcKinds[i % npcKinds.count])
            npc.position = pos
            worldRoot.addChild(npc)
            npcs.append(npc)
        }

        for (kind, pos) in enemySpawns {
            let enemy          = EnemyNode(kind: kind)
            enemy.position     = pos
            enemy.patrolOrigin = pos
            worldRoot.addChild(enemy)
            enemies.append(enemy)
        }
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

        joystick = VirtualJoystick(radius: 65)
        cam.addChild(joystick)

        talkButton = ActionButton(glyph: "💬", radius: 30, tint: .blue)
        talkButton.onTap = { [weak self] in self?.handleTalk() }
        talkButton.alpha = 0
        cam.addChild(talkButton)

        switchButton = ActionButton(glyph: gameState?.activeSpecies.emoji ?? "🐢",
                                    radius: 26, tint: .purple)
        switchButton.onTap = { [weak self] in self?.cycleParty() }
        cam.addChild(switchButton)

        // Battle overlay (always on camera, initially hidden)
        battleNode = BattleNode()
        battleNode.onVictory = { [weak self] kind in self?.handleBattleVictory(kind: kind) }
        battleNode.onDefeat  = { [weak self] in self?.handleBattleDefeat() }
        battleNode.onFled    = { [weak self] in self?.handleBattleFled() }
        cam.addChild(battleNode)

        addVignette()

#if canImport(AppKit)
        joystick.isHidden     = true
        talkButton.isHidden   = true
        switchButton.isHidden = true

        let hint = SKLabelNode(
            text: "WASD/↑↓←→ Move  ·  E Talk/Rest  ·  Tab Switch  ·  walk into enemies to battle")
        hint.fontName                = "Helvetica Neue"
        hint.fontSize                = 12
        hint.fontColor               = SKColor(white: 1, alpha: 0.55)
        hint.horizontalAlignmentMode = .center
        hint.verticalAlignmentMode   = .bottom
        hint.zPosition               = GameConstants.ZPos.ui
        cam.addChild(hint)
        hintLabel = hint
#endif

        layoutControls()
    }

    private func layoutControls() {
        guard joystick != nil else { return }
        let w = size.width, h = size.height

#if canImport(AppKit)
        hintLabel?.position  = CGPoint(x: 0, y: -h/2 + 8)
#else
        joystick.position     = CGPoint(x: -w/2 + 100, y: -h/2 + 100)
        talkButton.position   = CGPoint(x:  w/2 - 65,  y: -h/2 + 148)
        switchButton.position = CGPoint(x:  w/2 - 38,  y:  h/2 - 50)
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

        if battleNode.phase == .playerMenu {
            battleNode.handleKey(event.keyCode)
            return
        }

        switch event.keyCode {
        case 14: handleInteract()   // E
        case 48: cycleParty()       // Tab
        default: break
        }
    }

    override func keyUp(with event: NSEvent) {
        pressedKeys.remove(event.keyCode)
    }

    private func directionFromKeys() -> CGVector {
        var dx: CGFloat = 0, dy: CGFloat = 0
        if pressedKeys.contains(13) || pressedKeys.contains(126) { dy += 1 }   // W / ↑
        if pressedKeys.contains(1)  || pressedKeys.contains(125) { dy -= 1 }   // S / ↓
        if pressedKeys.contains(0)  || pressedKeys.contains(123) { dx -= 1 }   // A / ←
        if pressedKeys.contains(2)  || pressedKeys.contains(124) { dx += 1 }   // D / →
        let len = sqrt(dx*dx + dy*dy)
        guard len > 0 else { return .zero }
        return CGVector(dx: dx/len, dy: dy/len)
    }
#endif

    // MARK: - Interaction (E key / talk button)

    /// Handles E key / talk button: talk to NPC, rescue Quack, or rest at bench.
    private func handleInteract() {
        if let npc = nearbyNPC {
            handleTalk(npc: npc)
        } else if nearbyQuack, let quack = quackNode, !quack.isRescued {
            quack.rescue()
        } else if nearbyBench {
            restAtBench()
        }
    }

    private func handleTalk() { handleInteract() }

    private func handleTalk(npc: NPCNode) {
        guard let state = gameState, let dialogue else { return }
        let clues = state.quackClues
        dialogue.activeQuackClues = clues
        dialogue.startConversation(with: npc.kind, asSpecies: state.activeSpecies,
                                   quackClues: clues)

        // Auto-mark NPC-specific story clues
        switch npc.kind {
        case .child        where clues.contains(.foundFeather):
            state.quackClues.insert(.childSawChase)
        case .jogger       where !clues.isEmpty:
            state.quackClues.insert(.joggerSawCity)
        default: break
        }
    }

    // MARK: - Quack rescue

    private func handleQuackRescued() {
        guard let state = gameState else { return }
        state.addClue(.quackRescued)
        state.score += 500
        state.gainExp(300)

        // Firework celebration on camera
        let confetti = ["🎉", "🎊", "🦆", "✨", "⭐️"]
        for i in 0..<20 {
            let label = SKLabelNode(text: confetti[i % confetti.count])
            label.fontSize = CGFloat.random(in: 18...36)
            label.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                     y: CGFloat.random(in: -size.height/2...size.height/2))
            label.zPosition = GameConstants.ZPos.ui + 5
            label.alpha = 0
            cam.addChild(label)
            label.run(.sequence([
                .wait(forDuration: Double(i) * 0.08),
                .group([
                    .fadeIn(withDuration: 0.2),
                    .moveBy(x: CGFloat.random(in: -80...80),
                            y: CGFloat.random(in: 40...140),
                            duration: 1.2)
                ]),
                .fadeOut(withDuration: 0.4),
                .removeFromParent()
            ]))
        }

        DamageLabel.spawn(text: "🦆 Quack is safe! +500 ⭐  +300 EXP",
                          color: .yellow,
                          at: CGPoint(x: player.position.x, y: player.position.y + 60),
                          in: worldRoot)
    }

    private func showTalkButton(_ visible: Bool) {
#if !canImport(AppKit)
        talkButton.run(.fadeAlpha(to: visible ? 1 : 0, duration: 0.15))
#endif
        _ = visible
    }

    // MARK: - Bench rest

    private func restAtBench() {
        guard let state = gameState, !isTransitioning else { return }

        state.fullHeal()
        state.save()

        // Floating "Rested! 💤" message
        if let player = player {
            DamageLabel.spawn(text: "Rested! 💤  Game saved.",
                              color: .cyan,
                              at: CGPoint(x: player.position.x, y: player.position.y + 50),
                              in: worldRoot)
        }

        // Brief tint on screen
        let restFlash = SKSpriteNode(color: SKColor(white: 1, alpha: 0), size: size)
        restFlash.position  = .zero
        restFlash.zPosition = GameConstants.ZPos.ui + 10
        cam.addChild(restFlash)
        restFlash.run(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.3),
            .fadeOut(withDuration: 0.5),
            .removeFromParent()
        ]))
    }

    // MARK: - Party

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

    // MARK: - Battle trigger

    private func triggerBattle(with enemy: EnemyNode) {
        guard battleNode.phase == .none,
              !enemy.isDead,
              let state = gameState else { return }
        let now = CACurrentMediaTime()
        guard now - lastBattleEndTime > battleReengageCooldown else { return }

        player.physicsBody?.velocity = .zero
        pressedKeys.removeAll()
        enemies.forEach { $0.physicsBody?.velocity = .zero }

        battleNode.show(enemy: enemy, state: state)
    }

    // MARK: - Battle callbacks

    private func handleBattleVictory(kind: EnemyKind) {
        lastBattleEndTime = CACurrentMediaTime()
        if let idx = enemies.firstIndex(where: { $0.kind == kind && $0.isDead }) {
            let enemy = enemies[idx]
            enemies.remove(at: idx)
            enemy.playDeathAndRemove {}

            DamageLabel.score(kind.defeatScore,
                              at: CGPoint(x: enemy.position.x, y: enemy.position.y + 44),
                              in: worldRoot)

            let spawnPos = CGPoint(
                x: enemy.position.x + CGFloat.random(in: -80...80),
                y: enemy.position.y + CGFloat.random(in: -80...80)
            )
            run(.wait(forDuration: 15)) { [weak self] in
                guard let self else { return }
                let newEnemy          = EnemyNode(kind: kind)
                newEnemy.position     = spawnPos
                newEnemy.patrolOrigin = spawnPos
                self.worldRoot.addChild(newEnemy)
                self.enemies.append(newEnemy)
            }
        }
    }

    private func handleBattleDefeat() {
        lastBattleEndTime = CACurrentMediaTime()
    }

    private func handleBattleFled() {
        lastBattleEndTime = CACurrentMediaTime()
        let angle = CGFloat.random(in: 0 ..< 2 * .pi)
        player.physicsBody?.applyImpulse(CGVector(dx: cos(angle) * 160, dy: sin(angle) * 160))
    }

    // MARK: - Zone transition

    private func triggerZoneTransition(to destination: GameZone) {
        guard !isTransitioning, let state = gameState else { return }
        isTransitioning = true
        state.currentZone = destination

        // Black overlay on camera
        let overlay = SKSpriteNode(color: .black, size: size)
        overlay.position  = .zero
        overlay.zPosition = GameConstants.ZPos.ui + 100
        overlay.alpha     = 0
        cam.addChild(overlay)
        fadeOverlay = overlay

        overlay.run(.sequence([
            .fadeIn(withDuration: 0.45),
            .run { [weak self] in
                guard let self else { return }
                self.tearDownWorld()
                self.buildWorld()
                self.buildPlayerAndFollowers()
                self.cam.position = self.pendingSpawn
            },
            .wait(forDuration: 0.1),
            .fadeOut(withDuration: 0.45),
            .removeFromParent(),
            .run { [weak self] in self?.isTransitioning = false }
        ]))
    }

    // MARK: - Visual polish

    private func addVignette() {
        // Subtle dark vignette on camera edges — gives depth and focus to the play area.
        let vigSize = CGSize(width: 900, height: 900)
        let vig = SKShapeNode(rectOf: vigSize)
        vig.fillColor   = .clear
        vig.strokeColor = .clear
        vig.position    = .zero
        vig.zPosition   = GameConstants.ZPos.ui - 1

        // Build a radial gradient texture via CGContext
        let scale = 2
        let pw = Int(vigSize.width) * scale
        let ph = Int(vigSize.height) * scale
        if let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8,
                               bytesPerRow: pw * 4,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                                           CGImageAlphaInfo.premultipliedFirst.rawValue) {
            let cx = CGFloat(pw) / 2, cy = CGFloat(ph) / 2
            let r  = min(cx, cy) * 0.85
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    CGColor(red: 0, green: 0, blue: 0, alpha: 0),
                    CGColor(red: 0, green: 0, blue: 0, alpha: 0.48)
                ] as CFArray,
                locations: [0, 1]
            )
            if let gradient {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: cx, y: cy), startRadius: r * 0.45,
                    endCenter:   CGPoint(x: cx, y: cy), endRadius:   r,
                    options: [.drawsAfterEndLocation]
                )
            }
            if let img = ctx.makeImage() {
                let tex = SKTexture(cgImage: img)
                tex.filteringMode = .linear
                let vigNode = SKSpriteNode(texture: tex, size: vigSize)
                vigNode.position  = .zero
                vigNode.zPosition = GameConstants.ZPos.ui - 1
                vigNode.alpha     = 0.65
                cam.addChild(vigNode)
            }
        }
    }

    // MARK: - Treasure

    private func spawnTreasure(at position: CGPoint) {
        let drops: [ItemKind] = [.parkToken, .berry, .juiceBox]
        for (i, kind) in drops.enumerated() {
            let item = ItemNode(kind: kind)
            let angle = CGFloat(i) / CGFloat(drops.count) * 2 * .pi
            item.position = CGPoint(x: position.x + cos(angle)*28, y: position.y + sin(angle)*28)
            worldRoot.addChild(item)
            items.append(item)
        }
        DamageLabel.spawn(text: "✨ Chest opened!", color: .yellow,
                          at: CGPoint(x: position.x, y: position.y + 30), in: worldRoot)
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 1/60.0 : min(currentTime - lastUpdate, 0.05)
        lastUpdate = currentTime

        // Freeze world during dialogue, battle, or zone transition
        let frozen = isTransitioning
                  || (dialogue?.activeNPC != nil)
                  || (battleNode.phase != .none)
        guard !frozen else {
            player?.physicsBody?.velocity = .zero
            enemies.forEach { $0.physicsBody?.velocity = .zero }
            pressedKeys.removeAll()
            return
        }

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
            let idx = min((i+1) * trailSpacing, trail.count - 1)
            if idx >= 0 {
                let t = trail[idx]
                let dx = t.x - f.position.x; let dy = t.y - f.position.y
                f.position.x += dx * 0.28; f.position.y += dy * 0.28
                if abs(dx) > 0.5 { f.xScale = dx < 0 ? -1 : 1 }
                let moving = sqrt(dx*dx + dy*dy) > 1.5
                if moving {
                    let spec = i < followerSpecies.count ? followerSpecies[i] : .turtle
                    let frame: CharacterSprites.WalkFrame = Int(currentTime / 0.18) % 2 == 0 ? .a : .b
                    f.texture = CharacterSprites.texture(species: spec, frame: frame)
                }
            }
        }

        enemies.forEach { $0.tick(now: currentTime, playerPos: player.position) }

        // NPC proximity
        let nearNPC = npcs.first {
            let dx = $0.position.x - player.position.x
            let dy = $0.position.y - player.position.y
            return dx*dx + dy*dy < 70*70
        }
        if nearNPC !== nearbyNPC { nearbyNPC = nearNPC; showTalkButton(nearNPC != nil) }

        // Bench proximity (rest/save)
        let oldBench = nearbyBench
        nearbyBench = benchPositions.contains {
            let dx = $0.x - player.position.x
            let dy = $0.y - player.position.y
            return dx*dx + dy*dy < 55*55
        }
        if nearbyBench != oldBench {
#if canImport(AppKit)
            if nearbyBench {
                DamageLabel.spawn(text: "Press E to rest 💤",
                                  color: .cyan,
                                  at: CGPoint(x: player.position.x, y: player.position.y + 45),
                                  in: worldRoot)
            }
#endif
        }

        // Quack proximity (side-quest rescue)
        if let quack = quackNode, !quack.isRescued {
            let dx = quack.position.x - player.position.x
            let dy = quack.position.y - player.position.y
            let wasNearby = nearbyQuack
            nearbyQuack = dx*dx + dy*dy < 65*65
            if nearbyQuack && !wasNearby {
#if canImport(AppKit)
                DamageLabel.spawn(text: "Press E to rescue Quack! 🦆",
                                  color: SKColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1),
                                  at: CGPoint(x: player.position.x, y: player.position.y + 50),
                                  in: worldRoot)
#endif
            }
        } else {
            nearbyQuack = false
        }

        // Camera lerp — clamp to world bounds
        let worldW: CGFloat
        let worldH: CGFloat
        let zb = gameState?.currentZone.boundsSize ?? GameConstants.parkCenterWorldSize
        worldW = zb.width
        worldH = zb.height
        let hw = size.width/2, hh = size.height/2
        let tx = min(max(player.position.x, hw), worldW - hw)
        let ty = min(max(player.position.y, hh), worldH - hh)
        cam.position = CGPoint(
            x: cam.position.x + (tx - cam.position.x) * 0.10,
            y: cam.position.y + (ty - cam.position.y) * 0.10
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
            if second.categoryBitMask == GameConstants.Category.item,
               let item = second.node as? ItemNode { collectItem(item) }

            if second.categoryBitMask == GameConstants.Category.enemy,
               let enemy = second.node as? EnemyNode { triggerBattle(with: enemy) }

            if second.categoryBitMask == GameConstants.Category.item,
               let ch = second.node as? TreasureChestNode { ch.popOpen() }

            if second.categoryBitMask == GameConstants.Category.zoneExit,
               let exitNode = second.node as? ZoneExitNode {
                triggerZoneTransition(to: exitNode.destination)
            }

        case GameConstants.Category.pushable:
            if second.categoryBitMask == GameConstants.Category.pressurePlate,
               let plate = second.node as? PressurePlateNode { plate.activate() }

        default: break
        }
    }

    // MARK: - Contact handlers

    private func collectItem(_ item: ItemNode) {
        guard item.parent != nil else { return }
        gameState?.collect(item.kind)
        DamageLabel.collect("+\(item.kind.displayName)",
                            at: CGPoint(x: item.position.x, y: item.position.y + 24),
                            in: worldRoot)
        item.run(.sequence([
            .group([.scale(to: 1.5, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .removeFromParent()
        ]))
        items.removeAll { $0 === item }
    }
}
