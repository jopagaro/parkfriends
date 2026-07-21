import SpriteKit

// Generated from MAP_SPEC.md.
// - buildCenter() → §4 (scene `park`): pond, fountain plaza, statue plaza, oak.
// - buildNorth()  → §3 (scene `suburb_north`): lab, row houses, road, creek.
enum ParkWorld {

    struct BuildResult {
        let root: SKNode
        let npcSpawns: [CGPoint]
        let itemSpawns: [CGPoint]
        let fixedItems: [(ItemKind, CGPoint)]
        let enemySpawns: [(EnemyKind, CGPoint)]
        let playerSpawn: CGPoint
        let benchPositions: [CGPoint]
        let zoneExitNodes: [ZoneExitNode]
        let pressurePlate: PressurePlateNode?
        let gate: GateNode?
        let chest: TreasureChestNode?
        let boulder: PushableRockNode?
    }

    // MARK: - Park (Zone 1B) — MAP_SPEC §4

    static func buildCenter() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let painter = ScenePainter(
            root: root,
            cols: GameConstants.parkCenterCols,
            rows: GameConstants.parkCenterRows
        )

        // §4.2 — L0 bright grass everywhere, with darker patches under the
        // tree clusters so the fill doesn't read as one flat sheet.
        painter.fillGrass(rect: SpecRect(0, 0, painter.cols, painter.rows))
        for shade in [
            SpecRect(11, 3, 5, 5), SpecRect(58, 5, 6, 5), SpecRect(3, 44, 6, 9),
            SpecRect(79, 9, 4, 4), SpecRect(26, 55, 6, 6)
        ] {
            painter.fillDarkGrass(rect: shade)
        }

        // §4.2/§4.8 — Water: pond + creek painted as ONE autotiled blob so
        // shores wrap every edge and the creek merges seamlessly into the pond.
        let pondRect = SpecRect(8, 14, 22, 16)
        let creekArm = SpecRect(49, 0, 2, 13)
        let creekSteps = [
            SpecRect(46, 12, 5, 2),
            SpecRect(42, 13, 5, 2),
            SpecRect(38, 14, 5, 2),
            SpecRect(34, 15, 5, 2),
            SpecRect(30, 16, 5, 2),
            SpecRect(27, 17, 3, 2)   // merges into pond edge at x=28..29
        ]
        let waterRects = [pondRect, creekArm] + creekSteps
        painter.autotile(painter.tiles(waterRects),
                         z: PaintLayer.ground.z + 0.1,
                         tile: ImportedArt.pondBlobTile)

        // §4.10 — Fountain plaza, octagonal: 14×14 stone with 4 corner 2×2
        // blocks cut out. Stone-path autotile gives it a grass border.
        let plazaRect = SpecRect(38, 18, 14, 14)
        var plazaTiles = painter.tiles([plazaRect])
        plazaTiles.subtract(painter.tiles([
            SpecRect(38, 18, 2, 2), SpecRect(50, 18, 2, 2),
            SpecRect(38, 30, 2, 2), SpecRect(50, 30, 2, 2)
        ]))
        painter.autotile(plazaTiles,
                         z: PaintLayer.ground.z + 0.2,
                         tile: ImportedArt.parkStoneBlobTile)

        // §4.1 — Statue plaza.
        let statuePlazaRect = SpecRect(66, 38, 10, 10)
        painter.autotile(painter.tiles([statuePlazaRect]),
                         z: PaintLayer.ground.z + 0.2,
                         tile: ImportedArt.parkStoneBlobTile)

        // §4.3 — Dirt path network, autotiled so ends and corners are rounded.
        // Water and plazas are excluded; the bridge covers the creek crossing.
        let pathExclusions = [plazaRect, statuePlazaRect] + waterRects
        let pathTiles = painter.tiles([
            SpecRect(44, 0, 4, 64),
            SpecRect(28, 18, 20, 2),
            SpecRect(47, 38, 22, 2),
            SpecRect(8, 50, 40, 2)
        ], excluding: pathExclusions)
        painter.autotile(pathTiles,
                         z: PaintLayer.ground.z + 0.3,
                         tile: ImportedArt.parkPathBlobTile)

        // §4.8 — Wooden bridge where the main N-S path crosses the creek
        // diagonal: the path funnels onto a 2-wide plank walkway. Collision
        // below leaves x=45..46 open and rails off the water beside it.
        painter.placeSprite(SpecRect(45, 12, 2, 3),
                            texture: ImportedArt.sproutBridgeVertical(),
                            layer: .props)
        painter.addBlockingRect(SpecRect(44, 12, 1, 3))
        painter.addBlockingRect(SpecRect(47, 12, 1, 3))

        // §4.4 / §4.5 — Trees with collision.
        painter.placeTree(SpecRect(4, 46, 4, 6),  texture: ImportedArt.parkLargeTree())     // oak landmark
        painter.placeTree(SpecRect(12, 4, 3, 3),  texture: ImportedArt.parkLargeTree())
        painter.placeTree(SpecRect(60, 6, 3, 3),  texture: ImportedArt.parkLargeTree())
        painter.placeTree(SpecRect(80, 10, 2, 2), texture: ImportedArt.parkMediumTree())
        painter.placeTree(SpecRect(34, 32, 2, 3), texture: ImportedArt.parkTallConifer())
        painter.placeTree(SpecRect(56, 50, 2, 2), texture: ImportedArt.parkMediumTree())
        painter.placeTree(SpecRect(82, 52, 2, 2), texture: ImportedArt.parkWideTree())
        painter.placeTree(SpecRect(18, 38, 1, 2), texture: ImportedArt.parkSmallConifer())
        painter.placeTree(SpecRect(28, 56, 2, 2), texture: ImportedArt.parkMediumTree())

        // Density pass: 16 more medium/small trees scattered in empty grass quadrants.
        // (Avoiding paths, plaza, pond, and the perimeter where the tree-wall sits.)
        let extraTrees: [(Int, Int, TreeKind)] = [
            (16, 4, .medium), (24, 6, .small), (40, 4, .medium), (52, 4, .conifer),
            (74, 4, .wide),   (90, 4, .medium), (96, 14, .conifer),
            (4, 14, .medium), (4, 28, .medium), (4, 38, .small),
            (88, 26, .medium), (94, 38, .wide), (90, 50, .medium),
            (60, 56, .medium), (72, 56, .wide), (40, 60, .conifer)
        ]
        for (xT, yT, kind) in extraTrees {
            painter.placeTree(SpecRect(xT, yT, kind.w, kind.h), texture: kind.texture)
        }

        // §4.1 — Tree-wall border: dense hedge autotile, 2 thick, with gaps at
        // the N + S path transitions (x=44..47).
        let cols = painter.cols, rows = painter.rows
        var hedgeTiles = painter.tiles([
            SpecRect(0, 0, cols, 2), SpecRect(0, rows - 2, cols, 2),
            SpecRect(0, 2, 2, rows - 4), SpecRect(cols - 2, 2, 2, rows - 4)
        ])
        hedgeTiles.subtract(painter.tiles([
            SpecRect(44, 0, 4, 2), SpecRect(44, rows - 2, 4, 2)
        ]))
        painter.autotile(hedgeTiles,
                         z: PaintLayer.props.z,
                         tile: ImportedArt.parkHedgeBlobTile)
        for wall in [
            SpecRect(0, 0, 44, 2), SpecRect(48, 0, cols - 48, 2),
            SpecRect(0, rows - 2, 44, 2), SpecRect(48, rows - 2, cols - 48, 2),
            SpecRect(0, 2, 2, rows - 4), SpecRect(cols - 2, 2, 2, rows - 4)
        ] {
            painter.addBlockingRect(wall)
        }

        // §4.4 — Fountain: round pond blob basin + animated water shimmer.
        painter.placeSprite(SpecRect(43, 23, 4, 4),
                            texture: ImportedArt.pondBlobTile(col: 3, rowFromTop: 0),
                            layer: .props)
        painter.placeAnimated(SpecRect(44, 24, 2, 2),
                              frames: ImportedArt.parkWaterSurfaceFrames(),
                              timePerFrame: 0.25)

        // §4.4 — Statue: stone-block pedestal with a carved-rock figure.
        painter.placeSprite(SpecRect(70, 44, 2, 1),
                            texture: ImportedArt.parkStoneBlockTile(),
                            layer: .props)
        painter.placeRock(SpecRect(70, 42, 2, 2), variant: 6)

        // §4.9 — Pier: horizontal plank walkway extending east into the pond.
        painter.placeSprite(SpecRect(26, 19, 3, 1),
                            texture: ImportedArt.sproutBridgeHorizontal(),
                            layer: .props)

        // §4.9 — Shore reeds.
        for (xT, yT) in [(9, 22), (11, 28), (26, 26), (14, 18), (22, 28)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.parkGrassBlade(),
                                layer: .decor)
        }

        // §4.6/§4.9 — Pond shore rocks (textured).
        painter.placeRock(SpecRect(8, 16, 1, 1),  variant: 1)
        painter.placeRock(SpecRect(28, 14, 1, 1), variant: 4)
        painter.placeRock(SpecRect(14, 30, 1, 1), variant: 2)
        // Density pass: rocks scattered around the park.
        for (xT, yT, v) in [
            (6, 8, 1),  (16, 12, 2), (4, 22, 4),  (32, 38, 1), (38, 56, 2),
            (54, 8, 4), (60, 22, 1), (78, 32, 2), (88, 42, 4), (96, 28, 1),
            (8, 56, 2), (24, 60, 4), (60, 62, 1), (76, 58, 2), (90, 62, 4)
        ] {
            painter.placeRock(SpecRect(xT, yT, 1, 1), variant: v)
        }

        // §4.10 — Fountain plaza furnishings: corner lamps + chair benches.
        let lampTex = ImportedArt.lampTexture(city: false)
        for (xT, yT) in [(40, 19), (49, 19), (40, 28), (49, 28)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 2), texture: lampTex, layer: .props)
        }
        let chairTex = ImportedArt.parkFurnitureTile(col: 6, rowFromTop: 2)
        for (xT, yT) in [
            (44, 20), (45, 20),      // bench facing fountain from north
            (44, 30), (45, 30),      // south
            (50, 24), (38, 24)       // east / west singles
        ] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1), texture: chairTex, layer: .props)
        }

        // §4.10/§4.11 — Plaza flower beds (textured).
        let flowerRed    = ImportedArt.parkBiomSprite(col: 1, row: 1)
        let flowerYellow = ImportedArt.parkBiomSprite(col: 2, row: 1)
        let flowerBlue   = ImportedArt.parkBiomSprite(col: 3, row: 1)
        for (xT, yT, t) in [
            (41, 21, flowerRed), (48, 21, flowerYellow),
            (41, 29, flowerBlue), (48, 29, flowerRed),
            (69, 44, flowerRed), (71, 44, flowerYellow),
            (69, 41, flowerBlue), (71, 41, flowerRed),
            // §4.6 — freestanding flower clusters
            (50, 12, flowerRed), (52, 12, flowerYellow), (36, 50, flowerBlue)
        ] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1), texture: t, layer: .decor)
        }
        // §4.11 — Bench facing the statue.
        painter.placeSprite(SpecRect(70, 47, 1, 1), texture: chairTex, layer: .props)
        painter.placeSprite(SpecRect(71, 47, 1, 1), texture: chairTex, layer: .props)

        // §4.12 — Bushes scattered. Density pass: ~30 sprinkles.
        let bushTextures = [
            ImportedArt.parkBiomSprite(col: 0, row: 3),
            ImportedArt.parkBiomSprite(col: 1, row: 3),
            ImportedArt.parkBiomSprite(col: 2, row: 3),
            ImportedArt.parkBiomSprite(col: 4, row: 3)
        ]
        let bushSpots: [(Int, Int)] = [
            (6, 8), (18, 6), (56, 8), (88, 14), (12, 54), (78, 56), (32, 60),
            (22, 12), (28, 22), (46, 56), (64, 12), (74, 28), (84, 6), (94, 22),
            (6, 32), (4, 50), (16, 60), (40, 60), (68, 60), (88, 56), (96, 8),
            (54, 24), (60, 32), (78, 14), (84, 50), (94, 50), (32, 48), (52, 60),
            (22, 4), (76, 4), (10, 40), (96, 50)
        ]
        for (i, spot) in bushSpots.enumerated() {
            let tex = bushTextures[i % bushTextures.count]
            painter.placeSprite(SpecRect(spot.0, spot.1, 1, 1), texture: tex, layer: .decor)
        }

        // §4.6 — Generic park benches (returned in benchPositions for the engine).
        let benchSpots = [(40, 32), (20, 30), (66, 50)]
        let benchPositions: [CGPoint] = benchSpots.map {
            painter.center(SpecRect($0.0, $0.1, 1, 1))
        }
        for (xT, yT) in benchSpots {
            painter.placeSprite(SpecRect(xT, yT, 1, 1), texture: chairTex, layer: .props)
            painter.placeSprite(SpecRect(xT + 1, yT, 1, 1), texture: chairTex, layer: .props)
        }

        // Pond collision: one big rectangular wall covering the pond bounds.
        painter.addBlockingRect(pondRect)
        // Creek collision — everything except the bridge band (x=44..47,
        // y=12..14) so the main path stays crossable.
        painter.addBlockingRect(SpecRect(49, 0, 2, 12))     // north arm
        painter.addBlockingRect(SpecRect(48, 12, 3, 2))     // step 1, east of bridge
        painter.addBlockingRect(SpecRect(42, 13, 2, 2))     // step 2, west of bridge
        painter.addBlockingRect(SpecRect(38, 14, 5, 2))
        painter.addBlockingRect(SpecRect(34, 15, 5, 2))
        painter.addBlockingRect(SpecRect(30, 16, 5, 2))
        painter.addBlockingRect(SpecRect(27, 17, 3, 2))

        // §4.7 — Ambient creatures (animated decor; not battle actors).
        painter.placeAnimated(SpecRect(58, 30, 1, 1),
                              frames: ImportedArt.parkChickenFrames(),
                              timePerFrame: 0.18)
        painter.placeAnimated(SpecRect(59, 31, 1, 1),
                              frames: ImportedArt.parkChicksFrames(),
                              timePerFrame: 0.16)
        painter.placeSprite(SpecRect(60, 29, 1, 1),
                            texture: ImportedArt.parkEggNest(stage: 1),
                            layer: .decor)
        painter.placeAnimated(SpecRect(5, 53, 2, 1),
                              frames: ImportedArt.parkSquirrelIdleFrames(),
                              timePerFrame: 0.14)

        // Scene-boundary walls so the player can't walk off the edge.
        painter.addSceneBoundary()

        // Zone exits (matches §2 transition coords).
        var exits: [ZoneExitNode] = []
        let nExit = ZoneExitNode(
            destination: .parkNorth,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "Suburb"
        )
        nExit.position = painter.center(SpecRect(44, 0, 4, 1))
        root.addChild(nExit)
        exits.append(nExit)

        let sExit = ZoneExitNode(
            destination: .citySouth,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "City"
        )
        sExit.position = painter.center(SpecRect(44, 63, 4, 1))
        root.addChild(sExit)
        exits.append(sExit)

        let playerSpawn = painter.center(SpecRect(46, 2, 1, 1))

        // Ambient NPC rotation points (grass / plaza edges, off the water).
        let npcSpawns: [CGPoint] = [
            SpecRect(45, 35, 1, 1), SpecRect(24, 36, 1, 1),
            SpecRect(60, 44, 1, 1), SpecRect(76, 24, 1, 1),
            SpecRect(36, 8, 1, 1)
        ].map(painter.center)

        // Consumable pickups from ItemKind.parkSpawnPool.
        let itemSpawns: [CGPoint] = [
            SpecRect(14, 8, 1, 1), SpecRect(70, 14, 1, 1),
            SpecRect(20, 44, 1, 1), SpecRect(52, 56, 1, 1),
            SpecRect(86, 36, 1, 1), SpecRect(64, 20, 1, 1)
        ].map(painter.center)

        // Zone 1 roster: pigeons own the plaza, goose patrols the pond,
        // raccoon works the south path, wasp in the NE meadow.
        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.pigeon,  painter.center(SpecRect(56, 22, 1, 1))),
            (.pigeon,  painter.center(SpecRect(58, 26, 1, 1))),
            (.goose,   painter.center(SpecRect(18, 34, 1, 1))),
            (.raccoon, painter.center(SpecRect(36, 54, 1, 1))),
            (.wasp,    painter.center(SpecRect(78, 8, 1, 1)))
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawns,
            fixedItems: [],
            enemySpawns: enemySpawns,
            playerSpawn: playerSpawn,
            benchPositions: benchPositions,
            zoneExitNodes: exits,
            pressurePlate: nil, gate: nil, chest: nil, boulder: nil
        )
    }

    // MARK: - Suburb (Zone 1A) — MAP_SPEC §3, adapted to the 105×50 canvas

    static func buildNorth() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let painter = ScenePainter(
            root: root,
            cols: GameConstants.parkNorthCols,
            rows: GameConstants.parkNorthRows
        )
        let cols = painter.cols, rows = painter.rows

        // §3.2 — L0 grass everywhere.
        painter.fillGrass(rect: SpecRect(0, 0, cols, rows))

        // §3.2 — Road band across the full width, sidewalk curbs above/below.
        let roadRect = SpecRect(0, 21, cols, 5)
        for yT in roadRect.y..<(roadRect.y + roadRect.h) {
            for xT in 0..<cols {
                painter.place1x1(at: xT, yT,
                                 texture: ImportedArt.suburbPavementTile(col: xT, rowFromTop: yT),
                                 z: PaintLayer.ground.z + 0.2)
            }
        }
        for yT in [20, 26] {
            for xT in 0..<cols {
                painter.place1x1(at: xT, yT,
                                 texture: ImportedArt.parkStoneTile(variant: (xT + yT) % 3),
                                 z: PaintLayer.ground.z + 0.2)
            }
        }

        // §3.2 — Dirt path from the road down to the park gap (x=44..47).
        painter.autotile(painter.tiles([SpecRect(44, 27, 4, 23)]),
                         z: PaintLayer.ground.z + 0.3,
                         tile: ImportedArt.parkPathBlobTile)

        // §3.9 — Creek: spring at the east tree line, diagonal SW through the
        // lower lawn, then straight south to the park scene (x=49..50 there).
        // Small 3-tile steps keep the diagonal smooth instead of staircased.
        var creekRects: [SpecRect] = (0..<17).map { i in
            SpecRect(97 - 3 * i, 28 + i, 5, 2)
        }
        creekRects.append(SpecRect(49, 44, 2, 6))
        painter.autotile(painter.tiles(creekRects),
                         z: PaintLayer.ground.z + 0.1,
                         tile: ImportedArt.pondBlobTile)
        for r in creekRects { painter.addBlockingRect(r) }

        // §3.12 — Secret-lab plot (top-left): fenced yard, lab house, trees,
        // stone driveway to the road with a gate gap.
        fenceRing(painter, SpecRect(3, 2, 17, 13), gateXs: [10, 11])
        painter.placeSprite(SpecRect(7, 4, 7, 5),
                            texture: ImportedArt.generatedHouse(variant: "dark_purple"),
                            layer: .props)
        painter.addBlockingRect(SpecRect(7, 4, 7, 5))
        painter.placeTree(SpecRect(4, 3, 2, 2),  texture: ImportedArt.parkMediumTree())
        painter.placeTree(SpecRect(16, 3, 2, 2), texture: ImportedArt.parkMediumTree())
        painter.autotile(painter.tiles([SpecRect(10, 9, 2, 12)]),
                         z: PaintLayer.ground.z + 0.25,
                         tile: ImportedArt.parkStoneBlobTile)

        // §3.3 — Hedge separator between lab plot and the main suburb row.
        painter.autotile(painter.tiles([SpecRect(21, 2, 1, 13)]),
                         z: PaintLayer.props.z,
                         tile: ImportedArt.parkHedgeBlobTile)
        painter.addBlockingRect(SpecRect(21, 2, 1, 13))

        // §3.4/§3.5/§3.6/§3.11 — Six row-houses with fenced front yards,
        // yard trees, flowers, and driveways down to the north sidewalk.
        let topRow: [(Int, String)] = [
            (24, "blue"), (37, "brown"), (50, "green"),
            (63, "red_brown"), (76, "dark_red"), (89, "charcoal")
        ]
        for (hx, roof) in topRow {
            painter.placeSprite(SpecRect(hx, 6, 7, 5),
                                texture: ImportedArt.generatedHouse(variant: roof), layer: .props)
            painter.addBlockingRect(SpecRect(hx, 6, 7, 5))
            fenceRing(painter, SpecRect(hx - 1, 11, 9, 5), gateXs: [hx + 3, hx + 4])
            painter.placeTree(SpecRect(hx, 4, 2, 2),     texture: ImportedArt.parkMediumTree())
            painter.placeTree(SpecRect(hx + 5, 4, 2, 2), texture: ImportedArt.parkMediumTree())
            for (fx, tex) in [(hx + 1, ImportedArt.parkBiomSprite(col: 1, row: 1)),
                              (hx + 6, ImportedArt.parkBiomSprite(col: 3, row: 1))] {
                painter.placeSprite(SpecRect(fx, 13, 1, 1), texture: tex, layer: .decor)
            }
            painter.autotile(painter.tiles([SpecRect(hx + 3, 16, 2, 4)]),
                             z: PaintLayer.ground.z + 0.25,
                             tile: ImportedArt.parkStoneBlobTile)
        }

        // §3.4/§3.15 — Lower suburb: two houses + a small cottage.
        for (hx, roof) in [(8, "brown"), (22, "tan")] {
            painter.placeSprite(SpecRect(hx, 30, 7, 5),
                                texture: ImportedArt.generatedHouse(variant: roof), layer: .props)
            painter.addBlockingRect(SpecRect(hx, 30, 7, 5))
            fenceRing(painter, SpecRect(hx - 1, 35, 9, 5), gateXs: [hx + 3, hx + 4])
            painter.autotile(painter.tiles([SpecRect(hx + 3, 27, 2, 3)]),
                             z: PaintLayer.ground.z + 0.25,
                             tile: ImportedArt.parkStoneBlobTile)
        }
        painter.placeSprite(SpecRect(4, 42, 5, 4),
                            texture: ImportedArt.generatedHouse(variant: "tan"), layer: .props)
        painter.addBlockingRect(SpecRect(4, 42, 5, 4))

        // Lawn dressing: scattered trees, bushes, and a bench by the path.
        painter.placeTree(SpecRect(34, 40, 3, 3), texture: ImportedArt.parkLargeTree())
        painter.placeTree(SpecRect(70, 42, 2, 2), texture: ImportedArt.parkMediumTree())
        painter.placeTree(SpecRect(88, 40, 2, 3), texture: ImportedArt.parkTallConifer())
        painter.placeTree(SpecRect(58, 44, 2, 2), texture: ImportedArt.parkWideTree())
        for (bx, by) in [(30, 36), (55, 42), (78, 38), (16, 47), (68, 46)] {
            painter.placeSprite(SpecRect(bx, by, 1, 1),
                                texture: ImportedArt.parkBiomSprite(col: 6, row: 4),
                                layer: .decor)
        }
        let chairTex = ImportedArt.parkFurnitureTile(col: 6, rowFromTop: 2)
        painter.placeSprite(SpecRect(52, 44, 1, 1), texture: chairTex, layer: .props)
        painter.placeSprite(SpecRect(53, 44, 1, 1), texture: chairTex, layer: .props)
        let benchPositions = [painter.center(SpecRect(52, 45, 1, 1))]

        // §3.3 — Tree-wall hedge border, 2 thick, gap at the park path (S).
        var hedgeTiles = painter.tiles([
            SpecRect(0, 0, cols, 2), SpecRect(0, rows - 2, cols, 2),
            SpecRect(0, 2, 2, rows - 4), SpecRect(cols - 2, 2, 2, rows - 4)
        ])
        hedgeTiles.subtract(painter.tiles([SpecRect(44, rows - 2, 4, 2)]))
        painter.autotile(hedgeTiles,
                         z: PaintLayer.props.z,
                         tile: ImportedArt.parkHedgeBlobTile)
        for wall in [
            SpecRect(0, 0, cols, 2),
            SpecRect(0, rows - 2, 44, 2), SpecRect(48, rows - 2, cols - 48, 2),
            SpecRect(0, 2, 2, rows - 4), SpecRect(cols - 2, 2, 2, rows - 4)
        ] {
            painter.addBlockingRect(wall)
        }
        painter.addSceneBoundary()

        // Zone exit: south path gap back into the park.
        let sExit = ZoneExitNode(
            destination: .parkCenter,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "Park"
        )
        sExit.position = painter.center(SpecRect(44, rows - 1, 4, 1))
        root.addChild(sExit)

        let playerSpawn = painter.center(SpecRect(46, 46, 1, 1))

        let npcSpawns: [CGPoint] = [
            SpecRect(30, 18, 1, 1), SpecRect(70, 18, 1, 1),
            SpecRect(40, 33, 1, 1), SpecRect(80, 44, 1, 1)
        ].map(painter.center)

        let itemSpawns: [CGPoint] = [
            SpecRect(12, 18, 1, 1), SpecRect(58, 18, 1, 1),
            SpecRect(26, 44, 1, 1), SpecRect(92, 46, 1, 1)
        ].map(painter.center)

        // Suburban threats: organized pigeons and one profoundly
        // disappointed adult.
        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.pigeon,     painter.center(SpecRect(56, 28, 1, 1))),
            (.pigeon,     painter.center(SpecRect(33, 18, 1, 1))),
            (.sternAdult, painter.center(SpecRect(75, 27, 1, 1)))
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawns,
            fixedItems: [],
            enemySpawns: enemySpawns,
            playerSpawn: playerSpawn,
            benchPositions: benchPositions,
            zoneExitNodes: [sExit],
            pressurePlate: nil, gate: nil, chest: nil, boulder: nil
        )
    }

    /// Paints a 1-thick fence ring with gate gaps on the bottom edge, and
    /// adds matching collision segments.
    private static func fenceRing(_ painter: ScenePainter, _ rect: SpecRect, gateXs: [Int]) {
        let x2 = rect.x + rect.w - 1, y2 = rect.y + rect.h - 1
        var ring = painter.tiles([
            SpecRect(rect.x, rect.y, rect.w, 1), SpecRect(rect.x, y2, rect.w, 1),
            SpecRect(rect.x, rect.y, 1, rect.h), SpecRect(x2, rect.y, 1, rect.h)
        ])
        for gx in gateXs { ring.remove(TileXY(x: gx, y: y2)) }
        painter.autotile(ring, z: PaintLayer.decor.z + 0.5,
                         tile: ImportedArt.suburbFenceBlobTile)
        let gateMin = gateXs.min() ?? x2 + 1
        let gateMax = gateXs.max() ?? x2 + 1
        painter.addBlockingRect(SpecRect(rect.x, rect.y, rect.w, 1))
        painter.addBlockingRect(SpecRect(rect.x, rect.y, 1, rect.h))
        painter.addBlockingRect(SpecRect(x2, rect.y, 1, rect.h))
        if gateMin > rect.x + 1 {
            painter.addBlockingRect(SpecRect(rect.x, y2, gateMin - rect.x, 1))
        }
        if gateMax < x2 - 1 {
            painter.addBlockingRect(SpecRect(gateMax + 1, y2, x2 - gateMax, 1))
        }
    }
}

// MARK: - Spec helpers (private)

/// Rectangle in MAP_SPEC tile coords (origin top-left, y grows down).
private struct SpecRect {
    let x: Int, y: Int, w: Int, h: Int
    init(_ x: Int, _ y: Int, _ w: Int, _ h: Int) { self.x = x; self.y = y; self.w = w; self.h = h }

    func contains(tile xT: Int, _ yT: Int) -> Bool {
        xT >= x && xT < x + w && yT >= y && yT < y + h
    }
}

/// Single tile coordinate in MAP_SPEC space (for autotile sets).
private struct TileXY: Hashable {
    let x: Int
    let y: Int
}

private enum PaintLayer {
    case ground, decor, props
    var z: CGFloat {
        switch self {
        case .ground: return GameConstants.ZPos.ground
        case .decor:  return GameConstants.ZPos.ground + 1
        case .props:  return GameConstants.ZPos.decor
        }
    }
}

private enum TreeKind {
    case large, medium, wide, conifer, small
    var w: Int { self == .large ? 3 : (self == .small ? 1 : 2) }
    var h: Int { self == .large ? 3 : (self == .conifer ? 3 : (self == .small ? 2 : 2)) }
    var texture: SKTexture? {
        switch self {
        case .large:   return ImportedArt.parkLargeTree()
        case .medium:  return ImportedArt.parkMediumTree()
        case .wide:    return ImportedArt.parkWideTree()
        case .conifer: return ImportedArt.parkTallConifer()
        case .small:   return ImportedArt.parkSmallConifer()
        }
    }
}

/// Paints SKSpriteNodes onto a scene root using MAP_SPEC tile coords.
/// Handles spec→SpriteKit y-axis flip and tile→pixel scaling.
private final class ScenePainter {
    let root: SKNode
    let cols: Int
    let rows: Int
    private let tile: CGFloat = GameConstants.tileSize

    init(root: SKNode, cols: Int, rows: Int) {
        self.root = root
        self.cols = cols
        self.rows = rows
    }

    /// Pixel center of a SpecRect (top-left tile = (rect.x, rect.y)).
    func center(_ r: SpecRect) -> CGPoint {
        CGPoint(
            x: (CGFloat(r.x) + CGFloat(r.w) / 2) * tile,
            y: (CGFloat(rows) - CGFloat(r.y) - CGFloat(r.h) / 2) * tile
        )
    }

    func fillGrass(rect: SpecRect) {
        // Solid base in the tilesets' shared green, with a sparse sprout tile
        // every ~13th cell for texture without noise.
        let base = ImportedArt.parkGrassBaseTile()
        for yT in rect.y..<(rect.y + rect.h) {
            for xT in rect.x..<(rect.x + rect.w) {
                let sprinkle = (xT * 13 + yT * 7) % 17 == 3
                place1x1(at: xT, yT,
                         texture: sprinkle ? ImportedArt.darkGrassTile(variant: (xT + yT) % 3) : base,
                         z: PaintLayer.ground.z)
            }
        }
    }

    /// Darker grass patch (under tree clusters) with mixed sprout variants.
    func fillDarkGrass(rect: SpecRect) {
        for yT in rect.y..<(rect.y + rect.h) {
            for xT in rect.x..<(rect.x + rect.w) {
                place1x1(at: xT, yT, texture: ImportedArt.darkGrassTile(variant: (xT + yT) % 3),
                         z: PaintLayer.ground.z + 0.05)
            }
        }
    }

    /// Expands rects into a tile set (minus exclusions) for `autotile`.
    func tiles(_ rects: [SpecRect], excluding: [SpecRect] = []) -> Set<TileXY> {
        var out = Set<TileXY>()
        for r in rects {
            for yT in r.y..<(r.y + r.h) {
                for xT in r.x..<(r.x + r.w) {
                    if excluding.contains(where: { $0.contains(tile: xT, yT) }) { continue }
                    out.insert(TileXY(x: xT, y: yT))
                }
            }
        }
        return out
    }

    /// Paints a tile set with a 4×4 blob tileset (shared layout: 3×3 blob,
    /// capsules in row 0 / col 3, single blob at (3,0)). Tile choice is by
    /// N/S/E/W neighbors within the set — edges wrap every boundary.
    func autotile(_ tileSet: Set<TileXY>, z: CGFloat, tile texProvider: (Int, Int) -> SKTexture?) {
        for t in tileSet {
            let w = tileSet.contains(TileXY(x: t.x - 1, y: t.y))
            let e = tileSet.contains(TileXY(x: t.x + 1, y: t.y))
            let n = tileSet.contains(TileXY(x: t.x, y: t.y - 1))
            let s = tileSet.contains(TileXY(x: t.x, y: t.y + 1))
            let col: Int, rowFromTop: Int
            if !n && !s {
                rowFromTop = 0
                col = (w && e) ? 1 : (e ? 0 : (w ? 2 : 3))
            } else if !w && !e {
                col = 3
                rowFromTop = (n && s) ? 2 : (s ? 1 : 3)
            } else {
                col = (w && e) ? 1 : (e ? 0 : 2)
                rowFromTop = (n && s) ? 2 : (s ? 1 : 3)
            }
            place1x1(at: t.x, t.y, texture: texProvider(col, rowFromTop), z: z)
        }
    }

    func placeSprite(_ rect: SpecRect, texture: SKTexture?, layer: PaintLayer) {
        guard let texture else {
            placeholder(rect, label: "?", layer: layer); return
        }
        texture.filteringMode = .nearest
        let s = SKSpriteNode(
            texture: texture,
            size: CGSize(width: CGFloat(rect.w) * tile, height: CGFloat(rect.h) * tile)
        )
        s.position   = center(rect)
        s.zPosition  = layer.z
        root.addChild(s)
    }

    /// Looping frame animation (ambient creatures). No collision body.
    func placeAnimated(_ rect: SpecRect, frames: [SKTexture], timePerFrame: TimeInterval) {
        guard let first = frames.first else { return }
        for f in frames { f.filteringMode = .nearest }
        let s = SKSpriteNode(
            texture: first,
            size: CGSize(width: CGFloat(rect.w) * tile, height: CGFloat(rect.h) * tile)
        )
        s.position  = center(rect)
        s.zPosition = PaintLayer.props.z
        if frames.count > 1 {
            s.run(.repeatForever(.animate(with: frames, timePerFrame: timePerFrame)))
        }
        root.addChild(s)
    }

    /// Tree with a small circular collision body at its trunk.
    func placeTree(_ rect: SpecRect, texture: SKTexture?) {
        guard let texture else { return }
        texture.filteringMode = .nearest
        let s = SKSpriteNode(
            texture: texture,
            size: CGSize(width: CGFloat(rect.w) * tile, height: CGFloat(rect.h) * tile)
        )
        s.position  = center(rect)
        s.zPosition = PaintLayer.props.z
        let radius = max(CGFloat(min(rect.w, rect.h)) * tile * 0.30, tile * 0.30)
        let body = SKPhysicsBody(circleOfRadius: radius, center: CGPoint(x: 0, y: -CGFloat(rect.h) * tile * 0.25))
        body.isDynamic           = false
        body.categoryBitMask     = GameConstants.Category.wall
        body.collisionBitMask    = 0xFFFFFFFF
        body.contactTestBitMask  = 0
        s.physicsBody = body
        root.addChild(s)
    }

    func placeRock(_ rect: SpecRect, variant: Int) {
        let path = "textures.downloaded.sprites/world.park/pixel-art-gray-rock-with-grass-sprite-0\(variant).png"
        guard let tex = ImportedArt.fileTexture(relativePath: path) else { return }
        tex.filteringMode = .nearest
        let s = SKSpriteNode(texture: tex,
                             size: CGSize(width: CGFloat(rect.w) * tile, height: CGFloat(rect.h) * tile))
        s.position  = center(rect)
        s.zPosition = PaintLayer.props.z
        let body = SKPhysicsBody(circleOfRadius: tile * 0.30)
        body.isDynamic        = false
        body.categoryBitMask  = GameConstants.Category.wall
        body.collisionBitMask = 0xFFFFFFFF
        s.physicsBody = body
        root.addChild(s)
    }

    func placeholder(_ rect: SpecRect, label: String, layer: PaintLayer) {
        let s = SKShapeNode(rectOf: CGSize(width: CGFloat(rect.w) * tile, height: CGFloat(rect.h) * tile))
        s.fillColor   = SKColor.magenta.withAlphaComponent(0.85)
        s.strokeColor = .black
        s.lineWidth   = 1
        s.position    = center(rect)
        s.zPosition   = layer.z
        let lbl = SKLabelNode(text: label)
        lbl.fontSize  = 9
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        s.addChild(lbl)
        root.addChild(s)
    }

    /// Static rectangular collision body covering a SpecRect.
    func addBlockingRect(_ rect: SpecRect) {
        let node = SKNode()
        node.position = center(rect)
        let body = SKPhysicsBody(rectangleOf: CGSize(
            width: CGFloat(rect.w) * tile,
            height: CGFloat(rect.h) * tile
        ))
        body.isDynamic        = false
        body.categoryBitMask  = GameConstants.Category.wall
        body.collisionBitMask = 0xFFFFFFFF
        node.physicsBody = body
        root.addChild(node)
    }

    /// Four invisible walls along the scene perimeter so the player can't escape the world.
    func addSceneBoundary() {
        let w = CGFloat(cols) * tile
        let h = CGFloat(rows) * tile
        let thickness: CGFloat = tile
        let rects: [(CGPoint, CGSize)] = [
            (CGPoint(x: w / 2, y: h + thickness / 2),         CGSize(width: w, height: thickness)),  // north
            (CGPoint(x: w / 2, y: -thickness / 2),            CGSize(width: w, height: thickness)),  // south
            (CGPoint(x: -thickness / 2, y: h / 2),            CGSize(width: thickness, height: h)),  // west
            (CGPoint(x: w + thickness / 2, y: h / 2),         CGSize(width: thickness, height: h))   // east
        ]
        for (pos, size) in rects {
            let node = SKNode()
            node.position = pos
            let body = SKPhysicsBody(rectangleOf: size)
            body.isDynamic        = false
            body.categoryBitMask  = GameConstants.Category.wall
            body.collisionBitMask = 0xFFFFFFFF
            node.physicsBody = body
            root.addChild(node)
        }
    }

    func place1x1(at xT: Int, _ yT: Int, texture: SKTexture?, z: CGFloat) {
        guard let texture else { return }
        texture.filteringMode = .nearest
        let s = SKSpriteNode(texture: texture, size: CGSize(width: tile, height: tile))
        s.position  = CGPoint(
            x: (CGFloat(xT) + 0.5) * tile,
            y: (CGFloat(rows - yT) - 0.5) * tile
        )
        s.zPosition = z
        root.addChild(s)
    }
}
