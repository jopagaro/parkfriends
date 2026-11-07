import SpriteKit

// Interior scenes + the door system that gets you inside them.
// DoorNodes placed at building entrances trigger interior transitions;
// each interior has an exit door at its bottom gap leading back outside.

/// Which interior a door leads to. `nil` on a DoorNode means "exit".
enum InteriorKind {
    case house(seed: Int)
    case lab
    case cafe
    case store
    case hospital
    case police
    case apartment

    var displayTitle: String {
        switch self {
        case .house:     return "Somebody's House"
        case .lab:       return "The Secret Lab"
        case .cafe:      return "Bean There Café"
        case .store:     return "General Store"
        case .hospital:  return "Bellwether Clinic"
        case .police:    return "Police HQ"
        case .apartment: return "Apartment Lobby"
        }
    }

    var subtitle: String {
        switch self {
        case .house:     return "Lived-in  ·  Warm  ·  Not Yours"
        case .lab:       return "Humming  ·  Blinking  ·  Unexplained"
        case .cafe:      return "Coffee  ·  Chalkboard  ·  Quiet Jazz"
        case .store:     return "Snacks  ·  Sundries  ·  Exact Change"
        case .hospital:  return "Clean  ·  Calm  ·  Slightly Too Quiet"
        case .police:    return "Forms  ·  Radios  ·  One Donut Left"
        case .apartment: return "Mailboxes  ·  Echoes  ·  Someone Cooking"
        }
    }

    func build() -> ParkWorld.BuildResult {
        switch self {
        case .house(let seed): return InteriorWorld.buildHouse(seed: seed)
        case .lab:             return InteriorWorld.buildLab()
        case .cafe:            return InteriorWorld.buildCafe()
        case .store:           return InteriorWorld.buildStore()
        case .hospital:        return InteriorWorld.buildHospital()
        case .police:          return InteriorWorld.buildPolice()
        case .apartment:       return InteriorWorld.buildApartment()
        }
    }
}

/// Invisible trigger at a doorway. `interior` set = enter that interior;
/// nil = exit back to the outdoor return point.
final class DoorNode: SKNode {
    let interior: InteriorKind?

    init(interior: InteriorKind?, triggerSize: CGSize) {
        self.interior = interior
        super.init()
        name = "door"
        let body = SKPhysicsBody(rectangleOf: triggerSize)
        body.isDynamic          = false
        body.categoryBitMask    = GameConstants.Category.zoneExit
        body.collisionBitMask   = 0
        body.contactTestBitMask = GameConstants.Category.player
        physicsBody = body
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    /// Drops an entry door trigger covering the given tile rect.
    static func place(_ interior: InteriorKind, at rect: SpecRect,
                      in root: SKNode, painter: ScenePainter) {
        let door = DoorNode(
            interior: interior,
            triggerSize: CGSize(width: GameConstants.tileSize * CGFloat(rect.w),
                                height: GameConstants.tileSize * CGFloat(rect.h))
        )
        door.position = painter.center(rect)
        root.addChild(door)
    }
}

enum InteriorWorld {

    /// Common room shell: floor fill, back wall band, side/bottom trim with
    /// a door gap at the given columns, matching collision, and an exit door.
    private static func shell(cols: Int, rows: Int, floor: String,
                              doorCols: ClosedRange<Int>) -> (SKNode, ScenePainter) {
        let root = SKNode(); root.name = "world"
        let painter = ScenePainter(root: root, cols: cols, rows: rows)
        for yT in 0..<rows { for xT in 0..<cols {
            painter.place1x1(at: xT, yT, texture: ImportedArt.genTile(floor),
                             z: PaintLayer.ground.z)
        } }
        for xT in 0..<cols {
            painter.place1x1(at: xT, 0, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
            painter.place1x1(at: xT, 1, texture: ImportedArt.genTile("tile-wallint-32"),
                             z: PaintLayer.ground.z + 0.1)
        }
        for yT in 2..<rows {
            painter.place1x1(at: 0, yT, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
            painter.place1x1(at: cols - 1, yT, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
        }
        for xT in 0..<cols where !doorCols.contains(xT) {
            painter.place1x1(at: xT, rows - 1, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
        }
        painter.addBlockingRect(SpecRect(0, 0, cols, 2))
        painter.addBlockingRect(SpecRect(0, 2, 1, rows - 2))
        painter.addBlockingRect(SpecRect(cols - 1, 2, 1, rows - 2))
        painter.addBlockingRect(SpecRect(0, rows - 1, doorCols.lowerBound, 1))
        painter.addBlockingRect(SpecRect(doorCols.upperBound + 1, rows - 1,
                                         cols - doorCols.upperBound - 1, 1))
        painter.addSceneBoundary()
        // exit door trigger in the gap
        let exit = DoorNode(interior: nil,
                            triggerSize: CGSize(width: GameConstants.tileSize * CGFloat(doorCols.count),
                                                height: GameConstants.tileSize))
        exit.position = painter.center(SpecRect(doorCols.lowerBound, rows - 1, doorCols.count, 1))
        root.addChild(exit)
        return (root, painter)
    }

    private static func furn(_ painter: ScenePainter, _ name: String,
                             _ rect: SpecRect, block: Bool = true) {
        painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
        if block { painter.addBlockingRect(rect) }
    }

    private static func result(_ root: SKNode, _ painter: ScenePainter,
                               spawn: SpecRect, npcs: [CGPoint] = []) -> ParkWorld.BuildResult {
        ParkWorld.BuildResult(
            root: root,
            npcSpawns: npcs, itemSpawns: [], fixedItems: [], enemySpawns: [],
            playerSpawn: painter.center(spawn),
            benchPositions: [], zoneExitNodes: [],
            pressurePlate: nil, gate: nil, chest: nil, boulder: nil
        )
    }

    /// Cozy suburban house (16×11). `seed` varies the layout.
    static func buildHouse(seed: Int = 0) -> ParkWorld.BuildResult {
        let (root, painter) = shell(cols: 16, rows: 11, floor: "tile-floorwood-32",
                                    doorCols: 7...8)
        if seed % 2 == 0 {
            furn(painter, "furn-bed-64x96",     SpecRect(1, 2, 2, 3))
            furn(painter, "furn-cabinet-64x96", SpecRect(13, 1, 2, 3))
            furn(painter, "furn-plant-32x64",   SpecRect(14, 8, 1, 2))
        } else {
            furn(painter, "furn-bed-64x96",     SpecRect(13, 2, 2, 3))
            furn(painter, "furn-cabinet-64x96", SpecRect(1, 1, 2, 3))
            furn(painter, "furn-plant-32x64",   SpecRect(1, 8, 1, 2))
        }
        furn(painter, "furn-rug-96x64",   SpecRect(6, 5, 4, 3), block: false)
        furn(painter, "furn-table-64x48", SpecRect(7, 6, 2, 1))
        furn(painter, "furn-chair-32x48", SpecRect(6, 6, 1, 1), block: false)
        furn(painter, "furn-chair-32x48", SpecRect(9, 6, 1, 1), block: false)
        furn(painter, "furn-counter-96x48", SpecRect(9, 2, 3, 1))
        return result(root, painter, spawn: SpecRect(7, 9, 2, 1))
    }

    /// Secret lab (26×16) per MAP_SPEC §8.
    static func buildLab() -> ParkWorld.BuildResult {
        let (root, painter) = shell(cols: 26, rows: 16, floor: "tile-floorlab-32",
                                    doorCols: 12...13)
        for bx in [2, 9, 16] {
            furn(painter, "furn-labconsole-128x96", SpecRect(bx, 2, 4, 3))
        }
        furn(painter, "furn-table-64x48", SpecRect(11, 8, 2, 1))
        furn(painter, "furn-plant-32x64", SpecRect(22, 3, 1, 2))
        furn(painter, "prop-barrel-32x40", SpecRect(4, 11, 1, 1))
        furn(painter, "prop-barrel-32x40", SpecRect(20, 12, 1, 1))
        return result(root, painter, spawn: SpecRect(12, 14, 2, 1),
                      npcs: [painter.center(SpecRect(13, 5, 1, 1))])
    }

    /// Café: counter with register, chalkboard menu, tables.
    static func buildCafe() -> ParkWorld.BuildResult {
        let (root, painter) = shell(cols: 18, rows: 12, floor: "tile-floorwood-32",
                                    doorCols: 8...9)
        furn(painter, "furn-menuboard-64x40", SpecRect(2, 1, 2, 1), block: false)
        furn(painter, "furn-counter-96x48", SpecRect(1, 3, 3, 1))
        furn(painter, "furn-counter-96x48", SpecRect(1, 4, 3, 1))
        furn(painter, "furn-register-32x32", SpecRect(3, 3, 1, 1), block: false)
        for (tx, ty) in [(7, 4), (12, 4), (7, 8), (12, 8)] {
            furn(painter, "furn-table-64x48", SpecRect(tx, ty, 2, 1))
            furn(painter, "furn-chair-32x48", SpecRect(tx - 1, ty, 1, 1), block: false)
            furn(painter, "furn-chair-32x48", SpecRect(tx + 2, ty, 1, 1), block: false)
        }
        furn(painter, "furn-plant-32x64", SpecRect(16, 2, 1, 2))
        return result(root, painter, spawn: SpecRect(8, 10, 2, 1),
                      npcs: [painter.center(SpecRect(2, 6, 1, 1))])
    }

    /// General store: stocked aisles + register counter.
    static func buildStore() -> ParkWorld.BuildResult {
        let (root, painter) = shell(cols: 18, rows: 12, floor: "tile-floorwood-32",
                                    doorCols: 8...9)
        for sx in [3, 8, 13] {
            furn(painter, "furn-shelfgoods-64x96", SpecRect(sx, 2, 2, 3))
            furn(painter, "furn-shelfgoods-64x96", SpecRect(sx, 6, 2, 3))
        }
        furn(painter, "furn-counter-96x48", SpecRect(1, 9, 3, 1))
        furn(painter, "furn-register-32x32", SpecRect(2, 9, 1, 1), block: false)
        furn(painter, "furn-plant-32x64", SpecRect(16, 9, 1, 2))
        return result(root, painter, spawn: SpecRect(8, 10, 2, 1),
                      npcs: [painter.center(SpecRect(2, 10, 1, 1))])
    }

    /// Clinic: reception + a row of white beds.
    static func buildHospital() -> ParkWorld.BuildResult {
        let (root, painter) = shell(cols: 20, rows: 12, floor: "tile-floorlab-32",
                                    doorCols: 9...10)
        for bx in [12, 15, 18] {
            furn(painter, "furn-bedwhite-64x96", SpecRect(bx, 2, 2, 3))
        }
        furn(painter, "furn-counter-96x48", SpecRect(2, 4, 3, 1))
        furn(painter, "furn-register-32x32", SpecRect(3, 4, 1, 1), block: false)
        furn(painter, "furn-plant-32x64", SpecRect(1, 8, 1, 2))
        furn(painter, "furn-cabinet-64x96", SpecRect(6, 1, 2, 3))
        return result(root, painter, spawn: SpecRect(9, 10, 2, 1),
                      npcs: [painter.center(SpecRect(3, 6, 1, 1))])
    }

    /// Police HQ: desks, radio bank, and one very guarded donut.
    static func buildPolice() -> ParkWorld.BuildResult {
        let (root, painter) = shell(cols: 18, rows: 12, floor: "tile-floorlab-32",
                                    doorCols: 8...9)
        furn(painter, "furn-labconsole-128x96", SpecRect(13, 2, 4, 3))
        for (tx, ty) in [(3, 4), (3, 7), (8, 4)] {
            furn(painter, "furn-table-64x48", SpecRect(tx, ty, 2, 1))
            furn(painter, "furn-chair-32x48", SpecRect(tx + 2, ty, 1, 1), block: false)
        }
        furn(painter, "furn-cabinet-64x96", SpecRect(1, 1, 2, 3))
        furn(painter, "furn-plant-32x64", SpecRect(16, 8, 1, 2))
        return result(root, painter, spawn: SpecRect(8, 10, 2, 1),
                      npcs: [painter.center(SpecRect(9, 5, 1, 1))])
    }

    /// Apartment lobby: mail wall, bench, echoing plant.
    static func buildApartment() -> ParkWorld.BuildResult {
        let (root, painter) = shell(cols: 14, rows: 10, floor: "tile-floorwood-32",
                                    doorCols: 6...7)
        furn(painter, "furn-cabinet-64x96", SpecRect(1, 1, 2, 3))
        furn(painter, "furn-cabinet-64x96", SpecRect(11, 1, 2, 3))
        furn(painter, "furn-rug-96x64", SpecRect(5, 4, 4, 3), block: false)
        painter.placeSprite(SpecRect(5, 7, 2, 1),
                            texture: ImportedArt.genTile("prop-bench-64x40"), layer: .props)
        furn(painter, "furn-plant-32x64", SpecRect(12, 7, 1, 2))
        return result(root, painter, spawn: SpecRect(6, 8, 2, 1))
    }
}
