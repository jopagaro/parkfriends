import SpriteKit

/// Zone 2A — alleys, corner store, plaza band (Part 1.1). Touches park to the north.
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
        let cols = GameConstants.citySouthCols
        let rows = GameConstants.citySouthRows
        let worldW = CGFloat(cols) * tile
        let worldH = CGFloat(rows) * tile

        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let crack = (c + r * 7) % 11 == 0
                let base = (c + r) % 2 == 0 ? GamePalette.asphalt1 : GamePalette.asphalt2
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
            let b = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: CGSize(width: worldW, height: worldH)))
            b.categoryBitMask = GameConstants.Category.wall
            return b
        }()
        root.addChild(border)

        let buildingLayer = SKNode(); buildingLayer.zPosition = GameConstants.ZPos.ground + 1

        struct Spec { let c: Int; let r: Int; let w: Int; let h: Int; let pal: BuildingFacade.PaletteKind; let seed: UInt64 }
        let specs: [Spec] = [
            Spec(c: 2, r: 8, w: 11, h: 9, pal: .wood, seed: 101),
            Spec(c: 16, r: 6, w: 14, h: 11, pal: .brick, seed: 202),
            Spec(c: 38, r: 7, w: 10, h: 10, pal: .concrete, seed: 303),
            Spec(c: 48, r: 8, w: 11, h: 9, pal: .brick, seed: 404),
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
        let decor: [(String, Int, Int)] = [
            ("🗑️", 13, 11), ("🗑️", 46, 11),
            ("📰", 28, 9), ("🕳️", 32, 8),
            ("🪧", 21, 12), ("📦", 18, 7), ("📦", 40, 7),
            ("💧", 14, 4), ("🎨", 12, 9),
            ("🐦", 25, 14), ("🐦", 35, 14),
        ]
        for (g, c, r) in decor {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile * 1.05, height: tile * 1.05)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            decorLayer.addChild(n)
        }

        // City streetlamps (replace 🏮 emoji)
        for (c, r) in [(8, 12), (51, 12), (20, 12), (39, 12)] {
            let lamp = WorldSprites.makeLampPost(city: true)
            lamp.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile)
            decorLayer.addChild(lamp)
        }

        root.addChild(decorLayer)

        let southToPark = ZoneExitNode(
            destination: .parkCenter,
            triggerSize: CGSize(width: worldW, height: tile),
            arrowCount: 6, edgeLabel: "→ Park")
        southToPark.position = CGPoint(x: worldW / 2, y: tile / 2)
        root.addChild(southToPark)

        let northToCenter = ZoneExitNode(
            destination: .cityCenter,
            triggerSize: CGSize(width: worldW, height: tile),
            arrowCount: 6, edgeLabel: "→ City Center")
        northToCenter.position = CGPoint(x: worldW / 2, y: worldH - tile / 2)
        root.addChild(northToCenter)

        // Breadcrumb trail item near pigeon area (Quack side quest clue)
        let breadcrumb = ItemNode(kind: .breadcrumbTrail)
        breadcrumb.position = CGPoint(x: tile * 26, y: tile * 13)
        root.addChild(breadcrumb)

        let benchPositions: [CGPoint] = [
            CGPoint(x: 25 * tile + tile / 2, y: 13 * tile + tile / 2),
            CGPoint(x: 35 * tile + tile / 2, y: 13 * tile + tile / 2),
        ]

        let playerSpawn = CGPoint(x: tile * 29.5, y: tile * 3)

        return BuildResult(
            root: root,
            npcSpawns: [
                CGPoint(x: tile * 22, y: tile * 11),
                CGPoint(x: tile * 38, y: tile * 10),
            ],
            itemSpawns: [
                CGPoint(x: tile * 30, y: tile * 12),
                CGPoint(x: tile * 15, y: tile * 6),
            ],
            enemySpawns: [
                (.pigeon, CGPoint(x: tile * 24, y: tile * 13)),
                (.raccoon, CGPoint(x: tile * 13, y: tile * 8)),
                (.sternAdult, CGPoint(x: tile * 42, y: tile * 9)),
            ],
            playerSpawn: playerSpawn,
            benchPositions: benchPositions,
            zoneExitNodes: [southToPark, northToCenter]
        )
    }
}
