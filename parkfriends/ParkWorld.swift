import SpriteKit

/// Builds the static park world: ground tiles, paths, trees, benches, pond,
/// and a stone-ruin puzzle room.
enum ParkWorld {

    struct BuildResult {
        let root: SKNode
        let npcSpawns: [CGPoint]
        let itemSpawns: [CGPoint]
        let enemySpawns: [CGPoint]
        let playerSpawn: CGPoint
        // Puzzle room wiring
        let pressurePlate: PressurePlateNode
        let gate: GateNode
        let chest: TreasureChestNode
        let boulder: PushableRockNode
    }

    static func build() -> BuildResult {
        let root      = SKNode()
        root.name     = "world"
        let tile      = GameConstants.tileSize
        let cols      = GameConstants.worldCols
        let rows      = GameConstants.worldRows
        let worldSize = GameConstants.worldSize

        // MARK: Ground
        let groundLayer = SKNode()
        groundLayer.zPosition = GameConstants.ZPos.ground
        let grassA = SKColor(red: 0.47, green: 0.73, blue: 0.36, alpha: 1)
        let grassB = SKColor(red: 0.52, green: 0.78, blue: 0.40, alpha: 1)
        for r in 0..<rows {
            for c in 0..<cols {
                let color = ((r + c) % 2 == 0) ? grassA : grassB
                let node  = SKSpriteNode(color: color,
                                         size: CGSize(width: tile, height: tile))
                node.anchorPoint = .zero
                node.position    = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                groundLayer.addChild(node)
            }
        }
        root.addChild(groundLayer)

        // MARK: Dirt path
        let pathColor = SKColor(red: 0.78, green: 0.66, blue: 0.45, alpha: 1)
        let pathLayer = SKNode()
        pathLayer.zPosition = GameConstants.ZPos.ground + 0.5
        for r in 0..<rows {
            let offset = Int(3 * sin(Double(r) / 4.0))
            let center = cols / 2 + offset
            for dc in -1...1 {
                let c = center + dc
                guard c >= 0, c < cols else { continue }
                let node = SKSpriteNode(color: pathColor,
                                        size: CGSize(width: tile, height: tile))
                node.anchorPoint = .zero
                node.position    = CGPoint(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                pathLayer.addChild(node)
            }
        }
        root.addChild(pathLayer)

        // MARK: Pond (upper-left)
        let pondLayer = SKNode()
        pondLayer.zPosition = GameConstants.ZPos.ground + 1
        let pondCenter = CGPoint(x: CGFloat(8) * tile, y: CGFloat(rows - 8) * tile)
        let pond = SKShapeNode(ellipseOf: CGSize(width: tile * 6, height: tile * 4))
        pond.position    = pondCenter
        pond.fillColor   = SKColor(red: 0.36, green: 0.60, blue: 0.85, alpha: 1)
        pond.strokeColor = SKColor(white: 1, alpha: 0.4)
        pond.lineWidth   = 3
        pondLayer.addChild(pond)
        root.addChild(pondLayer)

        let pondBody = SKPhysicsBody(circleOfRadius: tile * 2.0)
        pondBody.isDynamic = false
        pondBody.categoryBitMask = GameConstants.Category.wall
        pond.physicsBody = pondBody

        // MARK: World border
        let border = SKNode()
        let edges = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: worldSize))
        edges.categoryBitMask = GameConstants.Category.wall
        border.physicsBody = edges
        root.addChild(border)

        // MARK: Decorations
        let decorLayer = SKNode()
        decorLayer.zPosition = GameConstants.ZPos.decor
        let decorSpots: [(String, Int, Int, Bool)] = [
            // (glyph, col, row, blocksMovement)
            ("🌳", 4, 4, true),   ("🌳", 6, 3, true),   ("🌳", 30, 5, true),
            ("🌳", 3, 15, true),  ("🌳", 36, 20, true),
            ("🌲", 10, 22, true), ("🌲", 18, 25, true),  ("🌲", 28, 26, true),
            ("🌳", 14, 10, true), ("🪑", 15, 6, false),  ("🪑", 25, 18, false),
            ("🌸", 20, 12, false),("🌷", 22, 8, false),  ("🌻", 28, 14, false),
            ("🍄", 5, 10, false), ("🪨", 9, 18, true),
            // Extra trees along top edge
            ("🌳", 2, 27, true),  ("🌳", 7, 28, true),  ("🌳", 15, 27, true),
            ("🌲", 22, 28, true), ("🌳", 37, 28, true),
            // Fountain area (centre-ish)
            ("⛲", 20, 15, true),
        ]
        for (glyph, c, r, blocks) in decorSpots {
            let node = SKSpriteNode(
                texture: SpriteFactory.emojiTexture(glyph, size: 96)
            )
            node.size     = CGSize(width: tile * 1.1, height: tile * 1.1)
            node.position = CGPoint(
                x: CGFloat(c) * tile + tile / 2,
                y: CGFloat(r) * tile + tile / 2
            )
            node.zPosition = GameConstants.ZPos.decor
            if blocks {
                let body = SKPhysicsBody(circleOfRadius: tile * 0.38)
                body.isDynamic       = false
                body.categoryBitMask = GameConstants.Category.wall
                node.physicsBody     = body
            }
            decorLayer.addChild(node)
        }
        root.addChild(decorLayer)

        // MARK: Puzzle Room — stone ruins, upper-right quadrant
        //
        //  Cols 30-38, Rows 20-28
        //  Layout (# = stone wall, . = floor, B = boulder, P = plate, G = gate, X = chest)
        //
        //   ##########
        //   #....X####
        //   #....G####
        //   #....P....
        //   #....B....
        //   #.........
        //   ##.#######   ← entrance at col 32
        //
        let (plate, gate, chest, boulder) = buildPuzzleRoom(
            root: root,
            originCol: 30, originRow: 20,
            tile: tile
        )

        // MARK: Spawn points
        let playerSpawn = CGPoint(x: worldSize.width / 2, y: tile * 2.5)

        let itemSpawns: [CGPoint] = [
            CGPoint(x: tile * 12, y: tile * 8),
            CGPoint(x: tile * 28, y: tile * 10),
            CGPoint(x: tile * 22, y: tile * 22),
            CGPoint(x: tile * 6,  y: tile * 6),
            CGPoint(x: tile * 7,  y: tile * 20)   // near pond
        ]

        let npcSpawns: [CGPoint] = [
            CGPoint(x: tile * 16, y: tile * 7),    // near bench
            CGPoint(x: tile * 26, y: tile * 19),   // near bench
            CGPoint(x: tile * 12, y: tile * 20),   // wanderer
            CGPoint(x: tile * 20, y: tile * 3)     // south path
        ]

        let enemySpawns: [CGPoint] = [
            CGPoint(x: tile * 30, y: tile * 15),   // ranger
            CGPoint(x: tile * 8,  y: tile * 14),   // stern adult
            CGPoint(x: tile * 25, y: tile * 5),    // wasp near south
            CGPoint(x: tile * 5,  y: tile * 26)    // ranger upper-left
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawns,
            enemySpawns: enemySpawns,
            playerSpawn: playerSpawn,
            pressurePlate: plate,
            gate: gate,
            chest: chest,
            boulder: boulder
        )
    }

    // MARK: - Puzzle Room Builder

    @discardableResult
    private static func buildPuzzleRoom(
        root: SKNode,
        originCol: Int, originRow: Int,
        tile: CGFloat
    ) -> (PressurePlateNode, GateNode, TreasureChestNode, PushableRockNode) {

        let roomLayer = SKNode()
        roomLayer.zPosition = GameConstants.ZPos.ground + 2
        root.addChild(roomLayer)

        func pos(_ c: Int, _ r: Int) -> CGPoint {
            CGPoint(
                x: CGFloat(originCol + c) * tile + tile / 2,
                y: CGFloat(originRow + r) * tile + tile / 2
            )
        }

        // Stone floor inside the room
        let stoneFloor = SKColor(red: 0.60, green: 0.58, blue: 0.55, alpha: 1)
        let stoneFloor2 = SKColor(red: 0.63, green: 0.61, blue: 0.58, alpha: 1)
        for r in 0..<8 {
            for c in 0..<8 {
                let color = ((r + c) % 2 == 0) ? stoneFloor : stoneFloor2
                let tile_ = SKSpriteNode(color: color,
                                          size: CGSize(width: tile, height: tile))
                tile_.anchorPoint = .zero
                tile_.position    = CGPoint(
                    x: CGFloat(originCol + c) * tile,
                    y: CGFloat(originRow + r) * tile
                )
                tile_.zPosition = GameConstants.ZPos.ground + 1.5
                root.addChild(tile_)
            }
        }

        // Wall layout: list of (col-offset, row-offset) that get a 🧱 wall block
        // Room is 8 wide × 8 tall; entrance gap at bottom (col offsets 1-2, row 0)
        var wallSlots: [(Int, Int)] = []
        for c in 0..<8 {
            wallSlots.append((c, 7))   // top wall
            if c != 1 && c != 2 {
                wallSlots.append((c, 0)) // bottom wall with entrance gap at 1,2
            }
        }
        for r in 1..<7 {
            wallSlots.append((0, r))   // left wall
            wallSlots.append((7, r))   // right wall
        }
        // Inner divider with gate gap at col 4, row 4
        for r in 5...7 {
            for c in 3..<7 {
                wallSlots.append((c, r))
            }
        }

        for (dc, dr) in wallSlots {
            let node = SKSpriteNode(
                texture: SpriteFactory.emojiTexture("🧱", size: 96)
            )
            node.size     = CGSize(width: tile, height: tile)
            node.position = pos(dc, dr)
            node.zPosition = GameConstants.ZPos.decor

            let body = SKPhysicsBody(
                rectangleOf: CGSize(width: tile - 4, height: tile - 4)
            )
            body.isDynamic       = false
            body.categoryBitMask = GameConstants.Category.wall
            node.physicsBody     = body

            roomLayer.addChild(node)
        }

        // Sign at entrance
        let sign = SKSpriteNode(texture: SpriteFactory.emojiTexture("🪧", size: 64))
        sign.size     = CGSize(width: 30, height: 30)
        sign.position = pos(3, -1)
        sign.zPosition = GameConstants.ZPos.decor
        root.addChild(sign)

        // Pressure plate — centre of room (col+3, row+2)
        let plate = PressurePlateNode()
        plate.position = pos(3, 2)
        root.addChild(plate)

        // Gate — one tile above the plate (col+3, row+4)
        let gate = GateNode()
        gate.position = pos(3, 4)
        root.addChild(gate)

        // Treasure chest — behind the gate (col+3, row+6)
        let chest = TreasureChestNode()
        chest.position = pos(3, 6)
        root.addChild(chest)

        // Pushable boulder — start a bit south of plate (col+3, row+1)
        let boulder = PushableRockNode()
        boulder.position = pos(3, 1)
        root.addChild(boulder)

        return (plate, gate, chest, boulder)
    }
}
