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
    //
    // Layout (row 0 = south/city edge, row 64 = north/park-north edge):
    //   Rows  0- 1 : Road
    //   Rows  2- 3 : Sidewalk / entrance
    //   Rows  4-64 : Park interior
    //
    // Left forest  : cols  0- 8  (grassShade ground + dense trees)
    // Right forest : cols 96-104 (grassShade ground + dense trees)
    // Top fringe   : rows 55-64  (grassShade + tree fringe)
    //
    // N-S golden spine  : cols 49-53, rows 4-54
    // E-W crossing path : cols  9-95, rows 22-25
    //
    // Pond         : centre col 22, row 39  (radiusX 10, radiusY 8)
    // Fountain plaza: stone cols 56-70, rows 27-42 + water centre 63,34
    // Statue garden : stone cols 70-77, rows 11-18
    // Two west houses: rough cols 10-20, rows 40-55

    static func buildCenter() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let tile = GameConstants.tileSize
        let cols = GameConstants.parkCenterCols   // 105
        let rows = GameConstants.parkCenterRows   // 65
        let worldSize = GameConstants.parkCenterWorldSize

        // ── Ground base layer ─────────────────────────────────────────────────
        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let isForest = c < 9 || c > cols - 10 || r > rows - 10
                let surface: TerrainSurface = isForest ? .grassShade : .grass
                let n = makeParkGroundTile(surface: surface, col: c, row: r, tile: tile)
                n.anchorPoint = .zero
                n.position = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                groundLayer.addChild(n)
            }
        }
        root.addChild(groundLayer)

        // ── Terrain overlay (paths, water, stone) ────────────────────────────
        let terrainLayer = SKNode()
        terrainLayer.zPosition = GameConstants.ZPos.ground + 0.6
        root.addChild(terrainLayer)

        // Road + sidewalk at south edge
        paintRectSurface(on: terrainLayer, surface: .road,     cols: 0...104, rows: 0...1, tile: tile)
        paintRectSurface(on: terrainLayer, surface: .sidewalk, cols: 0...104, rows: 2...3, tile: tile)

        // N-S main golden spine (4 tiles wide, col 49-52)
        paintRectSurface(on: terrainLayer, surface: .path, cols: 49...52, rows: 4...54, tile: tile)

        // E-W crossing path (4 tiles tall, rows 22-25, full park width)
        paintRectSurface(on: terrainLayer, surface: .path, cols: 9...95,  rows: 22...25, tile: tile)

        // Short stub from N-S spine up to entrance (cleans the junction)
        paintRectSurface(on: terrainLayer, surface: .path, cols: 49...52, rows: 4...8, tile: tile)

        // Branch path from crossing west toward pond dock
        paintDirtRibbon(on: terrainLayer,
                        path: [(32, 23), (28, 24), (24, 25), (20, 27)],
                        radius: 1, tile: tile)

        // Branch path from crossing east toward statue garden
        paintDirtRibbon(on: terrainLayer,
                        path: [(53, 23), (59, 22), (65, 20), (71, 18), (74, 16)],
                        radius: 1, tile: tile)

        // Connector from N-S spine south to fountain plaza
        paintDirtRibbon(on: terrainLayer,
                        path: [(51, 27), (53, 29), (55, 31)],
                        radius: 1, tile: tile)

        // Pond (left side, above E-W crossing)
        paintEllipseSurface(on: terrainLayer, surface: .water,
                            centerCol: 22, centerRow: 39,
                            radiusX: 10, radiusY: 8, tile: tile)

        // Fountain plaza (stone, right-of-center, rows 27-42)
        paintRectSurface(on: terrainLayer, surface: .stone,
                         cols: 56...70, rows: 27...42, tile: tile)
        // Fountain basin in centre of plaza
        paintEllipseSurface(on: terrainLayer, surface: .water,
                            centerCol: 63, centerRow: 35,
                            radiusX: 3, radiusY: 2, tile: tile)

        // Statue garden stone pad (right side, upper area)
        paintRectSurface(on: terrainLayer, surface: .stone,
                         cols: 70...77, rows: 11...18, tile: tile)

        // Grass tufts scattered through interior (reduces visual monotony)
        sprinkleGrassTufts(on: terrainLayer,
                           points: [(30, 8), (42, 10), (58, 9), (76, 12),
                                    (18, 16), (38, 28), (46, 32), (80, 28),
                                    (16, 50), (30, 48), (44, 52), (60, 50), (84, 48)],
                           tile: tile)

        // ── World border physics ──────────────────────────────────────────────
        let border = SKNode()
        border.physicsBody = {
            let b = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: worldSize))
            b.categoryBitMask = GameConstants.Category.wall
            return b
        }()
        root.addChild(border)

        // ── Decoration layer ──────────────────────────────────────────────────
        let decorLayer = SKNode(); decorLayer.zPosition = GameConstants.ZPos.decor

        // Dense forest border — left side (cols 1-8)
        var leftForest: [(String, Int, Int, Bool)] = []
        for r in stride(from: 6, through: 54, by: 3) {
            let col = 2 + (r % 5)
            leftForest.append((r % 6 == 0 ? "🌳" : "🌲", col, r, true))
        }
        // Extra fill for left forest
        leftForest += [
            ("🌲", 4, 8, true), ("🌳", 6, 12, true), ("🌲", 3, 17, true),
            ("🌳", 7, 22, true), ("🌲", 4, 27, true), ("🌳", 6, 32, true),
            ("🌿", 5, 10, false), ("🌿", 7, 18, false), ("🌿", 4, 35, false), ("🌿", 6, 45, false),
        ]
        addDecor(decorLayer, spots: leftForest, tile: tile)

        // Dense forest border — right side (cols 96-103)
        var rightForest: [(String, Int, Int, Bool)] = []
        for r in stride(from: 6, through: 54, by: 3) {
            let col = 97 + (r % 6)
            rightForest.append((r % 6 == 0 ? "🌳" : "🌲", col, r, true))
        }
        rightForest += [
            ("🌲", 98, 8, true),  ("🌳", 100, 13, true), ("🌲", 97, 18, true),
            ("🌳", 102, 23, true),("🌲", 98, 28, true),  ("🌳", 100, 33, true),
            ("🌿", 99, 11, false), ("🌿", 101, 21, false), ("🌿", 98, 38, false),
        ]
        addDecor(decorLayer, spots: rightForest, tile: tile)

        // Dense forest fringe — top rows (rows 55-64)
        var topForest: [(String, Int, Int, Bool)] = []
        for c in stride(from: 10, through: 94, by: 4) {
            let rowOffset = (c % 3 == 0) ? 57 : 56
            topForest.append((c % 8 == 0 ? "🌳" : "🌲", c, rowOffset, true))
        }
        topForest += [
            ("🌿", 20, 58, false), ("🌿", 44, 59, false), ("🌿", 68, 58, false), ("🌿", 88, 59, false),
            ("🌸", 30, 59, false), ("🌸", 58, 60, false), ("🌸", 80, 59, false),
        ]
        addDecor(decorLayer, spots: topForest, tile: tile)

        // Pond surroundings — dock, willows, path bench
        let pondDecor: [(String, Int, Int, Bool)] = [
            ("🪵", 29, 35, true),   // wooden dock log
            ("🪵", 30, 37, true),
            ("🌳", 14, 34, true),   // willow-like tree left of pond
            ("🌳", 16, 42, true),
            ("🌲", 12, 44, true),
            ("🌲", 14, 28, true),
            ("🌿", 12, 36, false), ("🌿", 15, 46, false),
            ("🌸", 16, 30, false),
            ("🪑", 30, 28, false),  // bench near pond path
            ("🗑️", 32, 22, false),  // bin by crossing
        ]
        addDecor(decorLayer, spots: pondDecor, tile: tile)

        // West houses (reference map shows two small buildings left of pond)
        let westHouses: [(String, Int, Int, Bool)] = [
            ("🏠", 12, 48, true),   // house 1
            ("🏠", 12, 42, true),   // house 2
            ("🌷", 16, 48, false), ("🌷", 16, 43, false),
            ("🌿", 10, 46, false),
        ]
        addDecor(decorLayer, spots: westHouses, tile: tile)

        // Fountain plaza decor
        let fountainDecor: [(String, Int, Int, Bool)] = [
            ("⛲", 63, 35, true),
            ("🌳", 55, 42, true),  ("🌳", 70, 42, true),  // trees flanking south
            ("🌳", 55, 28, true),  ("🌳", 70, 28, true),  // trees flanking north
            ("🪑", 57, 28, false), ("🪑", 68, 28, false), // benches
            ("🪑", 57, 42, false), ("🪑", 68, 42, false),
            ("🌸", 58, 27, false), ("🌸", 67, 27, false),
            ("🌸", 58, 43, false), ("🌸", 67, 43, false),
            ("🪧", 60, 26, false),
        ]
        addDecor(decorLayer, spots: fountainDecor, tile: tile)

        // Statue garden
        let statueDecor: [(String, Int, Int, Bool)] = [
            ("🗿", 73, 14, true),
            ("🌳", 68, 18, true),  ("🌳", 78, 18, true),
            ("🌿", 70, 12, false), ("🌿", 76, 12, false),
            ("🌸", 69, 10, false), ("🌸", 77, 10, false),
            ("🪑", 73, 10, false),
        ]
        addDecor(decorLayer, spots: statueDecor, tile: tile)

        // Entrance area (road/sidewalk edge, rows 3-8)
        let entranceDecor: [(String, Int, Int, Bool)] = [
            ("🚧", 30, 3, true), ("🚧", 72, 3, true),
            ("🪧", 51, 2, false),
            ("🌷", 18, 5, false), ("🌷", 84, 5, false),
            ("🪑", 24, 7, false), ("🪑", 78, 7, false),
            ("🗑️", 26, 7, false), ("🗑️", 76, 7, false),
        ]
        addDecor(decorLayer, spots: entranceDecor, tile: tile)

        // Central meadow (between spine and top forest)
        let meadowDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 30, 48, true), ("🌳", 44, 50, true),
            ("🌳", 62, 52, true), ("🌳", 78, 50, true),
            ("🌲", 36, 52, true), ("🌲", 54, 54, true), ("🌲", 72, 52, true),
            ("🌿", 40, 50, false), ("🌿", 56, 52, false), ("🌿", 74, 50, false),
            ("🌸", 48, 52, false), ("🌸", 66, 52, false),
        ]
        addDecor(decorLayer, spots: meadowDecor, tile: tile)

        // Large oak tree — left of central crossing (reference landmark)
        let oakDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 38, 30, true), ("🌳", 40, 32, true), ("🌲", 36, 32, true),
            ("🌿", 34, 30, false), ("🌿", 42, 28, false),
        ]
        addDecor(decorLayer, spots: oakDecor, tile: tile)

        root.addChild(decorLayer)

        // ── Lamp posts along main paths ───────────────────────────────────────
        let lampCoords: [(Int, Int)] = [
            (50, 8),  (50, 17),          // N-S spine
            (63, 26), (63, 43),          // Fountain plaza north/south
            (22, 21), (80, 21),          // E-W crossing sides
            (22, 52), (80, 52),          // meadow
        ]
        for (lc, lr) in lampCoords {
            let lamp = WorldSprites.makeLampPost(city: false)
            lamp.position = CGPoint(x: CGFloat(lc) * tile + tile / 2, y: CGFloat(lr) * tile)
            lamp.zPosition = GameConstants.ZPos.decor + 1
            decorLayer.addChild(lamp)
        }

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
        let benchPositions = [
            CGPoint(x: tile * 57.5, y: tile * 28.5),
            CGPoint(x: tile * 68.5, y: tile * 28.5),
            CGPoint(x: tile * 73.5, y: tile * 10.5),
            CGPoint(x: tile * 30.5, y: tile * 28.5),
        ]

        let playerSpawn = CGPoint(x: tile * 51, y: tile * 4)

        let itemSpawns: [CGPoint] = [
            CGPoint(x: tile * 30, y: tile * 10),
            CGPoint(x: tile * 63, y: tile * 32),
            CGPoint(x: tile * 20, y: tile * 26),
            CGPoint(x: tile * 73, y: tile * 13),
        ]

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 63, y: tile * 38),   // fountain
            CGPoint(x: tile * 24, y: tile * 24),   // near pond path
            CGPoint(x: tile * 73, y: tile * 15),   // statue garden
            CGPoint(x: tile * 51, y: tile * 14),   // central spine
            CGPoint(x: tile * 13, y: tile * 44),   // west house
            CGPoint(x: tile * 82, y: tile * 30),   // east meadow
            CGPoint(x: tile * 51, y: tile * 50),   // north meadow
        ]

        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.ranger,      CGPoint(x: tile * 72, y: tile * 14)),
            (.sternAdult,  CGPoint(x: tile * 32, y: tile * 32)),
            (.wasp,        CGPoint(x: tile * 86, y: tile * 44)),
            (.wasp,        CGPoint(x: tile * 14, y: tile * 44)),
            (.pigeon,      CGPoint(x: tile * 49, y: tile * 34)),
            (.pigeon,      CGPoint(x: tile * 36, y: tile * 20)),
            (.pigeon,      CGPoint(x: tile * 66, y: tile * 20)),
            (.flockLeader, CGPoint(x: tile * 51, y: tile * 38)),
            (.raccoon,     CGPoint(x: tile * 20, y: tile * 54)),
            (.raccoon,     CGPoint(x: tile * 82, y: tile * 54)),
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
                let surface: TerrainSurface = (c < 10 || c > cols - 11) ? .grassShade : .grass
                let n = makeParkGroundTile(surface: surface, col: c, row: r, tile: tile)
                n.anchorPoint = .zero
                n.position = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                groundLayer.addChild(n)
            }
        }
        root.addChild(groundLayer)

        let terrainLayer = SKNode()
        terrainLayer.zPosition = GameConstants.ZPos.ground + 0.6
        root.addChild(terrainLayer)

        paintDirtRibbon(
            on: terrainLayer,
            path: [(52, 4), (49, 7), (45, 10), (40, 13), (34, 16), (28, 18), (20, 19)],
            radius: 1,
            tile: tile
        )
        paintDirtRibbon(
            on: terrainLayer,
            path: [(52, 4), (57, 7), (62, 10), (67, 13), (72, 16), (77, 18)],
            radius: 1,
            tile: tile
        )
        paintEllipseSurface(on: terrainLayer, surface: .water, centerCol: 18, centerRow: 18, radiusX: 8, radiusY: 5, tile: tile)
        paintEllipseSurface(on: terrainLayer, surface: .water, centerCol: 78, centerRow: 16, radiusX: 5, radiusY: 4, tile: tile)
        paintBridgePatch(on: terrainLayer, originCol: 18, originRow: 22, tile: tile)
        paintRectSurface(on: terrainLayer, surface: .stone, cols: 44...58, rows: 35...41, tile: tile)
        paintFenceRun(on: terrainLayer, startCol: 14, row: 23, length: 10, tile: tile)
        addCliffFace(on: terrainLayer, startCol: 14, startRow: 24, length: 10, horizontal: true, tile: tile)
        addCliffFace(on: terrainLayer, startCol: 72, startRow: 20, length: 10, horizontal: true, tile: tile)
        sprinkleGrassTufts(on: terrainLayer,
                           points: [(20, 18), (28, 16), (39, 14), (48, 15), (60, 17), (72, 17),
                                    (36, 24), (46, 27), (58, 28), (70, 22), (46, 35), (58, 37), (70, 34)],
                           tile: tile)

        let border = SKNode()
        border.physicsBody = {
            let b = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: worldSize))
            b.categoryBitMask = GameConstants.Category.wall
            return b
        }()
        root.addChild(border)

        let decorLayer = SKNode(); decorLayer.zPosition = GameConstants.ZPos.decor

        // ── Quack clue zone (near main pond, rows 8-16) ──────────────────────
        let quackZone: [(String, Int, Int, Bool)] = [
            ("👣", 18, 15, false),
            ("👣", 20, 14, false),
            ("👣", 22, 13, false),
            ("⛵", 14, 16, true),
            ("🪵", 12, 13, true),
        ]
        addDecor(decorLayer, spots: quackZone, tile: tile)

        // ── Gerald's territory markers ────────────────────────────────────────
        let geraldDecor: [(String, Int, Int)] = [
            ("👑", 18, 23), ("👑", 24, 22), ("🪧", 21, 23),
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
            ("🌳", 6, 10, true), ("🌲", 10, 14, true), ("🌲", 7, 24, true),
            ("🌲", 9, 34, true), ("🌳", 6, 42, true), ("🌲", 12, 46, true),
            ("🌿", 9, 18, false), ("🌿", 7, 34, false), ("🍄", 6, 28, false),
        ]
        addDecor(decorLayer, spots: westTreeDecor, tile: tile)

        // ── East forest (cols 88-103) ─────────────────────────────────────────
        let eastTreeDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 92, 10, true), ("🌲", 97, 16, true), ("🌲", 92, 24, true),
            ("🌳", 98, 34, true), ("🌲", 92, 42, true), ("🌿", 94, 18, false),
            ("🌿", 96, 28, false), ("🍄", 98, 22, false),
        ]
        addDecor(decorLayer, spots: eastTreeDecor, tile: tile)

        // ── Central meadow / upper reaches ────────────────────────────────────
        let meadowDecor: [(String, Int, Int, Bool)] = [
            ("🌳", 34, 14, true), ("🌳", 48, 18, true), ("🌳", 64, 20, true),
            ("🌳", 42, 30, true), ("🌳", 60, 32, true),
            ("🌿", 38, 16, false), ("🌿", 58, 19, false), ("🌿", 48, 28, false),
            ("🌸", 40, 22, false), ("🌸", 58, 24, false),
            ("🪑", 32, 14, false), ("🪑", 76, 16, false),
        ]
        addDecor(decorLayer, spots: meadowDecor, tile: tile)

        // ── East secondary pond area ──────────────────────────────────────────
        let eastPondDecor: [(String, Int, Int, Bool)] = [
            ("⛵", 78, 15, true), ("🪵", 80, 18, true), ("🌿", 82, 18, false), ("🪧", 72, 14, false),
        ]
        addDecor(decorLayer, spots: eastPondDecor, tile: tile)

        // ── Hidden ruins / north area ──────────────────────────────────────────
        let ruinsDecor: [(String, Int, Int, Bool)] = [
            ("🪨", 46, 36, true), ("🪨", 56, 36, true), ("🪨", 52, 40, true),
            ("🌿", 48, 37, false), ("🌿", 58, 37, false), ("🍄", 52, 38, false), ("🗿", 51, 36, true),
        ]
        addDecor(decorLayer, spots: ruinsDecor, tile: tile)

        root.addChild(decorLayer)

        // ── Lamp posts ────────────────────────────────────────────────────────
        let lampCoords: [(Int, Int)] = [
            (32, 14), (52, 6), (78, 16),
            (20, 18), (52, 24)
        ]
        for (lc, lr) in lampCoords {
            let lamp = WorldSprites.makeLampPost(city: false)
            lamp.position = CGPoint(x: CGFloat(lc) * tile + tile / 2, y: CGFloat(lr) * tile)
            lamp.zPosition = GameConstants.ZPos.decor + 1
            decorLayer.addChild(lamp)
        }

        // ── Zone exits ────────────────────────────────────────────────────────
        let southExit = ZoneExitNode(
            destination: .parkCenter,
            triggerSize: CGSize(width: worldSize.width, height: tile),
            arrowCount: 8, edgeLabel: "→ Park Center")
        southExit.position = CGPoint(x: worldSize.width / 2, y: tile / 2)
        root.addChild(southExit)

        let benchPositions: [CGPoint] = [
            CGPoint(x: tile * 52.5, y: tile * 24.5),
            CGPoint(x: tile * 32.5, y: tile * 14.5),
        ]

        let playerSpawn = CGPoint(x: tile * 52.5, y: tile * 5)

        let itemSpawns: [CGPoint] = [
            CGPoint(x: tile * 24, y: tile * 16),
            CGPoint(x: tile * 80, y: tile * 17),
            CGPoint(x: tile * 52, y: tile * 35),
            CGPoint(x: tile * 72, y: tile * 20),
        ]

        let quackFeatherSpawn = CGPoint(x: tile * 20, y: tile * 14)

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 22, y: tile * 18),
            CGPoint(x: tile * 80, y: tile * 17),
            CGPoint(x: tile * 52, y: tile * 30),
        ]

        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.grandGooseGerald, CGPoint(x: tile * 20, y: tile * 20)),
            (.goose,            CGPoint(x: tile * 24, y: tile * 18)),
            (.goose,            CGPoint(x: tile * 16, y: tile * 24)),
            (.raccoon,          CGPoint(x: tile * 84, y: tile * 18)),
            (.raccoon,          CGPoint(x: tile * 40, y: tile * 36)),
            (.sternAdult,       CGPoint(x: tile * 14, y: tile * 8)),
            (.wasp,             CGPoint(x: tile * 90, y: tile * 10)),
            (.wasp,             CGPoint(x: tile * 55, y: tile * 34)),
            (.pigeon,           CGPoint(x: tile * 50, y: tile * 22)),
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
            pressurePlate: nil,
            gate: nil,
            chest: nil,
            boulder: nil
        )
    }

    // MARK: - Shared helpers

    private static func makeParkGroundTile(surface: TerrainSurface, col: Int, row: Int, tile: CGFloat) -> SKSpriteNode {
        let node: SKSpriteNode
        let variant = abs(((col &* 73) ^ (row &* 151) ^ ((col + row) &* 19)))

        let sz = CGSize(width: tile, height: tile)
        switch surface {
        case .grass:
            node = SKSpriteNode(texture: ImportedArt.sproutGrassTexture(variant: variant)
                                ?? SKSpriteNode(color: GamePalette.grassG1, size: sz).texture)
        case .grassShade:
            node = SKSpriteNode(texture: ImportedArt.sproutShadeGrassTexture(variant: variant)
                                ?? ImportedArt.sproutGrassTexture(variant: variant + 3))
        case .path:
            node = SKSpriteNode(texture: ImportedArt.sproutPathTexture(variant: variant)
                                ?? SKSpriteNode(color: GamePalette.dirtD1, size: sz).texture)
        case .water:
            node = SKSpriteNode(texture: ImportedArt.sproutWaterTexture(variant: variant)
                                ?? SKSpriteNode(color: GamePalette.waterMid, size: sz).texture)
        case .stone:
            node = SKSpriteNode(texture: ImportedArt.sproutHillTexture(col: variant % 3, row: 2)
                                ?? SKSpriteNode(color: SKColor(white: 0.58, alpha: 1), size: sz).texture)
        case .sidewalk:
            node = SKSpriteNode(texture: ImportedArt.sproutPathTexture(variant: variant + 1)
                                ?? SKSpriteNode(color: GamePalette.sidewalk1, size: sz).texture)
        case .road:
            node = SKSpriteNode(texture: ImportedArt.sproutPathTexture(variant: variant + 2)
                                ?? SKSpriteNode(color: GamePalette.roadR1, size: sz).texture)
        case .asphalt:
            node = SKSpriteNode(texture: ImportedArt.sproutPathTexture(variant: variant + 3)
                                ?? SKSpriteNode(color: GamePalette.asphalt1, size: sz).texture)
        }

        node.size = CGSize(width: tile, height: tile)
        return node
    }

    private static func paintRectSurface(
        on layer: SKNode,
        surface: TerrainSurface,
        cols: ClosedRange<Int>,
        rows: ClosedRange<Int>,
        tile: CGFloat
    ) {
        for row in rows {
            for col in cols {
                let node = makeParkGroundTile(surface: surface, col: col, row: row, tile: tile)
                node.anchorPoint = .zero
                node.position = CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)
                layer.addChild(node)
            }
        }
    }

    private static func paintEllipseSurface(
        on layer: SKNode,
        surface: TerrainSurface,
        centerCol: Int,
        centerRow: Int,
        radiusX: Int,
        radiusY: Int,
        tile: CGFloat
    ) {
        guard radiusX > 0, radiusY > 0 else { return }
        for row in (centerRow - radiusY)...(centerRow + radiusY) {
            for col in (centerCol - radiusX)...(centerCol + radiusX) {
                let dx = CGFloat(col - centerCol) / CGFloat(radiusX)
                let dy = CGFloat(row - centerRow) / CGFloat(radiusY)
                if dx * dx + dy * dy <= 1.0 {
                    let node = makeParkGroundTile(surface: surface, col: col, row: row, tile: tile)
                    node.anchorPoint = .zero
                    node.position = CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)
                    layer.addChild(node)
                }
            }
        }
    }

    private static func addDecor(_ layer: SKNode, spots: [(String, Int, Int, Bool)], tile: CGFloat) {
        for (glyph, c, r, blocks) in spots {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(glyph, size: 96))
            n.size = CGSize(width: tile * 1.1, height: tile * 1.1)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            n.zPosition = GameConstants.ZPos.decor
            if blocks || SpriteFactory.glyphBlocks(glyph) {
                SpriteFactory.applyBlockingBody(to: n, glyph: glyph, tile: tile)
                if n.physicsBody == nil {
                    let b = SKPhysicsBody(circleOfRadius: tile * 0.38)
                    b.isDynamic = false
                    b.categoryBitMask = GameConstants.Category.wall
                    n.physicsBody = b
                }
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

    private static func paintDirtRibbon(
        on layer: SKNode,
        path: [(Int, Int)],
        radius: Int,
        tile: CGFloat
    ) {
        for (step, point) in path.enumerated() {
            for dx in -radius...radius {
                for dy in -radius...radius {
                    let distance = abs(dx) + abs(dy)
                    guard distance <= radius + (step % 2 == 0 ? 0 : 1) else { continue }
                    let col = point.0 + dx
                    let row = point.1 + dy
                    let variant = abs(col * 19 + row * 11 + step * 7)
                    let texture = ImportedArt.sproutPathTexture(variant: variant)
                    let node = texture.map { SKSpriteNode(texture: $0) }
                        ?? SKSpriteNode(color: GamePalette.dirtD1, size: CGSize(width: tile, height: tile))
                    node.anchorPoint = .zero
                    node.size = CGSize(width: tile, height: tile)
                    node.position = CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)
                    layer.addChild(node)
                }
            }
        }
    }

    private static func addCliffFace(
        on layer: SKNode,
        startCol: Int,
        startRow: Int,
        length: Int,
        horizontal: Bool,
        tile: CGFloat
    ) {
        for i in 0..<length {
            let col = horizontal ? startCol + i : startCol
            let row = horizontal ? startRow : startRow + i
            let texCol = horizontal ? (i % 2 == 0 ? 0 : 1) : 3
            let texRow = horizontal ? 1 : 2
            let node = ImportedArt.sproutHillTexture(col: texCol, row: texRow)
                .map { SKSpriteNode(texture: $0) }
                ?? SKSpriteNode(color: GamePalette.brickWall, size: CGSize(width: tile, height: tile))
            node.anchorPoint = .zero
            node.size = CGSize(width: tile, height: tile)
            node.position = CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)
            layer.addChild(node)
        }
    }

    private static func paintFenceRun(
        on layer: SKNode,
        startCol: Int,
        row: Int,
        length: Int,
        tile: CGFloat
    ) {
        for i in 0..<length {
            let col = startCol + i
            let texCol = i == 0 ? 0 : (i == length - 1 ? 3 : 1)
            let tex = ImportedArt.sproutFenceTexture(col: texCol, row: 2)
            let node = tex.map { SKSpriteNode(texture: $0) }
                ?? SKSpriteNode(color: GamePalette.woodSiding, size: CGSize(width: tile, height: tile))
            node.anchorPoint = .zero
            node.size = CGSize(width: tile, height: tile)
            node.position = CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)
            layer.addChild(node)
        }
    }

    private static func paintBridgePatch(
        on layer: SKNode,
        originCol: Int,
        originRow: Int,
        tile: CGFloat
    ) {
        for r in 0..<2 {
            for c in 0..<3 {
                guard let tex = ImportedArt.sproutBridgeTexture(col: c, row: r) else { continue }
                let node = SKSpriteNode(texture: tex)
                node.anchorPoint = .zero
                node.size = CGSize(width: tile, height: tile)
                node.position = CGPoint(x: CGFloat(originCol + c) * tile, y: CGFloat(originRow + r) * tile)
                layer.addChild(node)
            }
        }
    }

    private static func sprinkleGrassTufts(
        on layer: SKNode,
        points: [(Int, Int)],
        tile: CGFloat
    ) {
        for (col, row) in points {
            let tuft = SKSpriteNode(color: .clear, size: CGSize(width: tile, height: tile))
            tuft.anchorPoint = .zero
            tuft.position = CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)

            let bladeA = SKSpriteNode(color: GamePalette.grassG3Deep, size: CGSize(width: tile * 0.12, height: tile * 0.28))
            bladeA.anchorPoint = CGPoint(x: 0.5, y: 0)
            bladeA.position = CGPoint(x: tile * 0.34, y: tile * 0.30)
            tuft.addChild(bladeA)

            let bladeB = SKSpriteNode(color: GamePalette.grassG3, size: CGSize(width: tile * 0.10, height: tile * 0.22))
            bladeB.anchorPoint = CGPoint(x: 0.5, y: 0)
            bladeB.position = CGPoint(x: tile * 0.52, y: tile * 0.34)
            tuft.addChild(bladeB)

            let bladeC = SKSpriteNode(color: GamePalette.grassG4Worn, size: CGSize(width: tile * 0.08, height: tile * 0.18))
            bladeC.anchorPoint = CGPoint(x: 0.5, y: 0)
            bladeC.position = CGPoint(x: tile * 0.66, y: tile * 0.28)
            tuft.addChild(bladeC)

            layer.addChild(tuft)
        }
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

        for r in 0..<16 {
            for c in 0..<16 {
                let variant = abs(((originCol + c) &* 47) ^ ((originRow + r) &* 83))
                let texture = ImportedArt.interiorFloorTexture(variant: variant)
                let t = SKSpriteNode(texture: texture,
                                     color: .clear,
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
            let texture = ImportedArt.interiorWallTexture(variant: abs((dc &* 13) ^ (dr &* 29))) ?? SpriteFactory.emojiTexture("🧱", size: 96)
            let n = SKSpriteNode(texture: texture)
            n.size = CGSize(width: tile, height: tile)
            n.position = pos(dc, dr)
            n.zPosition = GameConstants.ZPos.decor
            let b = SKPhysicsBody(rectangleOf: CGSize(width: tile - 4, height: tile - 4))
            b.isDynamic = false
            b.categoryBitMask = GameConstants.Category.wall
            n.physicsBody = b
            roomLayer.addChild(n)
        }

        let windowCoords = [(3, 15), (4, 15), (11, 15), (12, 15)]
        for (dc, dr) in windowCoords {
            guard let tex = ImportedArt.interiorFeatureTexture(kind: "window") else { continue }
            let n = SKSpriteNode(texture: tex, size: CGSize(width: tile, height: tile))
            n.position = pos(dc, dr)
            n.zPosition = GameConstants.ZPos.decor + 0.1
            roomLayer.addChild(n)
        }

        let counterCoords = [(10, 12), (11, 12), (12, 12)]
        for (index, coords) in counterCoords.enumerated() {
            guard let tex = ImportedArt.interiorFeatureTexture(kind: "counter", variant: index) else { continue }
            let n = SKSpriteNode(texture: tex, size: CGSize(width: tile, height: tile))
            n.position = pos(coords.0, coords.1)
            n.zPosition = GameConstants.ZPos.decor + 0.1
            roomLayer.addChild(n)
        }

        let shelfCoords = [(2, 11), (2, 8), (13, 11), (13, 8)]
        for (index, coords) in shelfCoords.enumerated() {
            guard let tex = ImportedArt.interiorFeatureTexture(kind: "shelf", variant: index) else { continue }
            let n = SKSpriteNode(texture: tex, size: CGSize(width: tile, height: tile))
            n.position = pos(coords.0, coords.1)
            n.zPosition = GameConstants.ZPos.decor + 0.1
            roomLayer.addChild(n)
        }

        let hearthCoords = [(4, 12), (5, 12)]
        for (index, coords) in hearthCoords.enumerated() {
            guard let tex = ImportedArt.interiorFeatureTexture(kind: "hearth", variant: index + 2) else { continue }
            let n = SKSpriteNode(texture: tex, size: CGSize(width: tile, height: tile))
            n.position = pos(coords.0, coords.1)
            n.zPosition = GameConstants.ZPos.decor + 0.1
            roomLayer.addChild(n)
        }

        let stairCoords = [(11, 3), (12, 3)]
        for (index, coords) in stairCoords.enumerated() {
            guard let tex = ImportedArt.interiorFeatureTexture(kind: "stairs", variant: index) else { continue }
            let n = SKSpriteNode(texture: tex, size: CGSize(width: tile, height: tile))
            n.position = pos(coords.0, coords.1)
            n.zPosition = GameConstants.ZPos.decor + 0.1
            roomLayer.addChild(n)
        }

        let plate = PressurePlateNode(); plate.position = pos(6, 4); root.addChild(plate)
        let gate = GateNode(); gate.position = pos(6, 8); root.addChild(gate)
        let chest = TreasureChestNode(); chest.position = pos(6, 12); root.addChild(chest)
        let boulder = PushableRockNode(); boulder.position = pos(6, 2); root.addChild(boulder)

        return (plate, gate, chest, boulder)
    }
}
