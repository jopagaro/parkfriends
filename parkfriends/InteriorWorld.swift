import SpriteKit

// Interior scenes (MAP_SPEC §8 + suburban house interiors).
// Built and renderable now; door transitions get wired in the mechanics
// phase (needs GameZone plumbing + save compatibility).
enum InteriorWorld {

    /// Cozy suburban house interior (16×11): wood floor, walls on every
    /// side, door gap at the bottom. `seed` varies the furniture layout.
    static func buildHouse(seed: Int = 0) -> ParkWorld.BuildResult {
        let root = SKNode(); root.name = "world"
        let cols = 16, rows = 11
        let painter = ScenePainter(root: root, cols: cols, rows: rows)

        for yT in 0..<rows { for xT in 0..<cols {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-floorwood-32"),
                             z: PaintLayer.ground.z)
        } }
        // back wall band + side/bottom trim with a door gap bottom-center
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
        for xT in 0..<cols where !(7...8).contains(xT) {
            painter.place1x1(at: xT, rows - 1, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
        }
        painter.addBlockingRect(SpecRect(0, 0, cols, 2))
        painter.addBlockingRect(SpecRect(0, 2, 1, rows - 2))
        painter.addBlockingRect(SpecRect(cols - 1, 2, 1, rows - 2))
        painter.addBlockingRect(SpecRect(0, rows - 1, 7, 1))
        painter.addBlockingRect(SpecRect(9, rows - 1, cols - 9, 1))

        func furn(_ name: String, _ rect: SpecRect, block: Bool = true) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            if block { painter.addBlockingRect(rect) }
        }
        // arrangement varies a touch by seed
        if seed % 2 == 0 {
            furn("furn-bed-64x96",     SpecRect(1, 2, 2, 3))
            furn("furn-cabinet-64x96", SpecRect(13, 1, 2, 3))
            furn("furn-plant-32x64",   SpecRect(14, 8, 1, 2))
        } else {
            furn("furn-bed-64x96",     SpecRect(13, 2, 2, 3))
            furn("furn-cabinet-64x96", SpecRect(1, 1, 2, 3))
            furn("furn-plant-32x64",   SpecRect(1, 8, 1, 2))
        }
        furn("furn-rug-96x64",   SpecRect(6, 5, 4, 3), block: false)
        furn("furn-table-64x48", SpecRect(7, 6, 2, 1))
        furn("furn-chair-32x48", SpecRect(6, 6, 1, 1), block: false)
        furn("furn-chair-32x48", SpecRect(9, 6, 1, 1), block: false)
        furn("furn-counter-96x48", SpecRect(9, 2, 3, 1))

        painter.addSceneBoundary()

        return ParkWorld.BuildResult(
            root: root,
            npcSpawns: [], itemSpawns: [], fixedItems: [], enemySpawns: [],
            playerSpawn: painter.center(SpecRect(8, 9, 1, 1)),
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
        for yT in 2..<16 {
            painter.place1x1(at: 0, yT, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
            painter.place1x1(at: 25, yT, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
        }
        for xT in 0..<26 where !(12...13).contains(xT) {
            painter.place1x1(at: xT, 15, texture: ImportedArt.genTile("tile-wallint-top-32"),
                             z: PaintLayer.ground.z + 0.1)
        }
        painter.addBlockingRect(SpecRect(0, 0, 26, 2))
        painter.addBlockingRect(SpecRect(0, 2, 1, 14))
        painter.addBlockingRect(SpecRect(25, 2, 1, 14))
        painter.addBlockingRect(SpecRect(0, 15, 12, 1))
        painter.addBlockingRect(SpecRect(14, 15, 12, 1))

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
