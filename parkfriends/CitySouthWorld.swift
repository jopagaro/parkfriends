import SpriteKit

/// Zone 2A — alleys, corner store, plaza band (88×42). Touches park to the south.
enum CitySouthWorld {

    struct BuildResult {
        let root: SKNode
        let npcSpawns: [CGPoint]
        let itemSpawns: [CGPoint]
        let enemySpawns: [(EnemyKind, CGPoint)]
        let playerSpawn: CGPoint
        let benchPositions: [CGPoint]
        let zoneExitNodes: [ZoneExitNode]
    }

    static func build() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let tile = GameConstants.tileSize
        let cols = GameConstants.citySouthCols   // 88
        let rows = GameConstants.citySouthRows   // 42
        let worldW = CGFloat(cols) * tile
        let worldH = CGFloat(rows) * tile

        // Ground layer — cracked asphalt with variation
        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let crack = (c + r * 7) % 11 == 0
                let base  = (c + r) % 2 == 0 ? GamePalette.asphalt1 : GamePalette.asphalt2
                let color = crack ? GamePalette.roadR2Deep : base
                let n = SKSpriteNode(color: color, size: CGSize(width: tile, height: tile))
                n.anchorPoint = .zero
                n.position = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                groundLayer.addChild(n)
            }
        }
        root.addChild(groundLayer)

        let border = SKNode()
        border.physicsBody = {
            let b = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero,
                                                       size: CGSize(width: worldW, height: worldH)))
            b.categoryBitMask = GameConstants.Category.wall
            return b
        }()
        root.addChild(border)

        // ── Buildings ─────────────────────────────────────────────────────────
        let buildingLayer = SKNode(); buildingLayer.zPosition = GameConstants.ZPos.ground + 1

        struct Spec {
            let c: Int; let r: Int; let w: Int; let h: Int
            let pal: BuildingFacade.PaletteKind; let seed: UInt64
        }
        let specs: [Spec] = [
            // West cluster
            Spec(c: 2,  r: 12, w: 14, h: 14, pal: .wood,     seed: 101),
            Spec(c: 2,  r: 28, w: 12, h: 12, pal: .brick,    seed: 102),
            // Center commercial
            Spec(c: 22, r: 10, w: 18, h: 16, pal: .brick,    seed: 202),
            Spec(c: 22, r: 28, w: 16, h: 12, pal: .concrete, seed: 203),
            // East cluster
            Spec(c: 56, r: 12, w: 14, h: 14, pal: .concrete, seed: 303),
            Spec(c: 74, r: 14, w: 13, h: 13, pal: .brick,    seed: 404),
            Spec(c: 58, r: 28, w: 12, h: 12, pal: .wood,     seed: 405),
            Spec(c: 74, r: 30, w: 13, h: 10, pal: .concrete, seed: 406),
        ]
        for s in specs {
            let facade = BuildingFacade.makeNode(
                widthTiles: s.w, heightTiles: s.h, tile: tile,
                palette: s.pal, seed: s.seed)
            facade.position = CGPoint(x: CGFloat(s.c) * tile, y: CGFloat(s.r) * tile)
            buildingLayer.addChild(facade)
            let bw = CGFloat(s.w) * tile
            let bh = CGFloat(s.h) * tile
            let body = SKPhysicsBody(rectangleOf: CGSize(width: bw - 4, height: bh - 4),
                                     center: CGPoint(x: bw / 2, y: bh / 2))
            body.isDynamic = false
            body.categoryBitMask = GameConstants.Category.wall
            body.collisionBitMask = 0xFFFFFFFF
            facade.physicsBody = body
        }
        root.addChild(buildingLayer)

        // ── Decor ─────────────────────────────────────────────────────────────
        let decorLayer = SKNode(); decorLayer.zPosition = GameConstants.ZPos.decor

        let decor: [(String, Int, Int)] = [
            // Alley details
            ("🗑️", 19, 20), ("🗑️", 55, 20),
            ("📰", 42, 16), ("🕳️", 48, 14),
            ("🪧", 32, 22), ("📦", 28, 12), ("📦", 60, 12),
            ("💧", 20, 6),  ("🎨", 18, 14), ("🎨", 70, 14),
            ("🐦", 38, 26), ("🐦", 50, 26), ("🐦", 44, 20),
            // Plaza and benches
            ("🪑", 38, 24), ("🪑", 50, 24),
            ("🌺", 36, 22), ("🌺", 52, 22),
            ("🌷", 36, 9),  ("🌷", 52, 9),
            ("🌳", 30, 38), ("🌳", 58, 38),
            // South park edge — transition zone
            ("🌿", 14, 6),  ("🌿", 74, 6),
            ("🌸", 10, 4),  ("🌸", 78, 4),
            ("🌳", 6, 5),   ("🌳", 82, 5),
            ("🪑", 20, 10), ("🪑", 68, 10),
            // Street clutter
            ("📦", 41, 30), ("📦", 47, 30),
            ("🪣", 54, 27), ("⛽", 68, 26),
            ("🚲", 38, 36), ("🚲", 50, 36),
        ]
        for (g, c, r) in decor {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile * 1.05, height: tile * 1.05)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            decorLayer.addChild(n)
        }

        // Streetlamps
        for (c, r) in [(12, 24), (76, 24), (30, 24), (58, 24), (12, 38), (76, 38), (44, 38)] {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let lamp = WorldSprites.makeLampPost(city: true)
            lamp.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile)
            decorLayer.addChild(lamp)
        }

        root.addChild(decorLayer)

        // Breadcrumb trail item near pigeon area (Quack side quest clue)
        let breadcrumb = ItemNode(kind: .breadcrumbTrail)
        breadcrumb.position = CGPoint(x: tile * 40, y: tile * 25)
        root.addChild(breadcrumb)

        // ── Zone exits ────────────────────────────────────────────────────────
        let southToPark = ZoneExitNode(
            destination: .parkCenter,
            triggerSize: CGSize(width: worldW, height: tile),
            arrowCount: 7, edgeLabel: "→ Park")
        southToPark.position = CGPoint(x: worldW / 2, y: tile / 2)
        root.addChild(southToPark)

        let northToCenter = ZoneExitNode(
            destination: .cityCenter,
            triggerSize: CGSize(width: worldW, height: tile),
            arrowCount: 7, edgeLabel: "→ City Center")
        northToCenter.position = CGPoint(x: worldW / 2, y: worldH - tile / 2)
        root.addChild(northToCenter)

        let benchPositions: [CGPoint] = [
            CGPoint(x: tile * 38.5, y: tile * 24.5),
            CGPoint(x: tile * 50.5, y: tile * 24.5),
            CGPoint(x: tile * 20.5, y: tile * 10.5),
            CGPoint(x: tile * 68.5, y: tile * 10.5),
        ]

        let playerSpawn = CGPoint(x: tile * 44.5, y: tile * 3)

        return BuildResult(
            root: root,
            npcSpawns: [
                CGPoint(x: tile * 34, y: tile * 22),
                CGPoint(x: tile * 54, y: tile * 22),
                CGPoint(x: tile * 20, y: tile * 38),
                CGPoint(x: tile * 68, y: tile * 38),
            ],
            itemSpawns: [
                CGPoint(x: tile * 46, y: tile * 22),
                CGPoint(x: tile * 22, y: tile * 12),
                CGPoint(x: tile * 66, y: tile * 12),
                CGPoint(x: tile * 44, y: tile * 36),
                CGPoint(x: tile * 14, y: tile * 30),
                CGPoint(x: tile * 74, y: tile * 30),
            ],
            enemySpawns: [
                (.goose,         CGPoint(x: tile * 38, y: tile * 26)),  // alley goose
                (.goose,         CGPoint(x: tile * 52, y: tile * 26)),
                (.raccoon,       CGPoint(x: tile * 18, y: tile * 14)),
                (.raccoon,       CGPoint(x: tile * 70, y: tile * 14)),
                (.sternAdult,    CGPoint(x: tile * 64, y: tile * 16)),
                (.sternAdult,    CGPoint(x: tile * 24, y: tile * 16)),
                (.skateboardKid, CGPoint(x: tile * 52, y: tile * 10)),
                (.skateboardKid, CGPoint(x: tile * 36, y: tile * 10)),
                (.pigeon,        CGPoint(x: tile * 44, y: tile * 20)),
            ],
            playerSpawn: playerSpawn,
            benchPositions: benchPositions,
            zoneExitNodes: [southToPark, northToCenter]
        )
    }
}
