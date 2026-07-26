import SpriteKit

// Interior scenes (MAP_SPEC §8 + suburban house interiors).
// Built and renderable now; door transitions get wired in the mechanics
// phase (needs GameZone plumbing + save compatibility).
enum InteriorWorld {

    /// Cozy suburban house interior (20×14): wood floor, furnished.
    /// `seed` varies the furniture arrangement slightly per house.
    static func buildHouse(seed: Int = 0) -> ParkWorld.BuildResult {
        let root = SKNode(); root.name = "world"
        let painter = ScenePainter(root: root, cols: 20, rows: 14)

        // floor + back wall band
        for yT in 0..<14 { for xT in 0..<20 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-floorwood-32"),
                             z: PaintLayer.ground.z)
        } }
        for xT in 0..<20 {
            painter.place1x1(at: xT, 0, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
            painter.place1x1(at: xT, 1, texture: ImportedArt.genTile("tile-wallint-32"),
                             z: PaintLayer.ground.z + 0.1)
        }
        painter.addBlockingRect(SpecRect(0, 0, 20, 2))

        func furn(_ name: String, _ rect: SpecRect, block: Bool = true) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            if block { painter.addBlockingRect(rect) }
        }
        // arrangement varies a touch by seed
        if seed % 2 == 0 {
            furn("furn-bed-64x96",     SpecRect(2, 2, 2, 3))
            furn("furn-cabinet-64x96", SpecRect(16, 1, 2, 3))
            furn("furn-plant-32x64",   SpecRect(18, 10, 1, 2))
        } else {
            furn("furn-bed-64x96",     SpecRect(16, 2, 2, 3))
            furn("furn-cabinet-64x96", SpecRect(2, 1, 2, 3))
            furn("furn-plant-32x64",   SpecRect(1, 10, 1, 2))
        }
        furn("furn-rug-96x64",   SpecRect(8, 6, 3, 2), block: false)
        furn("furn-table-64x48", SpecRect(8, 6, 2, 1))
        furn("furn-chair-32x48", SpecRect(7, 6, 1, 1), block: false)
        furn("furn-chair-32x48", SpecRect(10, 6, 1, 1), block: false)
        furn("furn-counter-96x48", SpecRect(11, 2, 3, 1))

        painter.addSceneBoundary()

        return ParkWorld.BuildResult(
            root: root,
            npcSpawns: [], itemSpawns: [], fixedItems: [], enemySpawns: [],
            playerSpawn: painter.center(SpecRect(10, 12, 1, 1)),
            benchPositions: [], zoneExitNodes: [],
            pressurePlate: nil, gate: nil, chest: nil, boulder: nil
        )
    }

    /// Secret lab interior (26×16) per MAP_SPEC §8: checker floor, console
    /// banks along the north wall, humming quietly about something older.
    static func buildLab() -> ParkWorld.BuildResult {
        let root = SKNode(); root.name = "world"
        let painter = ScenePainter(root: root, cols: 26, rows: 16)

        for yT in 0..<16 { for xT in 0..<26 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-floorlab-32"),
                             z: PaintLayer.ground.z)
        } }
        for xT in 0..<26 {
            painter.place1x1(at: xT, 0, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
            painter.place1x1(at: xT, 1, texture: ImportedArt.genTile("tile-wallint-32"),
                             z: PaintLayer.ground.z + 0.1)
        }
        painter.addBlockingRect(SpecRect(0, 0, 26, 2))

        // console banks along the north wall
        for bx in [2, 9, 16] {
            painter.placeSprite(SpecRect(bx, 2, 4, 3),
                                texture: ImportedArt.genTile("furn-labconsole-128x96"),
                                layer: .props)
            painter.addBlockingRect(SpecRect(bx, 2, 4, 3))
        }
        // work table + clutter
        painter.placeSprite(SpecRect(11, 8, 2, 1),
                            texture: ImportedArt.genTile("furn-table-64x48"), layer: .props)
        painter.addBlockingRect(SpecRect(11, 8, 2, 1))
        painter.placeSprite(SpecRect(22, 3, 1, 2),
                            texture: ImportedArt.genTile("furn-plant-32x64"), layer: .props)
        for (xT, yT) in [(4, 11), (20, 12)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-barrel-32x40"), layer: .props)
            painter.addBlockingRect(SpecRect(xT, yT, 1, 1))
        }

        painter.addSceneBoundary()

        return ParkWorld.BuildResult(
            root: root,
            npcSpawns: [painter.center(SpecRect(13, 5, 1, 1))],
            itemSpawns: [], fixedItems: [], enemySpawns: [],
            playerSpawn: painter.center(SpecRect(13, 14, 1, 1)),
            benchPositions: [], zoneExitNodes: [],
            pressurePlate: nil, gate: nil, chest: nil, boulder: nil
        )
    }
}
