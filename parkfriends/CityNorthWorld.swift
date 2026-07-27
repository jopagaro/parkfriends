import SpriteKit

// Construction zone (56×36, compact per EB density rules): chain-link
// walled site. Six functional areas — the build (slab/frame/crane), the
// dig, the material yard, the staked phase-2 lot, the site office, and
// the old-park remnant where Quack hides. South gate → City Center.
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

        // L0 — churned dirt; the old park's grass survives in the NE corner.
        for yT in 0..<rows { for xT in 0..<cols {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-dirt-\((xT * 3 + yT * 7) % 3)-32"),
                             z: PaintLayer.ground.z)
        } }
        painter.fillDarkGrass(rect: SpecRect(40, 2, 14, 6))

        // Chain-link perimeter, gate at the south spur x=26..29.
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
        fenceRun(SpecRect(0, rows - 2, 26, 1))
        fenceRun(SpecRect(30, rows - 2, cols - 30, 1))
        fenceRun(SpecRect(0, 2, 1, rows - 4))
        fenceRun(SpecRect(cols - 1, 2, 1, rows - 4))

        func prop(_ name: String, _ rect: SpecRect, block: Bool = true) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            if block { painter.addBlockingRect(rect) }
        }

        // — Haul roads: gate → build/dig, west branch under the dig, east
        //   branch to the office (directional track tiles) —
        for yT in 10..<(rows - 2) { for xT in 26..<29 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-track-\(yT % 3)-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }
        for xT in 8..<26 { for yT in 24..<26 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-trackh-\(xT % 3)-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }
        for xT in 29..<44 { for yT in 30..<32 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-trackh-\(xT % 3)-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }

        // — THE BUILD (NW): slab with girder frame, crane, mixer, lumber —
        for yT in 3..<14 { for xT in 12..<26 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-gravel-\((xT * 5 + yT * 3) % 3)-32"),
                             z: PaintLayer.ground.z + 0.1)
        } }
        prop("prop-girderframe-224x160", SpecRect(15, 4, 7, 5))
        painter.placeSprite(SpecRect(10, 2, 5, 8),
                            texture: ImportedArt.genTile("prop-crane-160x240"), layer: .props)
        painter.addBlockingRect(SpecRect(11, 8, 3, 2))
        prop("prop-cementmixer-64x96", SpecRect(23, 9, 2, 3))
        prop("prop-lumberstack-96x48", SpecRect(17, 10, 3, 2))
        for (xT, yT) in [(23, 4), (23, 6)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-barrel-32x40"), layer: .props)
        }

        // — THE DIG (center): pit, excavator on the lip, spoil ring —
        let pitRect = SpecRect(16, 17, 10, 6)
        painter.autotile(painter.tiles([pitRect]),
                         z: PaintLayer.ground.z + 0.2,
                         interior: { ImportedArt.genTile("tile-pit-\(($0 * 5 + $1 * 7) % 3)-32") },
                         tile: { ImportedArt.genBlobTile("sheet-pit-blob-128", col: $0, rowFromTop: $1) })
        painter.addBlockingRect(pitRect)
        prop("prop-excavator-128x96", SpecRect(11, 19, 4, 3))
        prop("prop-mound-96x64", SpecRect(14, 15, 3, 2), block: false)
        prop("prop-mound-96x64", SpecRect(24, 16, 3, 2), block: false)
        prop("prop-mound-96x64", SpecRect(19, 23, 3, 2), block: false)
        for (xT, yT) in [(15, 16), (26, 15), (15, 23), (26, 23)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-cone-24x32"), layer: .decor)
        }

        // — MATERIAL YARD (SW): ordered rows on gravel —
        for yT in 27..<34 { for xT in 2..<12 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-gravel-\((xT * 7 + yT) % 3)-32"),
                             z: PaintLayer.ground.z + 0.1)
        } }
        prop("prop-container-160x96", SpecRect(3, 27, 5, 3))
        prop("prop-lumberstack-96x48", SpecRect(3, 31, 3, 2))
        prop("prop-lumberstack-96x48", SpecRect(7, 31, 3, 2))
        prop("prop-pipes-128x48", SpecRect(8, 27, 4, 2))
        painter.placeSprite(SpecRect(10, 30, 1, 1),
                            texture: ImportedArt.genTile("prop-barrel-32x40"), layer: .props)

        // — PHASE-2 LOT (E): surveyor stakes + foundation trenches —
        for (xT, yT) in [(33, 12), (40, 12), (47, 12), (33, 18), (40, 18), (47, 18),
                         (33, 24), (40, 24), (47, 24)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-stake-16x32"), layer: .decor)
        }
        for r in [SpecRect(35, 15, 10, 1), SpecRect(35, 21, 10, 1)] {
            painter.autotile(painter.tiles([r]),
                             z: PaintLayer.ground.z + 0.2,
                             tile: { ImportedArt.genBlobTile("sheet-pit-blob-128", col: $0, rowFromTop: $1) })
            painter.addBlockingRect(r)
        }
        for (xT, yT) in [(38, 19), (45, 23), (49, 15)] {
            painter.placeRock(SpecRect(xT, yT, 1, 1), variant: xT % 3 + 1)
        }

        // — SITE OFFICE (SE): trailer, welfare, the foreman's pickup —
        prop("prop-trailer-192x128", SpecRect(44, 28, 6, 4))
        prop("prop-portapotty-48x80", SpecRect(41, 28, 1, 2))
        prop("prop-portapotty-48x80", SpecRect(43, 28, 1, 2))
        prop("prop-dumpster-96x64", SpecRect(38, 32, 3, 2))
        painter.placeSprite(SpecRect(50, 32, 3, 2),
                            texture: ImportedArt.genTile("prop-car-red-96x48"), layer: .props)
        painter.addBlockingRect(SpecRect(50, 32, 3, 2))
        painter.placeSprite(SpecRect(45, 33, 2, 1),
                            texture: ImportedArt.genTile("prop-bench-64x40"), layer: .props)

        // — OLD-PARK REMNANT (NE): what the site is burying —
        painter.placeTree(SpecRect(48, 2, 3, 4), texture: ImportedArt.parkMediumTree())
        painter.placeSprite(SpecRect(42, 5, 2, 1),
                            texture: ImportedArt.genTile("prop-bench-64x40"), layer: .props)
        painter.placeSprite(SpecRect(41, 3, 1, 1),
                            texture: ImportedArt.genTile("prop-tallgrass-0-32"), layer: .decor)
        painter.placeSprite(SpecRect(52, 6, 1, 1),
                            texture: ImportedArt.genTile("prop-tallgrass-1-32"), layer: .decor)

        // — Route dressing + variation rubble in the open ground —
        for (xT, yT) in [(25, 12), (30, 16), (25, 21), (30, 26), (25, 30),
                         (31, 29), (37, 33), (10, 23), (18, 26)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-cone-24x32"), layer: .decor)
        }
        prop("prop-dumpster-96x64", SpecRect(30, 4, 3, 2))
        for (xT, yT) in [(6, 8), (8, 16), (34, 7), (52, 20), (36, 26), (20, 33),
                         (6, 21), (52, 26), (33, 9)] {
            painter.placeRock(SpecRect(xT, yT, 1, 1), variant: xT % 3 + 1)
        }

        // Quack, cornered in the NE grass patch behind the equipment.
        let quack = QuackNode()
        quack.position = painter.center(SpecRect(46, 4, 1, 1))
        root.addChild(quack)

        painter.addSceneBoundary()

        var exits: [ZoneExitNode] = []
        let sExit = ZoneExitNode(
            destination: .cityCenter,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "City Center"
        )
        sExit.position = painter.center(SpecRect(26, rows - 1, 4, 1))
        root.addChild(sExit); exits.append(sExit)

        return BuildResult(
            root: root,
            npcSpawns: [SpecRect(18, 8, 1, 1), SpecRect(14, 25, 1, 1),
                        SpecRect(36, 16, 1, 1), SpecRect(46, 26, 1, 1)].map(painter.center),
            itemSpawns: [SpecRect(9, 29, 1, 1), SpecRect(50, 24, 1, 1),
                         SpecRect(20, 32, 1, 1)].map(painter.center),
            fixedItems: [],
            enemySpawns: [
                (.wasp,           painter.center(SpecRect(32, 6, 1, 1))),
                (.wasp,           painter.center(SpecRect(44, 20, 1, 1))),
                (.raccoon,        painter.center(SpecRect(5, 30, 1, 1))),
                (.vendingMachine, painter.center(SpecRect(34, 30, 1, 1))),
                (.sternAdult,     painter.center(SpecRect(21, 14, 1, 1)))
            ],
            playerSpawn: painter.center(SpecRect(27, rows - 4, 1, 1)),
            benchPositions: [],
            zoneExitNodes: exits,
            quackNode: quack
        )
    }
}
