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
    private var healButton:   ActionButton!
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
    private var isBossIntro:        Bool         = false  // freeze world during boss title card

    // Overworld attacks
    private var attacks:        [AttackNode]   = []
    private var chargeBarFill:  SKSpriteNode?
    private var chargeBarBg:    SKSpriteNode?

    // Follower trail
    private var trail:           [CGPoint] = []
    private let trailSpacing               = 26

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
        isBossIntro   = false
        attacks.removeAll()
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
        let tile = GameConstants.tileSize
        let storyProgress = gameState?.storyProgress ?? .introCheckFountain
        var fixedNPCs: [(NPCKind, CGPoint)] = [
            (.rangerGuide, CGPoint(x: tile * 52, y: tile * 8))
        ]
        if !(gameState?.hasHazelJoined ?? false) {
            fixedNPCs.append((.hazel, CGPoint(x: tile * 44, y: tile * 38)))
        }
        let openingEnemySpawns: [(EnemyKind, CGPoint)]
        switch storyProgress {
        case .acceptedLostAcorn:
            openingEnemySpawns = [(.pigeon, CGPoint(x: tile * 57, y: tile * 39))]
        case .introCheckFountain, .talkedToRanger, .foundLostAcorn:
            openingEnemySpawns = []
        case .hazelJoined:
            openingEnemySpawns = result.enemySpawns
        }
        finishWorldBuild(
            root: result.root,
            playerSpawn: result.playerSpawn,
            itemSpawns: result.itemSpawns,
            fixedItems: result.fixedItems,
            fixedNPCs: fixedNPCs,
            npcSpawns: result.npcSpawns,
            enemySpawns: openingEnemySpawns,
            benchPositions: result.benchPositions,
            zoneExitNodes: result.zoneExitNodes
        )
        updateParkCenterExits()
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
        let tile = GameConstants.tileSize
        // breadcrumbTrail is spawned directly by CitySouthWorld.build() — not in fixedItems here
        finishWorldBuild(
            root: result.root,
            playerSpawn: result.playerSpawn,
            itemSpawns: result.itemSpawns,
            fixedItems: [],
            fixedNPCs: [(.shopkeeper, CGPoint(x: tile * 22, y: tile * 8))],
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
        let tile = GameConstants.tileSize
        finishWorldBuild(
            root: result.root,
            playerSpawn: result.playerSpawn,
            itemSpawns: result.itemSpawns,
            fixedItems: result.fixedItems,
            fixedNPCs: [(.worker, CGPoint(x: tile * 36, y: tile * 22))],  // hard hat near center building
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
        fixedNPCs: [(NPCKind, CGPoint)] = [],
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

        // Fixed story items — skip ones whose clue is already found
        for (kind, pos) in fixedItems {
            if let clues = gameState?.quackClues {
                if kind == .quackFeather    && clues.contains(.foundFeather)   { continue }
                if kind == .breadcrumbTrail && clues.contains(.pigeonCityClue) { continue }
                if kind == .duckTag         && clues.contains(.raccoonDroppedTag) { continue }
            }
            let item = ItemNode(kind: kind)
            item.position = pos
            worldRoot.addChild(item)
            items.append(item)
        }

        let zone = gameState?.currentZone ?? .parkCenter
        if !(zone == .parkCenter && !(gameState?.hasHazelJoined ?? false)) {
            let spawnPool: [ItemKind]
            switch zone {
            case .parkNorth, .parkCenter: spawnPool = ItemKind.parkSpawnPool
            case .citySouth, .cityCenter: spawnPool = ItemKind.citySpawnPool
            case .cityNorth:              spawnPool = ItemKind.cityNorthSpawnPool
            }
            for (i, pos) in itemSpawns.enumerated() {
                let kind = spawnPool[i % spawnPool.count]
                let item = ItemNode(kind: kind)
                item.position = pos
                worldRoot.addChild(item)
                items.append(item)
            }
        }

        // Fixed NPCs (shopkeeper, quest NPCs) — placed at specific positions
        for (kind, pos) in fixedNPCs {
            let npc = NPCNode(kind: kind)
            npc.position = pos
            worldRoot.addChild(npc)
            npcs.append(npc)
        }

        // Random NPC rotation — fixed-placement NPCs excluded from pool
        if !(zone == .parkCenter && !(gameState?.hasHazelJoined ?? false)) {
            let npcKinds = NPCKind.allCases.filter { !$0.isFixed }
            for (i, pos) in npcSpawns.enumerated() {
                let npc = NPCNode(kind: npcKinds[i % npcKinds.count])
                npc.position = pos
                worldRoot.addChild(npc)
                npcs.append(npc)
            }
        }

        for (kind, pos) in enemySpawns {
            // Bosses that were already beaten don't reappear
            if kind.isBoss && (gameState?.defeatedBosses.contains(kind) ?? false) { continue }
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
        rebuildFollowers()
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

        healButton = ActionButton(glyph: "🍎", radius: 26, tint: .green)
        healButton.onTap = { [weak self] in self?.useQuickItem() }
        cam.addChild(healButton)

        // Battle overlay (always on camera, initially hidden)
        battleNode = BattleNode()
        battleNode.onVictory = { [weak self] kind in self?.handleBattleVictory(kind: kind) }
        battleNode.onDefeat  = { [weak self] in self?.handleBattleDefeat() }
        battleNode.onFled    = { [weak self] in self?.handleBattleFled() }
        cam.addChild(battleNode)

        addVignette()
        buildChargeBar()

#if canImport(AppKit)
        joystick.isHidden     = true
        talkButton.isHidden   = true
        switchButton.isHidden = true
        healButton.isHidden   = true

        let hint = SKLabelNode(
            text: "WASD · Space Attack · E Talk/Rest · H Heal · Tab Switch · I Stats · Esc Pause")
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
        hintLabel?.position           = CGPoint(x: 0,       y: -h/2 + 8)
        chargeBarBg?.parent?.position = CGPoint(x: w/2 - 90, y: -h/2 + 36)
#else
        joystick.position     = CGPoint(x: -w/2 + 100, y: -h/2 + 100)
        talkButton.position   = CGPoint(x:  w/2 - 65,  y: -h/2 + 148)
        switchButton.position = CGPoint(x:  w/2 - 38,  y:  h/2 - 50)
        healButton.position   = CGPoint(x:  w/2 - 90,  y:  h/2 - 50)
        chargeBarBg?.parent?.position = CGPoint(x: 0, y: -h/2 + 170)
#endif
    }

    /// Build the overworld attack charge indicator (stays on camera).
    private func buildChargeBar() {
        let barW: CGFloat = 100
        let barH: CGFloat = 7
        let container = SKNode()
        container.zPosition = GameConstants.ZPos.ui
        cam.addChild(container)

        // Glph label
        let glyphLabel = SKLabelNode(text: "⚡")
        glyphLabel.fontSize = 12
        glyphLabel.horizontalAlignmentMode = .right
        glyphLabel.verticalAlignmentMode   = .center
        glyphLabel.position = CGPoint(x: -barW / 2 - 5, y: 0)
        container.addChild(glyphLabel)

        // Background track
        let bg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.45),
                              size: CGSize(width: barW, height: barH))
        bg.anchorPoint = CGPoint(x: 0, y: 0.5)
        bg.position    = CGPoint(x: -barW / 2, y: 0)
        bg.name        = "chargeBarBg"
        container.addChild(bg)
        chargeBarBg = bg

        // Fill
        let fill = SKSpriteNode(color: .green, size: CGSize(width: 0, height: barH - 2))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position    = CGPoint(x: 1, y: 0)
        container.addChild(fill)
        chargeBarFill = fill

        // Border
        let border = SKShapeNode(rect: CGRect(x: -barW/2, y: -barH/2, width: barW, height: barH),
                                 cornerRadius: 2)
        border.fillColor   = .clear
        border.strokeColor = SKColor(white: 1, alpha: 0.22)
        border.lineWidth   = 1
        container.addChild(border)
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
        case 14: handleInteract()                          // E
        case 48: cycleParty()                              // Tab
        case 49: fireOverworldAttack()                     // Space
        case 34: gameState?.statsOpen.toggle()             // I — stats screen
        case  4: useQuickItem()                            // H — quick-use best consumable
        case 53:                                           // Esc — close overlay or pause
            if let state = gameState {
                if state.statsOpen      { state.statsOpen = false }
                else if state.shopOpen  { state.shopOpen  = false }
                else                    { state.isPaused.toggle() }
            }
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
        guard let state = gameState else { return }

        // Shopkeeper → open the store instead of dialogue
        if npc.kind.isShopkeeper {
            state.shopOpen = true
            return
        }

        guard let dialogue else { return }

        switch npc.kind {
        case .rangerGuide:
            let lines: [(String, String)]
            let onDismiss: (() -> Void)?
            switch state.storyProgress {
            case .introCheckFountain:
                lines = [
                    ("Ranger", "Morning. Official park notice: if you see a goose wearing clothing, do not make eye contact."),
                    ("Shelly", "That feels specific."),
                    ("Ranger", "It became specific yesterday."),
                    ("Ranger", "Hazel is by the fountain making this everyone's problem. Start there.")
                ]
                onDismiss = { [weak self] in
                    guard let self, let state = self.gameState else { return }
                    state.advanceStory(to: .talkedToRanger)
                    self.showStoryToast("Objective updated: Check the fountain.")
                }
            default:
                lines = [
                    ("Ranger", "I filed a normal-morning report and the geese made it fiction."),
                    ("Shelly", "That sounds unhelpful."),
                    ("Ranger", "It is still the most official thing I have.")
                ]
                onDismiss = nil
            }
            dialogue.presentScriptedConversation(title: "Prologue", lines: lines, onDismiss: onDismiss)
            return

        case .hazel:
            let lines: [(String, String)]
            let onDismiss: (() -> Void)?
            switch state.storyProgress {
            case .introCheckFountain:
                lines = [
                    ("Hazel", "You are early. Go get the ranger version first."),
                    ("Shelly", "There is a ranger version?"),
                    ("Hazel", "There is always a ranger version. Then there is the useful version.")
                ]
                onDismiss = nil
            case .talkedToRanger:
                lines = [
                    ("Hazel", "You. Shell person. Emergency."),
                    ("Shelly", "My name is Shelly."),
                    ("Hazel", "Great. Shelly Emergency."),
                    ("Hazel", "The pigeons stole my reserve acorn and posted up by the trash cans like they pay rent."),
                    ("Hazel", "Get Steven back and I will stop yelling long enough to join you.")
                ]
                onDismiss = { [weak self] in
                    guard let self, let state = self.gameState else { return }
                    state.advanceStory(to: .acceptedLostAcorn)
                    self.rebuildParkCenterOpeningIfNeeded()
                    self.showStoryToast("Quest started: The Lost Acorn.")
                }
            case .acceptedLostAcorn:
                lines = [
                    ("Hazel", "Trash cans. Angry pigeon. Steven."),
                    ("Shelly", "That is a very compact briefing."),
                    ("Hazel", "It is an urgent squirrel briefing.")
                ]
                onDismiss = nil
            case .foundLostAcorn:
                lines = [
                    ("Hazel", "That is my acorn."),
                    ("Shelly", "You can tell?"),
                    ("Hazel", "I named it Steven."),
                    ("Hazel", "All right. I am in. The pond is wrong and I would like witnesses.")
                ]
                onDismiss = { [weak self] in
                    guard let self, let state = self.gameState else { return }
                    self.consumeStoryItem(.lostAcorn)
                    state.unlockPartyMember(.squirrel)
                    state.advanceStory(to: .hazelJoined)
                    self.refreshPartySprites()
                    self.rebuildParkCenterOpeningIfNeeded()
                    self.updateParkCenterExits()
                    self.showStoryToast("Hazel joined! North path unlocked.")
                }
            case .hazelJoined:
                lines = [
                    ("Hazel", "Pond first. Then geese. Then whatever is teaching pigeons logistics."),
                    ("Shelly", "That order feels optimistic."),
                    ("Hazel", "It is still the order.")
                ]
                onDismiss = nil
            }
            dialogue.presentScriptedConversation(title: "The Lost Acorn", lines: lines, onDismiss: onDismiss)
            return

        default:
            break
        }

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
        case .worker:
            state.quackClues.insert(.workerSawDuck)
            state.save()
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

        run(.wait(forDuration: 1.5)) { [weak self] in self?.drainPendingLevelUps() }
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
        rebuildFollowers()
    }

    // MARK: - Battle trigger

    private func triggerBattle(with enemy: EnemyNode) {
        guard battleNode.phase == .none,
              !enemy.isDead,
              !isBossIntro,
              let state = gameState else { return }
        let now = CACurrentMediaTime()
        guard now - lastBattleEndTime > battleReengageCooldown else { return }

        player.physicsBody?.velocity = .zero
        pressedKeys.removeAll()
        enemies.forEach { $0.physicsBody?.velocity = .zero }

        // Auto-win: if average living party level > enemy level + 3, skip the battle UI
        let enemyLevel = max(1, enemy.kind.maxHP / 8)
        let livingMembers = state.party.filter(\.isAlive)
        let avgLevel = livingMembers.isEmpty ? 1 :
            livingMembers.map(\.level).reduce(0, +) / livingMembers.count
        if !enemy.kind.isBoss && avgLevel > enemyLevel + 3 {
            autoWin(enemy: enemy, state: state)
            return
        }

        // Bosses get a dramatic intro screen first
        if enemy.kind.isBoss {
            showBossIntro(for: enemy) { [weak self] in
                guard let self else { return }
                self.isBossIntro = false
                self.battleNode.show(enemy: enemy, state: state)
            }
        } else {
            battleNode.show(enemy: enemy, state: state)
        }
    }

    // MARK: - Boss intro title card

    private func showBossIntro(for enemy: EnemyNode, then startBattle: @escaping () -> Void) {
        isBossIntro = true
        let kind = enemy.kind

        // Stripe color per boss
        let stripeColor: SKColor
        switch kind {
        case .grandGooseGerald: stripeColor = SKColor(red: 0.10, green: 0.28, blue: 0.10, alpha: 1)
        case .officerGrumble:   stripeColor = SKColor(red: 0.08, green: 0.16, blue: 0.42, alpha: 1)
        case .foremanRex:       stripeColor = SKColor(red: 0.48, green: 0.22, blue: 0.04, alpha: 1)
        default:                stripeColor = SKColor(red: 0.35, green: 0.05, blue: 0.05, alpha: 1)
        }

        // Full-screen dark overlay
        let overlay = SKSpriteNode(color: .black,
                                   size: CGSize(width: max(size.width, 900),
                                                height: max(size.height, 900)))
        overlay.position  = .zero
        overlay.zPosition = GameConstants.ZPos.ui + 50
        overlay.alpha     = 0
        cam.addChild(overlay)

        // Colored banner stripe across middle
        let stripe = SKSpriteNode(color: stripeColor,
                                  size: CGSize(width: overlay.size.width, height: 200))
        stripe.position  = CGPoint(x: 0, y: 10)
        stripe.zPosition = 0.1
        stripe.alpha     = 0
        overlay.addChild(stripe)

        // ★ BOSS ★ badge (gold, pulsing)
        let bossTag = SKLabelNode(text: "★  B O S S  ★")
        bossTag.fontName                = "Helvetica Neue"
        bossTag.fontSize                = 13
        bossTag.fontColor               = SKColor(red: 1, green: 0.82, blue: 0.18, alpha: 1)
        bossTag.horizontalAlignmentMode = .center
        bossTag.verticalAlignmentMode   = .center
        bossTag.position                = CGPoint(x: 0, y: 72)
        bossTag.zPosition               = 0.5
        bossTag.alpha                   = 0
        overlay.addChild(bossTag)

        // Boss emoji (large, left-of-center)
        let emojiLabel = SKLabelNode(text: kind.bossEmoji)
        emojiLabel.fontSize               = 80
        emojiLabel.horizontalAlignmentMode = .center
        emojiLabel.verticalAlignmentMode   = .center
        emojiLabel.position               = CGPoint(x: -160, y: 10)
        emojiLabel.zPosition              = 0.5
        emojiLabel.alpha                  = 0
        overlay.addChild(emojiLabel)

        // Boss display name (big, white)
        let nameLabel = SKLabelNode(text: kind.displayName.uppercased())
        nameLabel.fontName                = "Helvetica Neue Bold"
        nameLabel.fontSize                = 34
        nameLabel.fontColor               = .white
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode   = .center
        nameLabel.position                = CGPoint(x: 40, y: 20)
        nameLabel.zPosition               = 0.5
        nameLabel.alpha                   = 0
        overlay.addChild(nameLabel)

        // Subtitle (italic-style)
        let titleLabel = SKLabelNode(text: kind.bossIntroTitle)
        titleLabel.fontName                = "Helvetica Neue"
        titleLabel.fontSize                = 17
        titleLabel.fontColor               = SKColor(white: 0.76, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode   = .center
        titleLabel.position                = CGPoint(x: 40, y: -18)
        titleLabel.zPosition               = 0.5
        titleLabel.alpha                   = 0
        overlay.addChild(titleLabel)

        // Flavor text (below stripe)
        let flavorLabel = SKLabelNode(text: kind.bossIntroFlavor)
        flavorLabel.fontName                = "Helvetica Neue"
        flavorLabel.fontSize                = 13
        flavorLabel.fontColor               = SKColor(white: 0.55, alpha: 1)
        flavorLabel.horizontalAlignmentMode = .center
        flavorLabel.verticalAlignmentMode   = .center
        flavorLabel.position                = CGPoint(x: 0, y: -115)
        flavorLabel.zPosition               = 0.5
        flavorLabel.alpha                   = 0
        overlay.addChild(flavorLabel)

        // Camera shake on stripe reveal
        let shake = SKAction.sequence([
            .moveBy(x: -7, y: 0, duration: 0.04),
            .moveBy(x: 14, y: 0, duration: 0.04),
            .moveBy(x: -7, y: 0, duration: 0.04),
        ])

        overlay.run(.sequence([
            .fadeAlpha(to: 0.90, duration: 0.35),
            .run { [weak self] in
                self?.cam.run(shake)
                stripe.run(.fadeAlpha(to: 1, duration: 0.12))
                emojiLabel.run(.sequence([
                    .scale(to: 1.5, duration: 0),
                    .group([.scale(to: 1.0, duration: 0.30), .fadeIn(withDuration: 0.25)])
                ]))
                nameLabel.run(.sequence([
                    .wait(forDuration: 0.08),
                    .group([
                        .fadeIn(withDuration: 0.22),
                        .sequence([.moveBy(x: 0, y: -10, duration: 0),
                                   .moveBy(x: 0, y:  10, duration: 0.22)])
                    ])
                ]))
                bossTag.run(.sequence([
                    .wait(forDuration: 0.05),
                    .fadeIn(withDuration: 0.18),
                    .repeatForever(.sequence([
                        .fadeAlpha(to: 0.35, duration: 0.55),
                        .fadeAlpha(to: 1.00, duration: 0.55)
                    ]))
                ]))
                titleLabel.run(.sequence([.wait(forDuration: 0.20), .fadeIn(withDuration: 0.20)]))
                flavorLabel.run(.sequence([.wait(forDuration: 0.40), .fadeIn(withDuration: 0.30)]))
            },
            .wait(forDuration: 2.8),
            .fadeOut(withDuration: 0.40),
            .removeFromParent(),
            .run(startBattle)
        ]))
    }

    /// Instant-win for trivially weak enemies — flash, award exp/coins, remove enemy.
    private func autoWin(enemy: EnemyNode, state: GameState) {
        lastBattleEndTime = CACurrentMediaTime()

        _ = enemy.takeDamage(enemy.hp + 1)   // drain all HP → isDead becomes true
        let pos = enemy.position

        // Quick flash + pop
        enemy.run(.sequence([
            .group([
                .scale(to: 1.4, duration: 0.08),
                .colorize(with: .yellow, colorBlendFactor: 0.8, duration: 0.08)
            ]),
            .group([
                .scale(to: 0, duration: 0.12),
                .fadeOut(withDuration: 0.12)
            ]),
            .removeFromParent()
        ]))
        enemies.removeAll { $0 === enemy }

        state.defeatEnemy(kind: enemy.kind)
        drainPendingLevelUps()
        DamageLabel.spawn(text: "💨 Too easy!",
                          color: SKColor(red: 0.9, green: 0.75, blue: 0.2, alpha: 1),
                          at: CGPoint(x: pos.x, y: pos.y + 30),
                          in: worldRoot)
        DamageLabel.score(enemy.kind.defeatScore,
                          at: CGPoint(x: pos.x, y: pos.y + 55),
                          in: worldRoot)

        // Respawn after delay
        let kind = enemy.kind
        run(.wait(forDuration: 20)) { [weak self] in
            guard let self else { return }
            let spawnPos = CGPoint(x: pos.x + CGFloat.random(in: -80...80),
                                   y: pos.y + CGFloat.random(in: -80...80))
            let newEnemy = EnemyNode(kind: kind)
            newEnemy.position     = spawnPos
            newEnemy.patrolOrigin = spawnPos
            self.worldRoot.addChild(newEnemy)
            self.enemies.append(newEnemy)
        }
    }

    // MARK: - Battle callbacks

    private func handleBattleVictory(kind: EnemyKind) {
        lastBattleEndTime = CACurrentMediaTime()
        if let idx = enemies.firstIndex(where: { $0.kind == kind && $0.isDead }) {
            let enemy = enemies[idx]
            enemies.remove(at: idx)
            let deathPos = enemy.position
            enemy.playDeathAndRemove {}

            DamageLabel.score(kind.defeatScore,
                              at: CGPoint(x: deathPos.x, y: deathPos.y + 44),
                              in: worldRoot)

            // Bosses: record permanently, no respawn, show victory burst
            if kind.isBoss {
                gameState?.defeatBoss(kind)
                showBossVictoryBurst(at: deathPos, kind: kind)
                drainPendingLevelUps()
                return
            }

            if kind == .pigeon,
               let state = gameState,
               state.currentZone == .parkCenter,
               state.storyProgress == .acceptedLostAcorn {
                state.collect(.lostAcorn)
                drainPendingLevelUps()
                rebuildParkCenterOpeningIfNeeded()
                showStoryToast("Found Hazel's Lost Acorn.")
                return
            }

            drainPendingLevelUps()

            // Regular enemies respawn after a delay
            let spawnPos = CGPoint(
                x: deathPos.x + CGFloat.random(in: -80...80),
                y: deathPos.y + CGFloat.random(in: -80...80)
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

    /// Firework-style confetti burst when a boss is defeated.
    private func showBossVictoryBurst(at pos: CGPoint, kind: EnemyKind) {
        let emojis = ["🎉", "🎊", "⭐️", "✨", "🏆"]
        for i in 0..<16 {
            let label = SKLabelNode(text: emojis[i % emojis.count])
            label.fontSize  = CGFloat.random(in: 22...42)
            label.position  = CGPoint(x: pos.x + CGFloat.random(in: -60...60),
                                      y: pos.y + CGFloat.random(in: -30...30))
            label.zPosition = GameConstants.ZPos.entity + 5
            label.alpha     = 0
            worldRoot.addChild(label)
            label.run(.sequence([
                .wait(forDuration: Double(i) * 0.06),
                .group([
                    .fadeIn(withDuration: 0.15),
                    .moveBy(x: CGFloat.random(in: -100...100),
                            y: CGFloat.random(in: 60...180), duration: 1.4)
                ]),
                .fadeOut(withDuration: 0.3),
                .removeFromParent()
            ]))
        }

        // Big centered toast
        let toast = SKLabelNode(text: "🏆 \(kind.displayName) defeated!")
        toast.fontName                = "Helvetica Neue Bold"
        toast.fontSize                = 22
        toast.fontColor               = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        toast.horizontalAlignmentMode = .center
        toast.position                = CGPoint(x: 0, y: 80)
        toast.zPosition               = GameConstants.ZPos.ui + 10
        toast.alpha                   = 0
        cam.addChild(toast)
        toast.run(.sequence([
            .group([.fadeIn(withDuration: 0.25), .scale(to: 1.1, duration: 0.25)]),
            .wait(forDuration: 2.0),
            .group([.fadeOut(withDuration: 0.4), .scale(to: 0.9, duration: 0.4)]),
            .removeFromParent()
        ]))
    }

    /// Show floating level-up toasts for any pending level-ups.
    private func drainPendingLevelUps() {
        guard let state = gameState, !state.pendingLevelUps.isEmpty else { return }
        let ups = state.pendingLevelUps
        state.pendingLevelUps.removeAll()
        for (i, lu) in ups.enumerated() {
            run(.wait(forDuration: Double(i) * 1.1 + 0.6)) { [weak self] in
                guard let self, let p = self.player else { return }
                DamageLabel.spawn(
                    text: "⬆️ \(lu.name) → Lv.\(lu.level)!  \(lu.summary)",
                    color: SKColor(red: 0.55, green: 1.0, blue: 0.45, alpha: 1),
                    at: CGPoint(x: p.position.x,
                                y: p.position.y + 65 + CGFloat(i) * 26),
                    in: self.worldRoot)
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

    // MARK: - Overworld Attack

    private func fireOverworldAttack() {
        guard let state = gameState,
              !isTransitioning, !isBossIntro,
              battleNode.phase == .none,
              !state.shopOpen,
              dialogue?.activeNPC == nil else { return }

        let now = CACurrentMediaTime()
        guard state.attackCharge(now: now) >= 1.0 else { return }  // must be fully charged

        state.recordAttack(now: now)
        player.playAttackPunch()

        let atk = AttackNode(species: state.activeSpecies,
                             at: player.position,
                             facing: player.facing)
        worldRoot.addChild(atk)
        attacks.append(atk)
    }

    private func useQuickItem() {
        guard let state = gameState,
              !isTransitioning, !isBossIntro,
              battleNode.phase == .none,
              !state.shopOpen, !state.statsOpen, !state.isPaused,
              dialogue?.activeNPC == nil else { return }

        // Prefer antidote if anyone is poisoned
        let anyPoisoned = state.party.contains { $0.isAlive && ($0.isPoisoned || $0.isBadlyPoisoned) }
        let hasAntidote = (state.inventory[.antidote] ?? 0) > 0

        // Pick item: antidote first if needed, then highest HP heal, then PP restorer
        let best: ItemKind?
        if anyPoisoned && hasAntidote {
            best = .antidote
        } else {
            best = ItemKind.allCases
                .filter { state.inventory[$0, default: 0] > 0 && $0.isUsable && !$0.curesPoison }
                .max { $0.healHP + $0.healPP * 2 < $1.healHP + $1.healPP * 2 }
        }

        guard let item = best else {
            DamageLabel.spawn(text: "No items! 🎒",
                              color: SKColor(white: 0.65, alpha: 1),
                              at: CGPoint(x: player.position.x, y: player.position.y + 44),
                              in: worldRoot)
            return
        }

        if let result = state.useConsumable(item) {
            let text: String
            if item.curesPoison {
                text = "\(item.emoji) Poison cured! (\(result.name))"
            } else if item == .mysteryBag {
                var parts: [String] = []
                if result.hp > 0 { parts.append("+\(result.hp) HP") }
                if result.pp > 0 { parts.append("+\(result.pp) PP") }
                text = "🛍️ Mystery! \(parts.joined(separator: "  "))  (\(result.name))"
            } else {
                var parts: [String] = []
                if result.hp > 0 { parts.append("+\(result.hp) HP") }
                if result.pp > 0 { parts.append("+\(result.pp) PP") }
                text = "\(item.emoji) \(parts.joined(separator: "  "))  (\(result.name))"
            }
            DamageLabel.spawn(
                text: text,
                color: SKColor(red: 0.35, green: 1.0, blue: 0.55, alpha: 1),
                at: CGPoint(x: player.position.x, y: player.position.y + 50),
                in: worldRoot)
        } else {
            DamageLabel.spawn(text: "Party is already full! 💚",
                              color: SKColor(white: 0.65, alpha: 1),
                              at: CGPoint(x: player.position.x, y: player.position.y + 44),
                              in: worldRoot)
        }
    }

    private func handleAttackHit(attack: AttackNode, enemy: EnemyNode) {
        guard !enemy.isDead,
              !attack.hitEnemies.contains(ObjectIdentifier(enemy)) else { return }
        attack.hitEnemies.insert(ObjectIdentifier(enemy))

        let dead = enemy.takeDamage(attack.damage)

        DamageLabel.spawn(
            text: "-\(attack.damage)",
            color: SKColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1),
            at: CGPoint(x: enemy.position.x, y: enemy.position.y + 28),
            in: worldRoot)

        if dead, let state = gameState {
            autoWin(enemy: enemy, state: state)
        }
        // Alive enemies will chase the player and trigger a battle on contact
        // (they'll start with reduced HP — the pre-battle damage advantage)
    }

    // MARK: - Zone transition

    private func triggerZoneTransition(to destination: GameZone) {
        guard !isTransitioning, let state = gameState else { return }

        switch destination {
        case .parkNorth where !state.hasHazelJoined:
            showStoryToast("Hazel should see the pond with you.")
            return
        case .citySouth where !state.defeatedBosses.contains(.grandGooseGerald):
            showStoryToast("The city can wait. Check the pond first.")
            return
        case .cityNorth where !state.defeatedBosses.contains(.officerGrumble):
            showStoryToast("The subway gate stays locked until Officer Grumble moves.")
            return
        default:
            break
        }

        isTransitioning = true
        state.currentZone = destination
        state.save()   // auto-save when crossing zone borders

        // Black overlay on camera
        let overlay = SKSpriteNode(color: .black,
                                   size: CGSize(width: max(size.width, 900),
                                                height: max(size.height, 900)))
        overlay.position  = .zero
        overlay.zPosition = GameConstants.ZPos.ui + 100
        overlay.alpha     = 0
        cam.addChild(overlay)
        fadeOverlay = overlay

        // Zone title card (shown while screen is black)
        let titleLabel = SKLabelNode(text: destination.displayTitle)
        titleLabel.fontName                = "Helvetica Neue Bold"
        titleLabel.fontSize                = 24
        titleLabel.fontColor               = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode   = .center
        titleLabel.position                = CGPoint(x: 0, y: 14)
        titleLabel.zPosition               = 1
        titleLabel.alpha                   = 0
        overlay.addChild(titleLabel)

        let subLabel = SKLabelNode(text: destination.zoneSubtitle)
        subLabel.fontName                = "Helvetica Neue"
        subLabel.fontSize                = 13
        subLabel.fontColor               = SKColor(white: 0.60, alpha: 1)
        subLabel.horizontalAlignmentMode = .center
        subLabel.verticalAlignmentMode   = .center
        subLabel.position                = CGPoint(x: 0, y: -8)
        subLabel.zPosition               = 1
        subLabel.alpha                   = 0
        overlay.addChild(subLabel)

        overlay.run(.sequence([
            .fadeIn(withDuration: 0.35),
            // Reveal zone name while screen is black
            .run {
                titleLabel.run(.fadeIn(withDuration: 0.22))
                subLabel.run(.sequence([.wait(forDuration: 0.10), .fadeIn(withDuration: 0.22)]))
            },
            .wait(forDuration: 0.75),   // display zone title ~0.75s
            // Rebuild world behind the black
            .run { [weak self] in
                guard let self else { return }
                self.tearDownWorld()
                self.buildWorld()
                self.buildPlayerAndFollowers()
                self.cam.position = self.pendingSpawn
                self.showZoneArrivalBeat()
            },
            .wait(forDuration: 0.08),
            .fadeOut(withDuration: 0.40),
            .removeFromParent(),
            .run { [weak self] in self?.isTransitioning = false }
        ]))
    }

    private func showZoneArrivalBeat() {
        guard let state = gameState else { return }

        let title = SKLabelNode(text: state.currentZone.displayTitle.uppercased())
        title.fontName = "Helvetica Neue Bold"
        title.fontSize = 16
        title.fontColor = SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1)
        title.position = CGPoint(x: 0, y: size.height / 2 - 92)
        title.horizontalAlignmentMode = .center
        title.zPosition = GameConstants.ZPos.ui + 25
        title.alpha = 0
        cam.addChild(title)

        let beat = SKLabelNode(text: state.zoneArrivalText)
        beat.fontName = "Helvetica Neue"
        beat.fontSize = 12
        beat.fontColor = .white
        beat.position = CGPoint(x: 0, y: size.height / 2 - 118)
        beat.horizontalAlignmentMode = .center
        beat.zPosition = GameConstants.ZPos.ui + 25
        beat.alpha = 0
        cam.addChild(beat)

        let show = SKAction.group([.fadeIn(withDuration: 0.2), .moveBy(x: 0, y: -6, duration: 0.2)])
        let hide = SKAction.group([.fadeOut(withDuration: 0.28), .moveBy(x: 0, y: -4, duration: 0.28)])
        title.run(.sequence([show, .wait(forDuration: 2.8), hide, .removeFromParent()]))
        beat.run(.sequence([show, .wait(forDuration: 2.8), hide, .removeFromParent()]))
    }

    // MARK: - Visual polish

    private func addVignette() {
        // Subtle dark vignette on camera edges — size must be large enough to cover any
        // Mac display so the rectangular edge is never visible on screen.
        let vigSize = CGSize(width: 4000, height: 4000)

        // Build a radial gradient texture via CGContext (rendered at half res for speed)
        let pw = 512, ph = 512
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8,
                               bytesPerRow: pw * 4,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                                           CGImageAlphaInfo.premultipliedFirst.rawValue) else { return }

        let cx = CGFloat(pw) / 2, cy = CGFloat(ph) / 2
        let r  = min(cx, cy) * 0.95
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(red: 0, green: 0, blue: 0, alpha: 0),
                CGColor(red: 0, green: 0, blue: 0, alpha: 0.52)
            ] as CFArray,
            locations: [0.35, 1]
        )
        if let gradient {
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                endCenter:   CGPoint(x: cx, y: cy), endRadius:   r,
                options: [.drawsAfterEndLocation]
            )
        }
        guard let img = ctx.makeImage() else { return }
        let tex = SKTexture(cgImage: img)
        tex.filteringMode = .linear
        let vigNode = SKSpriteNode(texture: tex, size: vigSize)
        vigNode.position  = .zero
        vigNode.zPosition = GameConstants.ZPos.ui - 1
        vigNode.alpha     = 0.55
        cam.addChild(vigNode)
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

        // Freeze world during dialogue, battle, zone transition, boss intro, or overlays
        let frozen = isTransitioning
                  || isBossIntro
                  || (dialogue?.activeNPC != nil)
                  || (battleNode.phase != .none)
                  || (gameState?.statsOpen ?? false)
                  || (gameState?.shopOpen ?? false)
                  || (gameState?.isPaused ?? false)
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
        let playerIsMoving = sqrt(dir.dx * dir.dx + dir.dy * dir.dy) > 0.05
        for (i, f) in followers.enumerated() {
            let target: CGPoint
            if playerIsMoving {
                let idx = min((i + 1) * trailSpacing, trail.count - 1)
                target = trail[max(0, idx)]
            } else {
                let offset = idleFollowerOffset(index: i, facing: player.facing)
                target = CGPoint(x: player.position.x + offset.x, y: player.position.y + offset.y)
            }

            let dx = target.x - f.position.x
            let dy = target.y - f.position.y
            f.position.x += dx * (playerIsMoving ? 0.28 : 0.18)
            f.position.y += dy * (playerIsMoving ? 0.28 : 0.18)
            if abs(dx) > 0.5 { f.xScale = dx < 0 ? -1 : 1 }

            let spec = i < followerSpecies.count ? followerSpecies[i] : .turtle
            let moving = sqrt(dx*dx + dy*dy) > (playerIsMoving ? 1.5 : 8.0)
            if moving && playerIsMoving {
                let frame: CharacterSprites.WalkFrame = Int(currentTime / 0.18) % 2 == 0 ? .a : .b
                f.texture = CharacterSprites.texture(species: spec, frame: frame)
            } else {
                f.texture = CharacterSprites.texture(species: spec, frame: .a)
            }
        }

        enemies.forEach { $0.tick(now: currentTime, playerPos: player.position) }

        // Overworld attack charge bar
        if let fill = chargeBarFill, let state = gameState {
            let charge = CGFloat(state.attackCharge(now: currentTime))
            let barW: CGFloat = 100
            fill.size.width = max(0, (barW - 2) * min(charge, 1.0))
            fill.color = charge >= 1.0
                ? SKColor(red: 0.2, green: 1.0, blue: 0.3, alpha: 1)   // ready: bright green
                : SKColor(red: 0.8, green: 0.55 + 0.45 * charge, blue: 0.1, alpha: 1)  // charging: orange→yellow
        }

        // Heal button glyph: show best available item, or 🚫 when empty
        if let state = gameState {
            let best = ItemKind.allCases
                .filter { state.inventory[$0, default: 0] > 0 && $0.isUsable }
                .max { $0.healHP < $1.healHP }
            healButton?.setGlyph(best?.emoji ?? "🚫")
        }

        // Projectile range culling
        attacks = attacks.filter { $0.parent != nil }
        attacks.forEach { $0.checkRange() }

        // NPC proximity
        let nearNPC = npcs.first {
            let dx = $0.position.x - player.position.x
            let dy = $0.position.y - player.position.y
            return dx*dx + dy*dy < 70*70
        }
        if nearNPC !== nearbyNPC {
            nearbyNPC = nearNPC
            showTalkButton(nearNPC != nil)
#if canImport(AppKit)
            if nearNPC != nil {
                DamageLabel.spawn(text: "Press E to talk",
                                  color: SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1),
                                  at: CGPoint(x: player.position.x, y: player.position.y + 48),
                                  in: worldRoot)
            }
#endif
        }

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

        case GameConstants.Category.attack:
            if second.categoryBitMask == GameConstants.Category.enemy,
               let atk = first.node as? AttackNode,
               let enemy = second.node as? EnemyNode {
                handleAttackHit(attack: atk, enemy: enemy)
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

    private func rebuildFollowers() {
        followers.forEach { $0.removeFromParent() }
        followers.removeAll()

        guard let state = gameState, player != nil else { return }
        followerSpecies = state.party.map(\.species).filter { $0 != state.activeSpecies }
        for (index, spec) in followerSpecies.enumerated() {
            let follower = SKSpriteNode(texture: CharacterSprites.texture(species: spec, frame: .a))
            follower.size = CGSize(width: 48, height: 48)
            follower.zPosition = GameConstants.ZPos.entity - 0.1
            follower.alpha = 0.88
            let offset = idleFollowerOffset(index: index, facing: player.facing)
            follower.position = CGPoint(x: player.position.x + offset.x, y: player.position.y + offset.y)
            worldRoot.addChild(follower)
            followers.append(follower)
        }
    }

    private func updateParkCenterExits() {
        guard gameState?.currentZone == .parkCenter else { return }
        for exit in zoneExitNodes where exit.destination == .parkNorth {
            if gameState?.hasHazelJoined == true {
                if exit.parent == nil { worldRoot.addChild(exit) }
            } else {
                exit.removeFromParent()
            }
        }
    }

    private func rebuildParkCenterOpeningIfNeeded() {
        guard gameState?.currentZone == .parkCenter else { return }
        let playerPosition = player?.position ?? pendingSpawn
        tearDownWorld()
        buildWorld()
        pendingSpawn = playerPosition
        buildPlayerAndFollowers()
        cam.position = playerPosition
        layoutControls()
    }

    private func consumeStoryItem(_ kind: ItemKind) {
        guard let state = gameState, let amount = state.inventory[kind], amount > 0 else { return }
        let remaining = amount - 1
        if remaining > 0 {
            state.inventory[kind] = remaining
        } else {
            state.inventory.removeValue(forKey: kind)
        }
        state.save()
    }

    private func showStoryToast(_ text: String) {
        guard let player else { return }
        DamageLabel.spawn(text: text,
                          color: SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1),
                          at: CGPoint(x: player.position.x, y: player.position.y + 62),
                          in: worldRoot)
    }

    private func idleFollowerOffset(index: Int, facing: CGVector) -> CGPoint {
        let leftRightBias: CGFloat
        let backBias: CGFloat

        if abs(facing.dx) > abs(facing.dy) {
            leftRightBias = facing.dx > 0 ? -1 : 1
            backBias = 1
        } else {
            leftRightBias = facing.dy > 0 ? 1 : -1
            backBias = facing.dy > 0 ? -1 : 1
        }

        switch index {
        case 0:
            return CGPoint(x: 18 * leftRightBias, y: 12 * backBias)
        case 1:
            return CGPoint(x: -18 * leftRightBias, y: 12 * backBias)
        case 2:
            return CGPoint(x: 0, y: 28 * backBias)
        default:
            return CGPoint(x: 0, y: CGFloat(28 + (index - 2) * 10) * backBias)
        }
    }
}
