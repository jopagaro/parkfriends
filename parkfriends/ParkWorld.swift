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

    // MARK: - Zone 1B — Park Center (south toward city)

    static func buildCenter() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let tile = GameConstants.tileSize
        let cols = GameConstants.parkCenterCols
        let rows = GameConstants.parkCenterRows
        let worldSize = GameConstants.parkCenterWorldSize

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
        let decorSpots: [(String, Int, Int, Bool)] = [
            ("🚧", 27, 3, true), ("🚧", 44, 3, true),
            ("🥀", 31, 4, false), ("🥀", 41, 4, false),
            ("🪧", 33, 2, false),
            ("⛲", 35, 26, true),
            ("🪑", 30, 24, false), ("🪑", 41, 24, false),
            ("🪑", 29, 28, false), ("🪑", 42, 28, false),
            ("🐦", 32, 27, false), ("🐦", 38, 25, false), ("🐦", 36, 29, false),
            ("🗑️", 34, 23, false), ("🗑️", 37, 29, false),
            ("🪨", 5, 18, true), ("🪨", 8, 20, true), ("🪨", 11, 16, true),
            ("🌳", 3, 15, true), ("🌳", 6, 14, true), ("🌳", 2, 12, true),
            ("🌳", 4, 12, true),
            ("🎤", 12, 15, false),
            ("🎾", 48, 9, false), ("🦴", 52, 8, false), ("🥣", 50, 11, false),
            ("🌳", 20, 16, true), ("🌳", 24, 20, true), ("🌳", 44, 18, true),
            ("🌳", 48, 22, true), ("🌲", 16, 28, true), ("🌲", 52, 28, true),
            ("🌳", 10, 5, true), ("🌳", 60, 5, true), ("🌳", 15, 8, true),
            ("🌳", 55, 8, true),
            ("🪑", 62, 20, false), ("🌸", 64, 18, false),
            ("🌻", 66, 22, false), ("🌳", 68, 16, true),
        ]
        addDecor(decorLayer, spots: decorSpots, tile: tile)
        root.addChild(decorLayer)

        // Park-style lamp posts along main paths
        let lampCoords: [(Int, Int)] = [
            (35, 22), (35, 16), (35, 12),   // central path
            (28, 26), (42, 26),              // fountain plaza
            (18, 20), (52, 20),              // mid-park
            (62, 20), (68, 16),              // east garden
        ]
        for (lc, lr) in lampCoords {
            let lamp = WorldSprites.makeLampPost(city: false)
            lamp.position = CGPoint(x: CGFloat(lc) * tile + tile / 2, y: CGFloat(lr) * tile)
            lamp.zPosition = GameConstants.ZPos.decor + 1
            decorLayer.addChild(lamp)
        }

        buildAmphitheater(root: root, originCol: 2, originRow: 14, tileW: 20, tileH: 16, tile: tile)

        let southExit = ZoneExitNode(
            destination: .citySouth,
            triggerSize: CGSize(width: worldSize.width, height: tile),
            arrowCount: 7, edgeLabel: "→ City South")
        southExit.position = CGPoint(x: worldSize.width / 2, y: tile / 2)
        root.addChild(southExit)

        let northExit = ZoneExitNode(
            destination: .parkNorth,
            triggerSize: CGSize(width: worldSize.width, height: tile),
            arrowCount: 7, edgeLabel: "→ Park North")
        northExit.position = CGPoint(x: worldSize.width / 2, y: worldSize.height - tile / 2)
        root.addChild(northExit)

        let benchCoords: [(Int, Int)] = [(30, 24), (40, 24), (30, 28), (40, 28), (62, 20)]
        let benchPositions = benchCoords.map {
            CGPoint(x: CGFloat($0.0) * tile + tile / 2, y: CGFloat($0.1) * tile + tile / 2)
        }

        let playerSpawn = CGPoint(x: tile * 35.5, y: tile * 4)

        let itemSpawns: [CGPoint] = [
            CGPoint(x: tile * 18, y: tile * 12),
            CGPoint(x: tile * 50, y: tile * 15),
            CGPoint(x: tile * 8, y: tile * 8),
            CGPoint(x: tile * 62, y: tile * 8),
            CGPoint(x: tile * 24, y: tile * 28),
            CGPoint(x: tile * 46, y: tile * 28),
        ]

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 32, y: tile * 26),
            CGPoint(x: tile * 22, y: tile * 14),
            CGPoint(x: tile * 48, y: tile * 20),
            CGPoint(x: tile * 35, y: tile * 10),
            CGPoint(x: tile * 8, y: tile * 24),
        ]

        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.ranger,      CGPoint(x: tile * 45, y: tile * 10)),
            (.sternAdult,  CGPoint(x: tile * 20, y: tile * 20)),
            (.wasp,        CGPoint(x: tile * 55, y: tile * 26)),
            (.pigeon,      CGPoint(x: tile * 34, y: tile * 24)),
            (.pigeon,      CGPoint(x: tile * 26, y: tile * 10)),
            (.flockLeader, CGPoint(x: tile * 36, y: tile * 27)), // Pigeon Flock Leader near fountain
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

    // MARK: - Zone 1A — Park North (pond, ruins, meadow)

    static func buildNorth() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let tile = GameConstants.tileSize
        let cols = GameConstants.parkNorthCols
        let rows = GameConstants.parkNorthRows
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

        let pondLayer = SKNode(); pondLayer.zPosition = GameConstants.ZPos.ground + 1
        pondLayer.addChild(makePond(cx: CGFloat(12) * tile, cy: CGFloat(10) * tile, w: tile * 9, h: tile * 6))
        pondLayer.addChild(makePond(cx: CGFloat(52) * tile, cy: CGFloat(6) * tile, w: tile * 5, h: tile * 3.5))
        root.addChild(pondLayer)

        let decorLayer = SKNode(); decorLayer.zPosition = GameConstants.ZPos.decor
        let decorSpots: [(String, Int, Int, Bool)] = [
            // 🦆 intentionally absent — Quack is missing from the pond!
            ("👣", 11, 9,  false),   // duck footprints leading away from pond
            ("👣", 13, 8,  false),   // trail continues south
            ("⛵", 8, 8, true),
            ("🪵", 6, 7, true),
            ("🌳", 24, 18, true), ("🌳", 32, 16, true),
            ("🍄", 28, 15, false), ("🍄", 38, 18, false), ("🪑", 30, 13, false),
            ("🌲", 50, 8, true), ("🌲", 53, 10, true), ("🌲", 56, 12, true),
            ("🌲", 58, 8, true), ("🌳", 60, 11, true), ("🌲", 62, 9, true),
            ("🌲", 64, 13, true), ("🌳", 48, 10, true), ("🌿", 52, 11, false),
            ("🪧", 48, 6, false),
        ]
        addDecor(decorLayer, spots: decorSpots, tile: tile)
        root.addChild(decorLayer)

        let (plate, gate, chest, boulder) = buildPuzzleRoom16(
            root: root, originCol: 52, originRow: 4, tile: tile)

        let southExit = ZoneExitNode(
            destination: .parkCenter,
            triggerSize: CGSize(width: worldSize.width, height: tile),
            arrowCount: 7, edgeLabel: "→ Park Center")
        southExit.position = CGPoint(x: worldSize.width / 2, y: tile / 2)
        root.addChild(southExit)

        let benchPositions: [CGPoint] = [
            CGPoint(x: tile * 30.5, y: tile * 13.5),
        ]

        let playerSpawn = CGPoint(x: tile * 35.5, y: tile * 8)

        let itemSpawnsFixed: [CGPoint] = [
            CGPoint(x: tile * 28, y: tile * 16),
            CGPoint(x: tile * 55, y: tile * 14),
            CGPoint(x: tile * 10, y: tile * 12),
        ]
        // Quack's feather always spawns near the empty pond — story trigger
        let quackFeatherSpawn = CGPoint(x: tile * 14, y: tile * 9)

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 14, y: tile * 12),
            CGPoint(x: tile * 56, y: tile * 8),
        ]

        // ── Grand Goose Gerald territory markers around the pond ──────────────
        let geraldDecor: [(String, Int, Int)] = [
            ("👑", 9,  13), ("👑", 15, 14), ("👑", 7,  11),
            ("🪧", 11, 14), // "NO TRESPASSING — By order of Gerald"
        ]
        for (g, c, r) in geraldDecor {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile, height: tile)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            n.zPosition = GameConstants.ZPos.decor
            root.addChild(n)
        }

        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.grandGooseGerald, CGPoint(x: tile * 10, y: tile * 12)), // Boss — guards the pond
            (.goose,            CGPoint(x: tile * 13, y: tile * 11)), // Gerald's lieutenants
            (.raccoon,          CGPoint(x: tile * 58, y: tile * 8)),
            (.sternAdult,       CGPoint(x: tile * 10, y: tile * 5)),
            (.wasp,             CGPoint(x: tile * 62, y: tile * 6)),
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawnsFixed,
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

    // MARK: - Shared

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

        // Base water body
        let pond = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        pond.fillColor   = GamePalette.waterMid
        pond.strokeColor = GamePalette.waterDeep.withAlphaComponent(0.55)
        pond.lineWidth   = 3
        container.addChild(pond)

        // Animated ripple rings
        for i in 0..<3 {
            let ripple = SKShapeNode(ellipseOf: CGSize(width: w * 0.35, height: h * 0.35))
            ripple.fillColor   = .clear
            ripple.strokeColor = GamePalette.waterHighlight.withAlphaComponent(0.45)
            ripple.lineWidth   = 1.5
            ripple.position    = CGPoint(x: CGFloat.random(in: -w*0.2...w*0.2),
                                         y: CGFloat.random(in: -h*0.15...h*0.15))
            ripple.alpha       = 0
            container.addChild(ripple)

            let delay = Double(i) * 1.1
            ripple.run(.repeatForever(.sequence([
                .wait(forDuration: delay),
                .group([
                    .scale(to: 2.2, duration: 1.6),
                    .sequence([
                        .fadeIn(withDuration: 0.3),
                        .fadeAlpha(to: 0, duration: 1.3)
                    ])
                ]),
                .scale(to: 1.0, duration: 0)
            ])))
        }

        // Highlight shimmer (slow drift)
        let shimmer = SKShapeNode(ellipseOf: CGSize(width: w * 0.28, height: h * 0.18))
        shimmer.fillColor   = GamePalette.waterHighlight.withAlphaComponent(0.30)
        shimmer.strokeColor = .clear
        shimmer.position    = CGPoint(x: -w * 0.15, y: h * 0.1)
        shimmer.run(.repeatForever(.sequence([
            .moveBy(x: w * 0.22, y: h * 0.05, duration: 2.8),
            .moveBy(x: -w * 0.22, y: -h * 0.05, duration: 2.8)
        ])))
        container.addChild(shimmer)

        // Physics body (on container, but use pond's bounds)
        let body = SKPhysicsBody(circleOfRadius: min(w, h) * 0.40)
        body.isDynamic = false
        body.categoryBitMask = GameConstants.Category.wall
        container.physicsBody = body

        return container
    }

    private static func buildAmphitheater(
        root: SKNode, originCol: Int, originRow: Int, tileW: Int, tileH: Int, tile: CGFloat
    ) {
        let stoneColor = SKColor(red: 0.62, green: 0.60, blue: 0.56, alpha: 1)
        let stoneColor2 = SKColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 1)
        for r in 0..<tileH {
            for c in 0..<tileW {
                let col = (r + c) % 2 == 0 ? stoneColor : stoneColor2
                let tileNode = SKSpriteNode(color: col, size: CGSize(width: tile, height: tile))
                tileNode.anchorPoint = .zero
                tileNode.position = CGPoint(x: CGFloat(originCol + c) * tile, y: CGFloat(originRow + r) * tile)
                tileNode.zPosition = GameConstants.ZPos.ground + 1.2
                root.addChild(tileNode)
            }
        }
        let centerX = CGFloat(originCol + tileW / 2) * tile
        let centerY = CGFloat(originRow + tileH / 2) * tile
        for i in 0..<12 {
            let angle = CGFloat(i) / 11.0 * .pi
            let radius: CGFloat = tile * CGFloat(min(tileW, tileH)) * 0.28
            let sx = centerX + cos(angle) * radius * 1.15
            let sy = centerY - sin(angle) * radius * 0.55
            let seat = SKSpriteNode(texture: SpriteFactory.emojiTexture("🪨", size: 96))
            seat.size = CGSize(width: tile * 0.95, height: tile * 0.95)
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
