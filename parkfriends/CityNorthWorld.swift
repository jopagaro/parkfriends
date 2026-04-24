import SpriteKit

/// Zone 3 — construction / warehouse (Part 1.1). Reachable via subway from city center.
enum CityNorthWorld {

    struct BuildResult {
        let root: SKNode
        let npcSpawns: [CGPoint]
        let itemSpawns: [CGPoint]
        let fixedItems: [(ItemKind, CGPoint)]
        let enemySpawns: [(EnemyKind, CGPoint)]
        let playerSpawn: CGPoint
        let benchPositions: [CGPoint]
        let zoneExitNodes: [ZoneExitNode]
        let quackNode: QuackNode?
    }

    static func build() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let tile = GameConstants.tileSize
        let cols = GameConstants.cityNorthCols
        let rows = GameConstants.cityNorthRows
        let worldW = CGFloat(cols) * tile
        let worldH = CGFloat(rows) * tile

        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let dirt = (c + r * 3) % 5 == 0 ? GamePalette.dirtD3 : GamePalette.dirtD1
                let n = SKSpriteNode(color: dirt, size: CGSize(width: tile, height: tile))
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
            Spec(c: 1,  r: 4, w: 14, h: 11, pal: .concrete, seed: 801),  // west warehouse
            Spec(c: 22, r: 5, w: 10, h: 10, pal: .brick,    seed: 802),  // center building
            Spec(c: 40, r: 4, w: 14, h: 11, pal: .concrete, seed: 803),  // east warehouse
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
            ("🚧", 16, 2), ("🚧", 38, 2), ("🚧", 21, 3), ("🚧", 33, 3),
            ("🏗️", 17, 9), ("🏗️", 37, 9),
            ("🦺", 19, 4), ("🦺", 35, 4),
            ("📦", 33, 5), ("📦", 34, 5), ("📦", 19, 3),
            ("⛽", 20, 3), ("🪣", 36, 3),
            ("🪧", 30, 2), ("🪧", 31, 2),
            ("🔩", 29, 6), ("🪛", 30, 6),
            ("🌡️", 18, 8), ("🔦", 38, 8),
            ("🗑️", 17, 2), ("🗑️", 37, 2),
        ]
        for (g, c, r) in decor {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile * 1.1, height: tile * 1.1)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            decorLayer.addChild(n)
        }
        root.addChild(decorLayer)

        let south = ZoneExitNode(
            destination: .cityCenter,
            triggerSize: CGSize(width: worldW, height: tile),
            arrowCount: 6, edgeLabel: "→ City Center")
        south.position = CGPoint(x: worldW / 2, y: tile / 2)
        root.addChild(south)

        // ── Quack! Trapped near the east warehouse (side-quest) ──────────────
        let quack = QuackNode()
        quack.position = CGPoint(x: tile * 50, y: tile * 7)
        root.addChild(quack)

        // A "caution" sign and barrier fence around Quack's hiding spot
        let quackDecor: [(String, CGFloat, CGFloat)] = [
            ("⚠️", tile * 48, tile * 6),
            ("🚧", tile * 47, tile * 8),
            ("🚧", tile * 52, tile * 8),
            ("🚧", tile * 47, tile * 5),
            ("🚧", tile * 52, tile * 5),
        ]
        for (g, x, y) in quackDecor {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile, height: tile)
            n.position = CGPoint(x: x, y: y)
            n.zPosition = GameConstants.ZPos.decor
            root.addChild(n)
        }

        // Foreman Rex territory: blueprint board + hard hats around his patrol zone
        let rexDecor: [(String, CGFloat, CGFloat)] = [
            ("📋", tile * 31, tile * 9),
            ("⛑️", tile * 28, tile * 9),
            ("⛑️", tile * 34, tile * 9),
        ]
        for (g, x, y) in rexDecor {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile, height: tile)
            n.position = CGPoint(x: x + tile / 2, y: y + tile / 2)
            n.zPosition = GameConstants.ZPos.decor
            root.addChild(n)
        }

        return BuildResult(
            root: root,
            npcSpawns: [CGPoint(x: tile * 25, y: tile * 8)],
            itemSpawns: [CGPoint(x: tile * 35, y: tile * 7)],
            fixedItems: [],
            enemySpawns: [
                (.foremanRex,     CGPoint(x: tile * 31, y: tile * 8)),  // Boss — construction site center
                (.vendingMachine, CGPoint(x: tile * 20, y: tile * 3)),
                (.skateboardKid,  CGPoint(x: tile * 33, y: tile * 3)),
                (.wasp,           CGPoint(x: tile * 18, y: tile * 3)),
                (.sternAdult,     CGPoint(x: tile * 36, y: tile * 3)),
            ],
            playerSpawn: CGPoint(x: tile * 29.5, y: worldH - tile * 3),
            benchPositions: [],
            zoneExitNodes: [south],
            quackNode: quack
        )
    }
}
