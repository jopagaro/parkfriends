import SpriteKit

/// Zone 1B (center) + Zone 1A (north) — Part 1 world structure.
enum ParkWorld {

    struct BuildResult {
        let root: SKNode
        let npcSpawns: [CGPoint]
        let itemSpawns: [CGPoint]
        let fixedItems: [(ItemKind, CGPoint)]  // deterministic story items
        let enemySpawns: [(EnemyKind, CGPoint)]
        let playerSpawn: CGPoint
        let benchPositions: [CGPoint]
        let zoneExitNodes: [ZoneExitNode]
        let pressurePlate: PressurePlateNode?
        let gate: GateNode?
        let chest: TreasureChestNode?
        let boulder: PushableRockNode?
    }

    // MARK: - Zone 1B — Park Center (105×65, south toward city)

    static func buildCenter() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let tile = GameConstants.tileSize
        let cols = GameConstants.parkCenterCols   // 105
        let rows = GameConstants.parkCenterRows   // 65
        let worldSize = GameConstants.parkCenterWorldSize

        // Ground layer
        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let color = ParkMapDesign.centerGroundColor(col: c, localRow: r)
                let n = SKSpriteNode(color: color, size: CGSize(width: tile, height: tile))
                n.anchorPoint = .zero
                n.position = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                groundLayer.addChild(n)
            }
        }
        root.addChild(groundLayer)

        let border = SKNode()
        border.physicsBody = {
            let b = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: worldSize))
            b.categoryBitMask = GameConstants.Category.wall
            return b
        }()
        root.addChild(border)

        let decorLayer = SKNode(); decorLayer.zPosition = GameConstants.ZPos.decor

        // ── Entrance area (rows 2-10) ────────────────────────────────────────
        let entranceDecor: [(String, Int, Int, Bool)] = [
            ("🚧", 30, 3, true), ("🚧", 35, 3, true), ("🚧", 55, 3, true), ("🚧", 70, 3, true),
            ("🥀", 33, 4, false), ("🥀", 50, 4, false), ("🥀", 72, 4, false),
            ("🪧", 52, 2, false),
            ("🌷", 20, 5, false), ("🌷", 85, 5, false),
            ("🌸", 28, 5, false), ("🌸", 77, 5, false),
            ("🪑", 26, 7, false), ("🪑", 78, 7, false),
            ("🗑️", 40, 6, false), ("🗑️", 65, 6, false),
            ("🌳", 12, 6, true),  ("🌳", 92, 6, true),
            ("🌳", 5, 8, true),   ("🌳", 99, 8, true),
        ]
        addDecor(decorLayer, spots: entranceDecor, tile: tile)

        // ── Dog Run (east area, rows 6-18) ───────────────────────────────────
        let dogRunDecor: [(String, Int, Int, Bool)] = [
            ("🎾", 78, 10, false), ("🎾", 84, 14, false),
            ("🦴", 80, 8, false),  ("🦴", 88, 16, false),
            ("🥣", 82, 11, false),
            ("🐕", 76, 12, false), ("🐕", 85, 9, false),
            ("🌳", 76, 7, true),   ("🌳", 90, 7, true),
            ("🌳", 76, 18, true),  ("🌳", 90, 18, true),
        ]
        addDecor(decorLayer, spots: dogRunDecor, tile: tile)

        // ── Fountain Plaza (center, rows 28-42) ───────────────────────────────
        let fountainDecor: [(String, Int, Int, Bool)] = [
            ("⛲", 52, 35, true),
            ("🪑", 45, 33, false), ("🪑", 59, 33, false),
            ("🪑", 44, 38, false), ("🪑", 60, 38, false),
            ("🪑", 52, 42, false),
            ("🐦", 48, 36, false), ("🐦", 54, 34, false), ("🐦", 50, 40, false),
            ("🐦", 57, 39, false), ("🐦", 43, 41, false),
            ("🗑️", 47, 33, false), ("🗑️", 57, 39, false),
            ("🌸", 46, 30, false), ("🌸", 58, 30, false),
            ("🌸", 44, 35, false), ("🌸", 60, 35, false),
            ("🌻", 42, 42, false), ("🌻", 62, 42, false),
        ]
        addDecor(decorLayer, spots: fountainDecor, tile: tile)

        // ── West forest / meadow (cols 2-18, rows 14-55) ─────────────────────
        let westForestDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 3, 15, true),  ("🌳", 6, 14, true),  ("🌳", 2, 20, true),
            ("🌳", 8, 22, true),  ("🌳", 3, 28, true),  ("🌳", 10, 30, true),
            ("🌲", 5, 35, true),  ("🌲", 10, 38, true), ("🌲", 3, 42, true),
            ("🌲", 8, 46, true),  ("🌳", 4, 50, true),  ("🌳", 12, 52, true),
            ("🌿", 6, 18, false), ("🌿", 4, 25, false), ("🌿", 9, 32, false),
            ("🌿", 6, 40, false), ("🌿", 11, 47, false),
            ("🍄", 7, 20, false), ("🍄", 3, 35, false), ("🍄", 9, 48, false),
            ("🪨", 5, 18, true),  ("🪨", 8, 26, true),  ("🪨", 12, 44, true),
            ("🎤", 12, 20, false),
        ]
        addDecor(decorLayer, spots: westForestDecor, tile: tile)

        // ── East garden (cols 82-103, rows 14-55) ────────────────────────────
        let eastGardenDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 84, 14, true),  ("🌳", 92, 16, true),  ("🌳", 100, 18, true),
            ("🌳", 86, 24, true),  ("🌳", 96, 20, true),  ("🌳", 102, 28, true),
            ("🌲", 84, 30, true),  ("🌲", 90, 35, true),  ("🌲", 98, 40, true),
            ("🌲", 85, 45, true),  ("🌳", 94, 50, true),  ("🌳", 102, 52, true),
            ("🌺", 83, 18, false), ("🌺", 95, 22, false), ("🌺", 101, 36, false),
            ("🌸", 87, 28, false), ("🌸", 97, 44, false),
            ("🌻", 84, 42, false), ("🌻", 99, 48, false),
            ("🪑", 88, 20, false), ("🪑", 95, 35, false),
            ("🪑", 83, 50, false),
        ]
        addDecor(decorLayer, spots: eastGardenDecor, tile: tile)

        // ── North meadow (rows 48-63) ─────────────────────────────────────────
        let northMeadowDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 22, 50, true),  ("🌳", 32, 52, true),  ("🌳", 44, 54, true),
            ("🌳", 56, 56, true),  ("🌳", 68, 52, true),  ("🌳", 78, 50, true),
            ("🌲", 18, 55, true),  ("🌲", 38, 58, true),  ("🌲", 52, 60, true),
            ("🌲", 62, 58, true),  ("🌲", 74, 55, true),
            ("🌿", 26, 53, false), ("🌿", 42, 57, false), ("🌿", 60, 61, false),
            ("🌿", 72, 57, false),
            ("🍄", 30, 55, false), ("🍄", 48, 59, false), ("🍄", 66, 56, false),
            ("🪨", 20, 58, true),  ("🪨", 50, 62, true),  ("🪨", 80, 57, true),
            ("🌸", 35, 56, false), ("🌸", 64, 60, false),
        ]
        addDecor(decorLayer, spots: northMeadowDecor, tile: tile)

        // ── Mid-park trees along paths ────────────────────────────────────────
        let midParkDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 22, 28, true),  ("🌳", 28, 22, true),
            ("🌳", 42, 20, true),  ("🌳", 62, 22, true),  ("🌳", 72, 28, true),
            ("🌲", 18, 35, true),  ("🌲", 86, 32, true),
            ("🪑", 95, 42, false), ("🌸", 96, 40, false),
            ("🌻", 100, 44, false),
        ]
        addDecor(decorLayer, spots: midParkDecor, tile: tile)

        root.addChild(decorLayer)

        // ── Lamp posts along main paths ───────────────────────────────────────
        let lampCoords: [(Int, Int)] = [
            (52, 26), (52, 20), (52, 14), (52, 8),   // central north-south path
            (40, 33), (64, 33),                        // fountain east-west
            (30, 38), (74, 38),                        // mid-park cross
            (20, 28), (84, 28),                        // outer paths
            (95, 22), (95, 42),                        // east garden lamps
            (10, 22), (10, 42),                        // west forest edge
        ]
        for (lc, lr) in lampCoords {
            let lamp = WorldSprites.makeLampPost(city: false)
            lamp.position = CGPoint(x: CGFloat(lc) * tile + tile / 2, y: CGFloat(lr) * tile)
            lamp.zPosition = GameConstants.ZPos.decor + 1
            decorLayer.addChild(lamp)
        }

        // ── Amphitheater (west area, rows 16-32) ────────────────────────────
        buildAmphitheater(root: root, originCol: 2, originRow: 16, tileW: 22, tileH: 18, tile: tile)

        // ── Zone exits ────────────────────────────────────────────────────────
        let southExit = ZoneExitNode(
            destination: .citySouth,
            triggerSize: CGSize(width: worldSize.width, height: tile),
            arrowCount: 8, edgeLabel: "→ City South")
        southExit.position = CGPoint(x: worldSize.width / 2, y: tile / 2)
        root.addChild(southExit)

        let northExit = ZoneExitNode(
            destination: .parkNorth,
            triggerSize: CGSize(width: worldSize.width, height: tile),
            arrowCount: 8, edgeLabel: "→ Park North")
        northExit.position = CGPoint(x: worldSize.width / 2, y: worldSize.height - tile / 2)
        root.addChild(northExit)

        // ── Benches ───────────────────────────────────────────────────────────
        let benchCoords: [(Int, Int)] = [
            (45, 33), (59, 33), (44, 38), (60, 38), (95, 22), (10, 22)
        ]
        let benchPositions = benchCoords.map {
            CGPoint(x: CGFloat($0.0) * tile + tile / 2, y: CGFloat($0.1) * tile + tile / 2)
        }

        let playerSpawn = CGPoint(x: tile * 52.5, y: tile * 4)

        let itemSpawns: [CGPoint] = [
            CGPoint(x: tile * 22, y: tile * 18),
            CGPoint(x: tile * 82, y: tile * 20),
            CGPoint(x: tile * 10, y: tile * 10),
            CGPoint(x: tile * 95, y: tile * 10),
            CGPoint(x: tile * 40, y: tile * 50),
            CGPoint(x: tile * 64, y: tile * 50),
            CGPoint(x: tile * 52, y: tile * 58),
            CGPoint(x: tile * 18, y: tile * 55),
            CGPoint(x: tile * 86, y: tile * 55),
        ]

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 48, y: tile * 36),   // fountain area
            CGPoint(x: tile * 24, y: tile * 20),   // west forest edge
            CGPoint(x: tile * 80, y: tile * 22),   // east garden
            CGPoint(x: tile * 52, y: tile * 14),   // central path
            CGPoint(x: tile * 14, y: tile * 40),   // west benches
            CGPoint(x: tile * 90, y: tile * 38),   // east benches
            CGPoint(x: tile * 52, y: tile * 55),   // north meadow
        ]

        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.ranger,      CGPoint(x: tile * 70, y: tile * 14)),
            (.sternAdult,  CGPoint(x: tile * 30, y: tile * 30)),
            (.wasp,        CGPoint(x: tile * 88, y: tile * 44)),
            (.wasp,        CGPoint(x: tile * 14, y: tile * 44)),
            (.pigeon,      CGPoint(x: tile * 50, y: tile * 34)),
            (.pigeon,      CGPoint(x: tile * 38, y: tile * 18)),
            (.pigeon,      CGPoint(x: tile * 64, y: tile * 18)),
            (.flockLeader, CGPoint(x: tile * 52, y: tile * 38)),   // fountain boss
            (.raccoon,     CGPoint(x: tile * 20, y: tile * 54)),
            (.raccoon,     CGPoint(x: tile * 84, y: tile * 54)),
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawns,
            fixedItems: [],
            enemySpawns: enemySpawns,
            playerSpawn: playerSpawn,
            benchPositions: benchPositions,
            zoneExitNodes: [southExit, northExit],
            pressurePlate: nil,
            gate: nil,
            chest: nil,
            boulder: nil
        )
    }

    // MARK: - Zone 1A — Park North (105×50, pond, ruins, meadow)

    static func buildNorth() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let tile = GameConstants.tileSize
        let cols = GameConstants.parkNorthCols   // 105
        let rows = GameConstants.parkNorthRows   // 50
        let worldSize = GameConstants.parkNorthWorldSize

        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let color = ParkMapDesign.northGroundColor(col: c, localRow: r)
                let n = SKSpriteNode(color: color, size: CGSize(width: tile, height: tile))
                n.anchorPoint = .zero
                n.position = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                groundLayer.addChild(n)
            }
        }
        root.addChild(groundLayer)

        let border = SKNode()
        border.physicsBody = {
            let b = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: worldSize))
            b.categoryBitMask = GameConstants.Category.wall
            return b
        }()
        root.addChild(border)

        // ── Ponds ──────────────────────────────────────────────────────────────
        let pondLayer = SKNode(); pondLayer.zPosition = GameConstants.ZPos.ground + 1
        // Main pond (Gerald's territory) — larger and more prominent
        pondLayer.addChild(makePond(cx: CGFloat(18) * tile, cy: CGFloat(22) * tile,
                                    w: tile * 13, h: tile * 9))
        // East secondary pond
        pondLayer.addChild(makePond(cx: CGFloat(78) * tile, cy: CGFloat(12) * tile,
                                    w: tile * 8, h: tile * 5))
        // Small hidden pond in north forest
        pondLayer.addChild(makePond(cx: CGFloat(52) * tile, cy: CGFloat(40) * tile,
                                    w: tile * 5, h: tile * 3.5))
        root.addChild(pondLayer)

        let decorLayer = SKNode(); decorLayer.zPosition = GameConstants.ZPos.decor

        // ── Quack clue zone (near main pond, rows 8-16) ──────────────────────
        let quackZone: [(String, Int, Int, Bool)] = [
            ("👣", 16, 14,  false),  // duck footprints leading away from pond
            ("👣", 18, 13,  false),
            ("👣", 20, 12,  false),  // trail continues east
            ("⛵", 10, 16, true),   // old rowboat
            ("🪵", 8,  14, true),   // log
        ]
        addDecor(decorLayer, spots: quackZone, tile: tile)

        // ── Gerald's territory markers ────────────────────────────────────────
        let geraldDecor: [(String, Int, Int)] = [
            ("👑", 13, 26), ("👑", 22, 27), ("👑", 10, 22), ("👑", 25, 20),
            ("🪧", 15, 26), // "NO TRESPASSING — By order of Gerald"
            ("🪧", 21, 20),
        ]
        for (g, c, r) in geraldDecor {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile, height: tile)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            n.zPosition = GameConstants.ZPos.decor
            root.addChild(n)
        }

        // ── Dense forest (west side, cols 2-12) ──────────────────────────────
        let westTreeDecor: [(String, Int, Int, Bool)] = [
            ("🌲", 2, 5, true),  ("🌲", 5, 8, true),  ("🌲", 3, 14, true),
            ("🌲", 8, 10, true), ("🌲", 4, 20, true), ("🌲", 7, 28, true),
            ("🌲", 3, 34, true), ("🌲", 9, 38, true), ("🌲", 5, 44, true),
            ("🌳", 2, 30, true), ("🌳", 6, 40, true),
            ("🌿", 4, 12, false), ("🌿", 6, 22, false), ("🌿", 3, 36, false),
            ("🍄", 5, 16, false), ("🍄", 8, 32, false), ("🍄", 4, 46, false),
        ]
        addDecor(decorLayer, spots: westTreeDecor, tile: tile)

        // ── East forest (cols 88-103) ─────────────────────────────────────────
        let eastTreeDecor: [(String, Int, Int, Bool)] = [
            ("🌲", 90, 6, true),  ("🌲", 94, 10, true), ("🌲", 98, 8, true),
            ("🌲", 92, 16, true), ("🌲", 100, 14, true), ("🌳", 96, 20, true),
            ("🌲", 88, 22, true), ("🌲", 102, 22, true), ("🌳", 90, 30, true),
            ("🌲", 96, 34, true), ("🌲", 88, 40, true),  ("🌳", 100, 38, true),
            ("🌿", 92, 12, false), ("🌿", 98, 28, false), ("🌿", 91, 44, false),
            ("🍄", 94, 24, false), ("🍄", 99, 40, false),
        ]
        addDecor(decorLayer, spots: eastTreeDecor, tile: tile)

        // ── Central meadow / upper reaches ────────────────────────────────────
        let meadowDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 36, 30, true),  ("🌳", 52, 28, true), ("🌳", 68, 32, true),
            ("🌳", 40, 42, true),  ("🌳", 60, 44, true),
            ("🌲", 28, 36, true),  ("🌲", 76, 36, true),
            ("🌿", 44, 30, false), ("🌿", 56, 34, false),
            ("🍄", 34, 38, false), ("🍄", 70, 40, false),
            ("🌸", 48, 32, false), ("🌸", 62, 30, false),
            ("🪑", 44, 16, false), // Scenic bench near east pond
            ("🪑", 32, 14, false),
            ("🌺", 36, 10, false), ("🌺", 72, 10, false),
        ]
        addDecor(decorLayer, spots: meadowDecor, tile: tile)

        // ── East secondary pond area ──────────────────────────────────────────
        let eastPondDecor: [(String, Int, Int, Bool)] = [
            ("⛵", 74, 10, true),
            ("🌲", 72, 8, true), ("🌲", 84, 8, true),
            ("🌿", 75, 14, false),
            ("🪧", 70, 8, false),  // "East pond — no fishing"
        ]
        addDecor(decorLayer, spots: eastPondDecor, tile: tile)

        // ── Hidden ruins / north area ──────────────────────────────────────────
        let ruinsDecor: [(String, Int, Int, Bool)] = [
            ("🪨", 28, 46, true), ("🪨", 36, 44, true), ("🪨", 52, 48, true),
            ("🪨", 68, 44, true), ("🪨", 78, 46, true),
            ("🌿", 32, 45, false), ("🌿", 55, 47, false), ("🌿", 72, 45, false),
            ("🍄", 40, 47, false), ("🍄", 64, 46, false),
        ]
        addDecor(decorLayer, spots: ruinsDecor, tile: tile)

        root.addChild(decorLayer)

        // ── Lamp posts ────────────────────────────────────────────────────────
        let lampCoords: [(Int, Int)] = [
            (28, 5), (52, 5), (76, 5),   // south entry row
            (16, 18), (28, 18),           // pond west
            (40, 20), (52, 20),           // central path
            (76, 18), (88, 18),           // east area
        ]
        for (lc, lr) in lampCoords {
            let lamp = WorldSprites.makeLampPost(city: false)
            lamp.position = CGPoint(x: CGFloat(lc) * tile + tile / 2, y: CGFloat(lr) * tile)
            lamp.zPosition = GameConstants.ZPos.decor + 1
            decorLayer.addChild(lamp)
        }

        // ── Puzzle room (east, col 70+, row 8+) ──────────────────────────────
        let (plate, gate, chest, boulder) = buildPuzzleRoom16(
            root: root, originCol: 72, originRow: 8, tile: tile)

        // ── Zone exits ────────────────────────────────────────────────────────
        let southExit = ZoneExitNode(
            destination: .parkCenter,
            triggerSize: CGSize(width: worldSize.width, height: tile),
            arrowCount: 8, edgeLabel: "→ Park Center")
        southExit.position = CGPoint(x: worldSize.width / 2, y: tile / 2)
        root.addChild(southExit)

        let benchPositions: [CGPoint] = [
            CGPoint(x: tile * 44.5, y: tile * 16.5),
            CGPoint(x: tile * 32.5, y: tile * 14.5),
        ]

        let playerSpawn = CGPoint(x: tile * 52.5, y: tile * 5)

        let itemSpawns: [CGPoint] = [
            CGPoint(x: tile * 38, y: tile * 28),
            CGPoint(x: tile * 82, y: tile * 20),
            CGPoint(x: tile * 16, y: tile * 10),
            CGPoint(x: tile * 52, y: tile * 44),
            CGPoint(x: tile * 26, y: tile * 44),
            CGPoint(x: tile * 78, y: tile * 44),
        ]

        let quackFeatherSpawn = CGPoint(x: tile * 20, y: tile * 14)

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 22, y: tile * 18),  // near main pond
            CGPoint(x: tile * 80, y: tile * 14),  // near east pond
            CGPoint(x: tile * 52, y: tile * 36),  // deep meadow
        ]

        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.grandGooseGerald, CGPoint(x: tile * 16, y: tile * 22)),  // Boss — guards the main pond
            (.goose,            CGPoint(x: tile * 20, y: tile * 18)),  // Gerald's lieutenants
            (.goose,            CGPoint(x: tile * 12, y: tile * 26)),
            (.raccoon,          CGPoint(x: tile * 84, y: tile * 14)),
            (.raccoon,          CGPoint(x: tile * 40, y: tile * 42)),
            (.sternAdult,       CGPoint(x: tile * 14, y: tile * 8)),
            (.wasp,             CGPoint(x: tile * 90, y: tile * 10)),
            (.wasp,             CGPoint(x: tile * 55, y: tile * 40)),
            (.pigeon,           CGPoint(x: tile * 50, y: tile * 20)),
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawns,
            fixedItems: [(.quackFeather, quackFeatherSpawn)],
            enemySpawns: enemySpawns,
            playerSpawn: playerSpawn,
            benchPositions: benchPositions,
            zoneExitNodes: [southExit],
            pressurePlate: plate,
            gate: gate,
            chest: chest,
            boulder: boulder
        )
    }

    // MARK: - Shared helpers

    private static func addDecor(_ layer: SKNode, spots: [(String, Int, Int, Bool)], tile: CGFloat) {
        for (glyph, c, r, blocks) in spots {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(glyph, size: 96))
            n.size = CGSize(width: tile * 1.1, height: tile * 1.1)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            n.zPosition = GameConstants.ZPos.decor
            if blocks {
                let b = SKPhysicsBody(circleOfRadius: tile * 0.38)
                b.isDynamic = false
                b.categoryBitMask = GameConstants.Category.wall
                n.physicsBody = b
            }
            layer.addChild(n)
        }
    }

    private static func makePond(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: cx, y: cy)

        let pond = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        pond.fillColor   = GamePalette.waterMid
        pond.strokeColor = GamePalette.waterDeep.withAlphaComponent(0.55)
        pond.lineWidth   = 4
        container.addChild(pond)

        // Shore fringe (lighter band)
        let shore = SKShapeNode(ellipseOf: CGSize(width: w * 1.08, height: h * 1.10))
        shore.fillColor   = GamePalette.waterMid.withAlphaComponent(0.30)
        shore.strokeColor = .clear
        container.addChild(shore)
        shore.zPosition = -0.1

        // Animated ripple rings
        for i in 0..<4 {
            let ripple = SKShapeNode(ellipseOf: CGSize(width: w * 0.32, height: h * 0.32))
            ripple.fillColor   = .clear
            ripple.strokeColor = GamePalette.waterHighlight.withAlphaComponent(0.45)
            ripple.lineWidth   = 1.5
            ripple.position    = CGPoint(x: CGFloat.random(in: -w*0.2...w*0.2),
                                         y: CGFloat.random(in: -h*0.15...h*0.15))
            ripple.alpha       = 0
            container.addChild(ripple)

            let delay = Double(i) * 1.0
            ripple.run(.repeatForever(.sequence([
                .wait(forDuration: delay),
                .group([
                    .scale(to: 2.4, duration: 1.8),
                    .sequence([
                        .fadeIn(withDuration: 0.3),
                        .fadeAlpha(to: 0, duration: 1.5)
                    ])
                ]),
                .scale(to: 1.0, duration: 0)
            ])))
        }

        let shimmer = SKShapeNode(ellipseOf: CGSize(width: w * 0.28, height: h * 0.18))
        shimmer.fillColor   = GamePalette.waterHighlight.withAlphaComponent(0.30)
        shimmer.strokeColor = .clear
        shimmer.position    = CGPoint(x: -w * 0.15, y: h * 0.1)
        shimmer.run(.repeatForever(.sequence([
            .moveBy(x: w * 0.22, y: h * 0.05, duration: 2.8),
            .moveBy(x: -w * 0.22, y: -h * 0.05, duration: 2.8)
        ])))
        container.addChild(shimmer)

        let body = SKPhysicsBody(circleOfRadius: min(w, h) * 0.42)
        body.isDynamic = false
        body.categoryBitMask = GameConstants.Category.wall
        container.physicsBody = body

        return container
    }

    private static func buildAmphitheater(
        root: SKNode, originCol: Int, originRow: Int, tileW: Int, tileH: Int, tile: CGFloat
    ) {
        let stoneColor  = SKColor(red: 0.62, green: 0.60, blue: 0.56, alpha: 1)
        let stoneColor2 = SKColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 1)
        for r in 0..<tileH {
            for c in 0..<tileW {
                let col = (r + c) % 2 == 0 ? stoneColor : stoneColor2
                let tileNode = SKSpriteNode(color: col, size: CGSize(width: tile, height: tile))
                tileNode.anchorPoint = .zero
                tileNode.position = CGPoint(x: CGFloat(originCol + c) * tile,
                                            y: CGFloat(originRow + r) * tile)
                tileNode.zPosition = GameConstants.ZPos.ground + 1.2
                root.addChild(tileNode)
            }
        }
        let centerX = CGFloat(originCol + tileW / 2) * tile
        let centerY = CGFloat(originRow + tileH / 2) * tile
        for i in 0..<16 {
            let angle = CGFloat(i) / 15.0 * .pi
            let radius: CGFloat = tile * CGFloat(min(tileW, tileH)) * 0.32
            let sx = centerX + cos(angle) * radius * 1.15
            let sy = centerY - sin(angle) * radius * 0.55
            let seat = SKSpriteNode(texture: SpriteFactory.emojiTexture("🪨", size: 96))
            seat.size = CGSize(width: tile * 0.90, height: tile * 0.90)
            seat.position = CGPoint(x: sx, y: sy)
            seat.zPosition = GameConstants.ZPos.decor
            root.addChild(seat)
        }
        let stage = SKSpriteNode(
            color: SKColor(red: 0.70, green: 0.68, blue: 0.64, alpha: 1),
            size: CGSize(width: tile * CGFloat(tileW / 3), height: tile * 2)
        )
        stage.position = CGPoint(x: centerX, y: CGFloat(originRow + 1) * tile + tile)
        stage.zPosition = GameConstants.ZPos.ground + 1.4
        root.addChild(stage)
    }

    private static func buildPuzzleRoom16(
        root: SKNode, originCol: Int, originRow: Int, tile: CGFloat
    ) -> (PressurePlateNode, GateNode, TreasureChestNode, PushableRockNode) {

        let roomLayer = SKNode(); roomLayer.zPosition = GameConstants.ZPos.ground + 2
        root.addChild(roomLayer)

        func pos(_ c: Int, _ r: Int) -> CGPoint {
            CGPoint(
                x: CGFloat(originCol + c) * tile + tile / 2,
                y: CGFloat(originRow + r) * tile + tile / 2)
        }

        let sf1 = SKColor(red: 0.60, green: 0.58, blue: 0.55, alpha: 1)
        let sf2 = SKColor(red: 0.63, green: 0.61, blue: 0.58, alpha: 1)
        for r in 0..<16 {
            for c in 0..<16 {
                let t = SKSpriteNode(color: (r + c) % 2 == 0 ? sf1 : sf2,
                                     size: CGSize(width: tile, height: tile))
                t.anchorPoint = .zero
                t.position = CGPoint(x: CGFloat(originCol + c) * tile, y: CGFloat(originRow + r) * tile)
                t.zPosition = GameConstants.ZPos.ground + 1.5
                root.addChild(t)
            }
        }

        var walls: [(Int, Int)] = []
        for c in 0..<16 { walls.append((c, 15)) }
        for c in 0..<16 where c < 6 || c > 9 { walls.append((c, 0)) }
        for r in 1..<15 { walls.append((0, r)); walls.append((15, r)) }
        for r in 10..<16 { for c in 6..<16 { walls.append((c, r)) } }

        for (dc, dr) in walls {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture("🧱", size: 96))
            n.size = CGSize(width: tile, height: tile)
            n.position = pos(dc, dr)
            n.zPosition = GameConstants.ZPos.decor
            let b = SKPhysicsBody(rectangleOf: CGSize(width: tile - 4, height: tile - 4))
            b.isDynamic = false
            b.categoryBitMask = GameConstants.Category.wall
            n.physicsBody = b
            roomLayer.addChild(n)
        }

        let plate = PressurePlateNode(); plate.position = pos(6, 4); root.addChild(plate)
        let gate = GateNode(); gate.position = pos(6, 8); root.addChild(gate)
        let chest = TreasureChestNode(); chest.position = pos(6, 12); root.addChild(chest)
        let boulder = PushableRockNode(); boulder.position = pos(6, 2); root.addChild(boulder)

        return (plate, gate, chest, boulder)
    }
}
