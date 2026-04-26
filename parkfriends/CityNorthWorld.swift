import SpriteKit

/// Zone 3 — construction / warehouse district (88×48). Reachable via subway from city center.
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
        let cols = GameConstants.cityNorthCols   // 88
        let rows = GameConstants.cityNorthRows   // 48
        let worldW = CGFloat(cols) * tile
        let worldH = CGFloat(rows) * tile

        // Ground layer — textured; paved south entrance + dirt/gravel construction zone.
        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        for r in 0..<rows {
            for c in 0..<cols {
                let pave = r < 8   // south entrance strip is paved asphalt
                let n: SKSpriteNode
                if pave {
                    n = WorldTerrain.makeCityGroundTile(
                        col: c, row: r, tile: tile,
                        isSidewalk: false, isRoad: false,
                        isCrosswalkArea: false, isCrosswalkStripe: false,
                        isCurbLip: false
                    )
                } else {
                    // Dirt / gravel: reuse path texture from ImportedArt, fallback to color.
                    let variant = abs(((c &* 73) ^ (r &* 151) ^ ((c + r) &* 19)))
                    let sz = CGSize(width: tile, height: tile)
                    if let tex = ImportedArt.cityDirtTexture(variant: variant) {
                        n = SKSpriteNode(texture: tex, size: sz)
                    } else {
                        let gravel = (c + r * 3) % 7 == 0
                        n = SKSpriteNode(color: gravel ? GamePalette.dirtD3 : GamePalette.dirtD1, size: sz)
                    }
                    n.anchorPoint = .zero
                    n.position = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                }
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

        // ── Buildings / Warehouses ────────────────────────────────────────────
        let buildingLayer = SKNode(); buildingLayer.zPosition = GameConstants.ZPos.ground + 1

        struct Spec {
            let c: Int; let r: Int; let w: Int; let h: Int
            let pal: BuildingFacade.PaletteKind; let seed: UInt64
        }
        let specs: [Spec] = [
            Spec(c: 1,  r: 8,  w: 18, h: 16, pal: .concrete, seed: 801),  // west warehouse
            Spec(c: 1,  r: 28, w: 16, h: 14, pal: .brick,    seed: 802),  // west warehouse 2
            Spec(c: 24, r: 10, w: 14, h: 14, pal: .brick,    seed: 803),  // center building
            Spec(c: 24, r: 28, w: 14, h: 14, pal: .concrete, seed: 804),  // center building 2
            Spec(c: 42, r: 9,  w: 18, h: 16, pal: .wood,     seed: 805),  // mid warehouse
            Spec(c: 64, r: 8,  w: 18, h: 16, pal: .concrete, seed: 806),  // east warehouse (Quack here)
            Spec(c: 64, r: 28, w: 18, h: 16, pal: .brick,    seed: 807),  // east warehouse 2
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
            // Construction zone markings
            ("🚧", 22, 4),  ("🚧", 40, 4),  ("🚧", 62, 4),  ("🚧", 32, 5),
            ("🚧", 20, 25), ("🚧", 60, 25), ("🚧", 40, 26),
            // Heavy machinery
            ("🏗️", 22, 14), ("🏗️", 60, 14), ("🏗️", 42, 28),
            // Worker gear
            ("🦺", 28, 8),  ("🦺", 52, 8),  ("🦺", 22, 26),
            ("⛑️", 36, 10), ("⛑️", 50, 10),
            // Crates and supplies
            ("📦", 20, 9),  ("📦", 21, 9),  ("📦", 40, 7),  ("📦", 41, 7),
            ("📦", 60, 9),  ("📦", 61, 9),  ("📦", 22, 27), ("📦", 60, 27),
            // Tools and equipment
            ("⛽", 22, 7),  ("🪣", 38, 7),  ("🔩", 44, 14), ("🪛", 45, 14),
            ("🔦", 58, 7),  ("🪚", 52, 26),
            // Signs and warnings
            ("🪧", 44, 4),  ("🪧", 45, 4),
            ("⚠️", 40, 42), ("⚠️", 48, 42), ("⚠️", 74, 14),
            // Trash and misc
            ("🗑️", 20, 5),  ("🗑️", 62, 5),
            ("🌡️", 22, 20), ("🔦", 60, 20),
            // Far north — deep construction
            ("🏗️", 20, 40), ("🏗️", 65, 40),
            ("📦", 30, 42), ("📦", 55, 42), ("📦", 74, 38),
            ("🚧", 44, 42), ("🚧", 34, 40),
        ]
        for (g, c, r) in decor {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile * 1.1, height: tile * 1.1)
            n.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile + tile / 2)
            decorLayer.addChild(n)
        }

        // Site lamps (industrial style)
        for (c, r) in [(20, 8), (62, 8), (40, 10), (20, 26), (62, 26), (40, 30)] {
            guard c >= 0, c < cols, r >= 0, r < rows else { continue }
            let lamp = WorldSprites.makeLampPost(city: true)
            lamp.position = CGPoint(x: CGFloat(c) * tile + tile / 2, y: CGFloat(r) * tile)
            decorLayer.addChild(lamp)
        }

        root.addChild(decorLayer)

        // ── Quack! Trapped near the east warehouse ────────────────────────────
        let quack = QuackNode()
        quack.position = CGPoint(x: tile * 73, y: tile * 22)
        root.addChild(quack)

        // Caution signs and barrier around Quack's hiding spot
        let quackDecor: [(String, CGFloat, CGFloat)] = [
            ("⚠️", tile * 70, tile * 20),
            ("🚧", tile * 69, tile * 24),
            ("🚧", tile * 77, tile * 24),
            ("🚧", tile * 69, tile * 18),
            ("🚧", tile * 77, tile * 18),
        ]
        for (g, x, y) in quackDecor {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile, height: tile)
            n.position = CGPoint(x: x, y: y)
            n.zPosition = GameConstants.ZPos.decor
            root.addChild(n)
        }

        // Foreman Rex blueprint / command post zone
        let rexDecor: [(String, CGFloat, CGFloat)] = [
            ("📋", tile * 43, tile * 24),
            ("⛑️", tile * 40, tile * 26),
            ("⛑️", tile * 46, tile * 26),
            ("🪧", tile * 43, tile * 26),
        ]
        for (g, x, y) in rexDecor {
            let n = SKSpriteNode(texture: SpriteFactory.emojiTexture(g, size: 96))
            n.size = CGSize(width: tile, height: tile)
            n.position = CGPoint(x: x + tile / 2, y: y + tile / 2)
            n.zPosition = GameConstants.ZPos.decor
            root.addChild(n)
        }

        // ── Zone exit ─────────────────────────────────────────────────────────
        let south = ZoneExitNode(
            destination: .cityCenter,
            triggerSize: CGSize(width: worldW, height: tile),
            arrowCount: 7, edgeLabel: "→ City Center")
        south.position = CGPoint(x: worldW / 2, y: tile / 2)
        root.addChild(south)

        return BuildResult(
            root: root,
            npcSpawns: [
                CGPoint(x: tile * 36, y: tile * 22),   // worker near center
                CGPoint(x: tile * 22, y: tile * 20),   // west worker
                CGPoint(x: tile * 30, y: tile * 38),   // deep site worker
            ],
            itemSpawns: [
                CGPoint(x: tile * 44, y: tile * 22),
                CGPoint(x: tile * 22, y: tile * 24),
                CGPoint(x: tile * 62, y: tile * 24),
                CGPoint(x: tile * 44, y: tile * 38),
                CGPoint(x: tile * 20, y: tile * 38),
                CGPoint(x: tile * 68, y: tile * 38),
            ],
            fixedItems: [],
            enemySpawns: [
                (.foremanRex,     CGPoint(x: tile * 44, y: tile * 26)),   // Boss
                (.vendingMachine, CGPoint(x: tile * 22, y: tile * 6)),
                (.skateboardKid,  CGPoint(x: tile * 50, y: tile * 6)),
                (.skateboardKid,  CGPoint(x: tile * 38, y: tile * 36)),
                (.wasp,           CGPoint(x: tile * 24, y: tile * 6)),
                (.wasp,           CGPoint(x: tile * 62, y: tile * 36)),
                (.sternAdult,     CGPoint(x: tile * 56, y: tile * 6)),
                (.sternAdult,     CGPoint(x: tile * 34, y: tile * 36)),
                (.raccoon,        CGPoint(x: tile * 44, y: tile * 42)),
            ],
            playerSpawn: CGPoint(x: tile * 44.5, y: worldH - tile * 4),
            benchPositions: [],
            zoneExitNodes: [south],
            quackNode: quack
        )
    }
}
