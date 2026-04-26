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

        // Ground layer — textured asphalt (ImportedArt), solid-color fallback.
        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let n = WorldTerrain.makeCityGroundTile(
                    col: c, row: r, tile: tile,
                    isSidewalk: false, isRoad: false,
                    isCrosswalkArea: false, isCrosswalkStripe: false,
                    isCurbLip: false
                )
                groundLayer.addChild(n)
            }
        }
        root.addChild(groundLayer)

        // South park-edge sidewalk band and center plaza paving — textured.
        let pavingLayer = SKNode()
        pavingLayer.zPosition = GameConstants.ZPos.ground + 0.4

        for c in 0..<cols {
            for r in 2..<8 {
                let n = WorldTerrain.makeCityGroundTile(
                    col: c, row: r, tile: tile,
                    isSidewalk: true, isRoad: false,
                    isCrosswalkArea: false, isCrosswalkStripe: false,
                    isCurbLip: false
                )
                pavingLayer.addChild(n)
            }
        }

        for c in 30..<58 {
            for r in 19..<29 {
                let n = WorldTerrain.makeCityGroundTile(
                    col: c, row: r, tile: tile,
                    isSidewalk: true, isRoad: false,
                    isCrosswalkArea: false, isCrosswalkStripe: false,
                    isCurbLip: false
                )
                pavingLayer.addChild(n)
            }
        }

        for c in [34, 35, 52, 53] {
            for r in 21..<27 {
                let planter = SKSpriteNode(color: GamePalette.foundation,
                                           size: CGSize(width: tile, height: tile))
                planter.anchorPoint = .zero
                planter.position = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                pavingLayer.addChild(planter)
            }
        }
        root.addChild(pavingLayer)

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
            // West houses facing the park edge
            Spec(c: 4,  r: 22, w: 11, h: 12, pal: .wood,     seed: 101),
            Spec(c: 16, r: 22, w: 11, h: 12, pal: .wood,     seed: 102),
            // Center commercial strip
            Spec(c: 30, r: 22, w: 14, h: 15, pal: .brick,    seed: 202),
            Spec(c: 45, r: 22, w: 12, h: 14, pal: .concrete, seed: 203),
            // East businesses / apartments
            Spec(c: 60, r: 22, w: 12, h: 14, pal: .brick,    seed: 303),
            Spec(c: 73, r: 22, w: 11, h: 13, pal: .concrete, seed: 404),
            // Rear service row
            Spec(c: 8,  r: 33, w: 12, h: 8, pal: .brick,     seed: 405),
            Spec(c: 64, r: 33, w: 14, h: 8, pal: .wood,      seed: 406),
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
            ("🗑️", 28, 20), ("🗑️", 58, 20), ("📦", 24, 14), ("📦", 66, 15),
            ("📰", 42, 18), ("🕳️", 48, 13), ("🪧", 44, 21),
            ("💧", 20, 6),  ("🎨", 10, 28), ("🎨", 78, 28),
            ("🐦", 38, 20), ("🐦", 52, 20), ("🐦", 68, 20),
            // Plaza and storefront edge
            ("🪑", 38, 18), ("🪑", 50, 18),
            ("🌳", 34, 18), ("🌳", 54, 18),
            ("🌺", 35, 16), ("🌺", 53, 16), ("🌿", 32, 17), ("🌿", 55, 17),
            ("🌷", 8, 19),  ("🌷", 22, 19), ("🌷", 62, 19), ("🌷", 76, 19),
            ("🌳", 30, 38), ("🌳", 58, 38), ("🌳", 8, 6), ("🌳", 80, 6),
            // South park edge — transition zone
            ("🌸", 10, 4),  ("🌸", 78, 4), ("🌿", 14, 7), ("🌿", 74, 7),
            ("🪑", 20, 10), ("🪑", 68, 10), ("🌿", 24, 8), ("🌿", 64, 8),
            // Street clutter
            ("📦", 12, 31), ("📦", 72, 31),
            ("🪣", 58, 28), ("⛽", 70, 28),
            ("🚲", 38, 36), ("🚲", 50, 36), ("🚲", 16, 36),
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
