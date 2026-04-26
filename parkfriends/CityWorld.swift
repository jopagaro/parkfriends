import SpriteKit

/// Zone 2 — City Center: main street, apartments, subway to Zone 3 (88×65).
enum CityWorld {

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
        let cols = GameConstants.cityCenterCols   // 88
        let rows = GameConstants.cityCenterRows   // 65
        let worldW = CGFloat(cols) * tile
        let worldH = CGFloat(rows) * tile

        // Ground layer — real textures via ImportedArt, solid-color fallback.
        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let n = WorldTerrain.makeCityGroundTile(
                    col: c, row: r, tile: tile,
                    isSidewalk:        CityMapDesign.isSidewalk(col: c, row: r),
                    isRoad:            CityMapDesign.isMainStreetRoad(col: c, row: r),
                    isCrosswalkArea:   CityMapDesign.isCrosswalkArea(col: c, row: r),
                    isCrosswalkStripe: CityMapDesign.isCrosswalkStripe(col: c, row: r),
                    isCurbLip:         CityMapDesign.isCurbLip(col: c, row: r)
                )
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
            // North apartment row (top, rows 34-52)
            Spec(c: 1,  r: 34, w: 16, h: 18, pal: .brick,    seed: 501),
            Spec(c: 21, r: 36, w: 14, h: 16, pal: .concrete, seed: 502),
            Spec(c: 39, r: 34, w: 12, h: 16, pal: .wood,     seed: 503),
            Spec(c: 55, r: 36, w: 14, h: 16, pal: .brick,    seed: 504),
            Spec(c: 73, r: 34, w: 14, h: 18, pal: .concrete, seed: 505),
            // Mid commercial row (rows 10-26)
            Spec(c: 1,  r: 10, w: 16, h: 14, pal: .concrete, seed: 506),
            Spec(c: 22, r: 10, w: 14, h: 14, pal: .wood,     seed: 507),
            Spec(c: 40, r: 10, w: 12, h: 14, pal: .brick,    seed: 508),
            Spec(c: 56, r: 10, w: 14, h: 14, pal: .concrete, seed: 509),
            Spec(c: 74, r: 10, w: 13, h: 14, pal: .brick,    seed: 510),
            // South plaza (rows 42-58)
            Spec(c: 1,  r: 42, w: 16, h: 14, pal: .wood,     seed: 511),
            Spec(c: 72, r: 42, w: 15, h: 14, pal: .brick,    seed: 512),
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

        // ── Decor layer ───────────────────────────────────────────────────────
        let decorLayer = SKNode(); decorLayer.zPosition = GameConstants.ZPos.decor

        // Street trees and furniture
        let emojiDecor: [(String, Int, Int)] = [
            // Street trees along main road
            ("🌳", 36, 34), ("🌳", 52, 34), ("🌳", 36, 28), ("🌳", 52, 28),
            ("🌳", 20, 34), ("🌳", 68, 34),
            // Benches
            ("🪑", 30, 33), ("🪑", 58, 33), ("🪑", 30, 42), ("🪑", 58, 42),
            // Signs, crates, trash
            ("🪧", 30, 28), ("📦", 24, 11), ("📦", 38, 11),
            ("💡", 32, 14), ("🌺", 22, 32), ("🌺", 66, 32),
            ("🌷", 22, 9),  ("🌷", 38, 9),
            // Subway area
            ("🚇", 44, 4), ("🪧", 42, 5), ("🪧", 46, 5),
            // Misc city detail
            ("🗑️", 20, 14), ("🗑️", 68, 14),
            ("📦", 20, 22), ("📦", 68, 22),
            ("🌳", 30, 56), ("🌳", 58, 56),
            ("🪑", 30, 55), ("🪑", 58, 55),
            ("🛒", 44, 50),
            ("🪧", 44, 58),
            ("🕳️", 52, 34),
            ("🎨", 18, 12),  // street art on alley wall
            ("🎨", 70, 12),
            // Food cart / vendor area
            ("🍕", 43, 43), ("☕", 45, 43),
            ("🪑", 41, 44), ("🪑", 47, 44),
        ]
        for (glyph, c, r) in emojiDecor {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(glyph, size: 96))
            n.size = CGSize(width: tile * 1.1, height: tile * 1.1)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            decorLayer.addChild(n)
        }

        // Streetlamps
        let lampCoords: [(Int, Int)] = [
            (15, 8),  (40, 8),  (72, 8),    // south row
            (15, 28), (40, 29), (52, 29), (72, 28),  // mid
            (15, 44), (72, 44),              // north plaza row
            (30, 56), (58, 56),              // far north
        ]
        for (c, r) in lampCoords {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let lamp = WorldSprites.makeLampPost(city: true)
            lamp.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile)
            decorLayer.addChild(lamp)
        }

        // Officer Grumble territory near subway
        let grumbleDecor: [(String, Int, Int)] = [
            ("🚫", 42, 5), ("🚫", 46, 5),
            ("🪧", 44, 5),
        ]
        for (g, c, r) in grumbleDecor {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile * 1.05, height: tile * 1.05)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            n.zPosition = GameConstants.ZPos.decor
            decorLayer.addChild(n)
        }

        root.addChild(decorLayer)

        // ── Zone exits ────────────────────────────────────────────────────────
        let northToSouthBand = ZoneExitNode(
            destination: .citySouth,
            triggerSize: CGSize(width: worldW, height: tile * 3),
            arrowCount: 7, edgeLabel: "→ City South")
        northToSouthBand.position = CGPoint(x: worldW / 2, y: worldH - tile * 1.5)
        root.addChild(northToSouthBand)

        let subwayToNorth = ZoneExitNode(
            destination: .cityNorth,
            triggerSize: CGSize(width: tile * 5, height: tile * 3),
            arrowCount: 0)
        subwayToNorth.position = CGPoint(x: tile * 44.5, y: tile * 3.5)
        root.addChild(subwayToNorth)

        let benchCoords: [(Int, Int)] = [(30, 33), (58, 33), (30, 42), (58, 42)]
        let benchPositions = benchCoords.map {
            CGPoint(x: CGFloat($0.0) * tile + tile / 2, y: CGFloat($0.1) * tile + tile / 2)
        }

        let playerSpawn = CGPoint(x: tile * 44.5, y: tile * 6)

        let itemSpawns: [CGPoint] = [
            CGPoint(x: tile * 34, y: tile * 34),
            CGPoint(x: tile * 54, y: tile * 34),
            CGPoint(x: tile * 34, y: tile * 12),
            CGPoint(x: tile * 76, y: tile * 34),
            CGPoint(x: tile * 12, y: tile * 34),
            CGPoint(x: tile * 44, y: tile * 16),
            CGPoint(x: tile * 20, y: tile * 56),
            CGPoint(x: tile * 68, y: tile * 56),
        ]

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 32, y: tile * 32),
            CGPoint(x: tile * 56, y: tile * 32),
            CGPoint(x: tile * 32, y: tile * 12),
            CGPoint(x: tile * 44, y: tile * 10),
            CGPoint(x: tile * 44, y: tile * 55),
            CGPoint(x: tile * 22, y: tile * 56),
            CGPoint(x: tile * 66, y: tile * 56),
        ]

        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.officerGrumble, CGPoint(x: tile * 44, y: tile * 8)),   // Boss — blocks subway
            (.goose,          CGPoint(x: tile * 30, y: tile * 33)),   // territorial city goose
            (.goose,          CGPoint(x: tile * 58, y: tile * 33)),
            (.skateboardKid,  CGPoint(x: tile * 60, y: tile * 12)),
            (.skateboardKid,  CGPoint(x: tile * 24, y: tile * 12)),
            (.raccoon,        CGPoint(x: tile * 20, y: tile * 20)),
            (.raccoon,        CGPoint(x: tile * 68, y: tile * 20)),
            (.sternAdult,     CGPoint(x: tile * 34, y: tile * 12)),
            (.sternAdult,     CGPoint(x: tile * 54, y: tile * 12)),
            (.vendingMachine, CGPoint(x: tile * 44, y: tile * 46)),   // possessed machine
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawns,
            enemySpawns: enemySpawns,
            playerSpawn: playerSpawn,
            benchPositions: benchPositions,
            zoneExitNodes: [northToSouthBand, subwayToNorth]
        )
    }
}
