import SpriteKit

// Construction zone (88×48) per MAP_SPEC §6: chain-link walled dirt lot,
// heavy equipment clutter, the site office trailer, and — deep in the
// northeast corner — Quack. South gate connects to City Center.
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
        let painter = ScenePainter(
            root: root,
            cols: GameConstants.cityNorthCols,
            rows: GameConstants.cityNorthRows
        )
        let cols = painter.cols, rows = painter.rows

        // L0 — churned dirt everywhere; exposed older earth in the NE corner
        // (the park under the park, peeking through).
        for yT in 0..<rows { for xT in 0..<cols {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-dirt-\((xT * 3 + yT * 7) % 3)-32"),
                             z: PaintLayer.ground.z)
        } }
        painter.fillDarkGrass(rect: SpecRect(66, 2, 20, 8))

        // Gravel work aprons around the machinery + slab areas.
        for r in [SpecRect(24, 12, 18, 10), SpecRect(58, 32, 14, 8), SpecRect(6, 32, 12, 8)] {
            for yT in r.y..<(r.y + r.h) { for xT in r.x..<(r.x + r.w) {
                painter.place1x1(at: xT, yT,
                                 texture: ImportedArt.genTile("tile-gravel-\((xT * 5 + yT * 3) % 3)-32"),
                                 z: PaintLayer.ground.z + 0.1)
            } }
        }
        // Tire-track haul road: gate → the dig, with a branch to the trailer.
        for yT in 14..<(rows - 2) { for xT in 42..<45 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-track-\((yT) % 3)-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }
        for xT in 45..<76 { for yT in 38..<41 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-trackh-\((xT) % 3)-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }

        // THE DIG — the excavation pit over the old buried park (Act 3).
        // Dark churned earth, blob-rimmed, ringed with collision except
        // nothing: you can look, not fall in. Ramp visual on the south lip.
        let pitRect = SpecRect(28, 16, 14, 9)
        painter.autotile(painter.tiles([pitRect]),
                         z: PaintLayer.ground.z + 0.2,
                         interior: { ImportedArt.genTile("tile-pit-\(($0 * 5 + $1 * 7) % 3)-32") },
                         tile: { ImportedArt.genBlobTile("sheet-pit-blob-128", col: $0, rowFromTop: $1) })
        painter.addBlockingRect(pitRect)

        // Chain-link perimeter (1 tile wide, 2 tall visually), gate at the
        // south spur x=42..45.
        let fenceTex = ImportedArt.genTile("prop-chainlink-32x64")
        func fenceRun(_ rect: SpecRect) {
            for yT in stride(from: rect.y, to: rect.y + rect.h, by: 1) {
                for xT in rect.x..<(rect.x + rect.w) {
                    painter.placeSprite(SpecRect(xT, yT - 1, 1, 2), texture: fenceTex, layer: .props)
                }
            }
            painter.addBlockingRect(rect)
        }
        fenceRun(SpecRect(0, 1, cols, 1))
        fenceRun(SpecRect(0, rows - 2, 42, 1))
        fenceRun(SpecRect(46, rows - 2, cols - 46, 1))
        fenceRun(SpecRect(0, 2, 1, rows - 4))
        fenceRun(SpecRect(cols - 1, 2, 1, rows - 4))

        // Equipment + clutter.
        func prop(_ name: String, _ rect: SpecRect, block: Bool = true) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            if block { painter.addBlockingRect(rect) }
        }
        // The half-built structure: girder frame on its slab, crane looming
        // over it, excavator parked at the pit lip.
        prop("prop-girderframe-224x160", SpecRect(48, 8, 7, 5))
        painter.placeSprite(SpecRect(20, 4, 5, 8),
                            texture: ImportedArt.genTile("prop-crane-160x240"), layer: .props)
        painter.addBlockingRect(SpecRect(21, 10, 3, 2))    // mast base only
        prop("prop-excavator-128x96", SpecRect(30, 26, 4, 3))
        prop("prop-cementmixer-64x96", SpecRect(46, 20, 2, 3))

        // Material yard along the west wall.
        prop("prop-container-160x96", SpecRect(4, 26, 5, 3))
        prop("prop-container-160x96", SpecRect(4, 20, 5, 3))
        prop("prop-lumberstack-96x48", SpecRect(10, 34, 3, 2))
        prop("prop-lumberstack-96x48", SpecRect(14, 34, 3, 2))
        prop("prop-pipes-128x48",     SpecRect(8, 38, 4, 2))
        prop("prop-mound-96x64",      SpecRect(12, 22, 3, 2), block: false)
        prop("prop-mound-96x64",      SpecRect(36, 12, 3, 2), block: false)
        prop("prop-mound-96x64",      SpecRect(24, 26, 3, 2), block: false)

        // Site services by the trailer: mixer queue, porta-potties, dumpsters.
        prop("prop-trailer-192x128",  SpecRect(76, 38, 6, 4))
        prop("prop-portapotty-48x80", SpecRect(72, 34, 1, 2))
        prop("prop-portapotty-48x80", SpecRect(74, 34, 1, 2))
        prop("prop-dumpster-96x64",   SpecRect(60, 34, 3, 2))
        prop("prop-dumpster-96x64",   SpecRect(36, 6, 3, 2))
        prop("prop-lumberstack-96x48", SpecRect(56, 14, 3, 2))

        // Cones line the haul road + ring the pit lip.
        for (xT, yT) in [(41, 16), (41, 22), (41, 28), (41, 34), (45, 18), (45, 26),
                         (27, 15), (34, 14), (42, 14), (27, 25), (35, 26),
                         (46, 39), (56, 37), (66, 41)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-cone-24x32"), layer: .decor)
        }
        for (xT, yT) in [(12, 12), (14, 13), (66, 22), (48, 30), (52, 6)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-barrel-32x40"), layer: .props)
        }
        // rubble around the dig + along the old-park grass edge
        for (xT, yT) in [(26, 12), (44, 12), (52, 36), (64, 10), (66, 7), (70, 11),
                         (78, 12), (84, 11), (26, 28), (44, 28)] {
            painter.placeRock(SpecRect(xT, yT, 1, 1), variant: xT % 3 + 1)
        }

        // Quack, cornered in the NE grass patch behind the equipment.
        let quack = QuackNode()
        quack.position = painter.center(SpecRect(74, 5, 1, 1))
        root.addChild(quack)

        painter.addSceneBoundary()

        var exits: [ZoneExitNode] = []
        let sExit = ZoneExitNode(
            destination: .cityCenter,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "City Center"
        )
        sExit.position = painter.center(SpecRect(42, rows - 1, 4, 1))
        root.addChild(sExit); exits.append(sExit)

        return BuildResult(
            root: root,
            npcSpawns: [SpecRect(30, 30, 1, 1), SpecRect(56, 12, 1, 1),
                        SpecRect(46, 24, 1, 1), SpecRect(70, 36, 1, 1)].map(painter.center),
            itemSpawns: [SpecRect(10, 20, 1, 1), SpecRect(60, 40, 1, 1),
                         SpecRect(30, 42, 1, 1)].map(painter.center),
            fixedItems: [],
            enemySpawns: [
                (.wasp,           painter.center(SpecRect(50, 8, 1, 1))),
                (.wasp,           painter.center(SpecRect(70, 14, 1, 1))),
                (.raccoon,        painter.center(SpecRect(16, 32, 1, 1))),
                (.vendingMachine, painter.center(SpecRect(70, 42, 1, 1))),
                (.sternAdult,     painter.center(SpecRect(36, 24, 1, 1)))
            ],
            playerSpawn: painter.center(SpecRect(43, rows - 4, 1, 1)),
            benchPositions: [],
            zoneExitNodes: exits,
            quackNode: quack
        )
    }
}
