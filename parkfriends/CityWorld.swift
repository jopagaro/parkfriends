import SpriteKit

/// Zone 2 — City Center: main street, apartments, subway to Zone 3 (Part 1.1).
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
        let cols = GameConstants.cityCenterCols
        let rows = GameConstants.cityCenterRows
        let worldW = CGFloat(cols) * tile
        let worldH = CGFloat(rows) * tile

        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let color = CityMapDesign.groundColor(col: c, row: r)
                let n = SKSpriteNode(color: color, size: CGSize(width: tile, height: tile))
                n.anchorPoint = .zero
                n.position = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                groundLayer.addChild(n)
            }
        }
        root.addChild(groundLayer)

        let border = SKNode()
        border.physicsBody = {
            let b = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: CGSize(width: worldW, height: worldH)))
            b.categoryBitMask = GameConstants.Category.wall
            return b
        }()
        root.addChild(border)

        let buildingLayer = SKNode(); buildingLayer.zPosition = GameConstants.ZPos.ground + 1

        struct Spec { let c: Int; let r: Int; let w: Int; let h: Int; let pal: BuildingFacade.PaletteKind; let seed: UInt64 }
        let specs: [Spec] = [
            Spec(c: 1, r: 21, w: 12, h: 16, pal: .brick, seed: 501),
            Spec(c: 47, r: 21, w: 12, h: 16, pal: .brick, seed: 502),
            Spec(c: 1, r: 6, w: 12, h: 12, pal: .concrete, seed: 503),
            Spec(c: 15, r: 6, w: 12, h: 12, pal: .wood, seed: 504),
            Spec(c: 33, r: 6, w: 11, h: 12, pal: .concrete, seed: 505),
            Spec(c: 47, r: 6, w: 12, h: 12, pal: .brick, seed: 506),
            Spec(c: 14, r: 22, w: 10, h: 12, pal: .brick, seed: 507),
            Spec(c: 36, r: 22, w: 10, h: 12, pal: .wood, seed: 508),
        ]
        for s in specs {
            let facade = BuildingFacade.makeNode(
                widthTiles: s.w, heightTiles: s.h, tile: tile, palette: s.pal, seed: s.seed)
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

        let decorLayer = SKNode(); decorLayer.zPosition = GameConstants.ZPos.decor
        let emojiDecor: [(String, Int, Int)] = [
            ("🌳", 25, 22), ("🌳", 34, 22), ("🌳", 25, 15), ("🌳", 34, 15),
            ("🪑", 20, 20), ("🪑", 39, 20),
            ("🪧", 20, 18), ("📦", 17, 7), ("📦", 25, 7),
            ("💡", 21, 9), ("🌺", 15, 18), ("🌺", 26, 18),
            ("🌷", 15, 5), ("🌷", 26, 5),
            ("🚇", 29, 3), ("🪧", 27, 4),
            ("🗑️", 13, 10), ("🗑️", 46, 10),
            ("📦", 13, 14), ("📦", 46, 14),
            ("🌳", 20, 30), ("🌳", 39, 30),
            ("🪑", 20, 28), ("🪑", 39, 28),
            ("🛒", 28, 31),
            ("🪧", 29, 37),
            ("🕳️", 35, 21),
        ]
        for (glyph, c, r) in emojiDecor {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(glyph, size: 96))
            n.size = CGSize(width: tile * 1.1, height: tile * 1.1)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            decorLayer.addChild(n)
        }

        // Proper drawn streetlamps (replacing 🏮 emoji)
        let lampCoords: [(Int, Int)] = [
            (10, 5), (26, 5), (49, 5),
            (10, 19), (26, 20), (33, 20), (49, 19),
            (10, 34), (49, 34),
        ]
        for (c, r) in lampCoords {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let lamp = WorldSprites.makeLampPost(city: true)
            lamp.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile)
            decorLayer.addChild(lamp)
        }

        root.addChild(decorLayer)

        let northToSouthBand = ZoneExitNode(
            destination: .citySouth,
            triggerSize: CGSize(width: worldW, height: tile * 3),
            arrowCount: 6, edgeLabel: "→ City South")
        northToSouthBand.position = CGPoint(x: worldW / 2, y: worldH - tile * 1.5)
        root.addChild(northToSouthBand)

        // Subway exit — no arrows (it's a teleporter, sign already placed)
        let subwayToNorth = ZoneExitNode(
            destination: .cityNorth,
            triggerSize: CGSize(width: tile * 4, height: tile * 3),
            arrowCount: 0)
        subwayToNorth.position = CGPoint(x: tile * 29.5, y: tile * 2.5)
        root.addChild(subwayToNorth)

        let benchCoords: [(Int, Int)] = [(20, 20), (39, 20), (20, 28), (39, 28)]
        let benchPositions = benchCoords.map {
            CGPoint(x: CGFloat($0.0) * tile + tile / 2, y: CGFloat($0.1) * tile + tile / 2)
        }

        let playerSpawn = CGPoint(x: tile * 29.5, y: tile * 4)

        let itemSpawns: [CGPoint] = [
            CGPoint(x: tile * 22, y: tile * 22),
            CGPoint(x: tile * 37, y: tile * 22),
            CGPoint(x: tile * 22, y: tile * 8),
            CGPoint(x: tile * 50, y: tile * 22),
            CGPoint(x: tile * 8, y: tile * 22),
            CGPoint(x: tile * 29, y: tile * 10),
        ]

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 21, y: tile * 19),
            CGPoint(x: tile * 38, y: tile * 19),
            CGPoint(x: tile * 21, y: tile * 8),
            CGPoint(x: tile * 29, y: tile * 6),
            CGPoint(x: tile * 29, y: tile * 34),
        ]

        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.pigeon, CGPoint(x: tile * 20, y: tile * 21)),
            (.pigeon, CGPoint(x: tile * 39, y: tile * 21)),
            (.raccoon, CGPoint(x: tile * 13, y: tile * 11)),
            (.raccoon, CGPoint(x: tile * 46, y: tile * 11)),
            (.sternAdult, CGPoint(x: tile * 22, y: tile * 7)),
            (.wasp, CGPoint(x: tile * 29, y: tile * 25)),
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
