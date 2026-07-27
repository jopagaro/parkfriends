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

        // ── FUNCTIONAL LAYOUT (world-design rules: every area answers
        // "what happens here?", related props share one screen, paths
        // connect the areas, no dead fields) ──────────────────────────
        //   NW: material yard   N-center: the build   NE: old-park remnant
        //   C-south: the dig    E: staked phase-2 lot  SE: site office
        func prop(_ name: String, _ rect: SpecRect, block: Bool = true) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            if block { painter.addBlockingRect(rect) }
        }

        // — Haul roads: gate → build/dig junction, west to the yard,
        //   east to the office (tracks are directional) —
        for yT in 18..<(rows - 2) { for xT in 42..<45 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-track-\(yT % 3)-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }
        for xT in 18..<42 { for yT in 30..<33 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-trackh-\(xT % 3)-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }
        for xT in 45..<74 { for yT in 38..<41 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-trackh-\(xT % 3)-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }

        // — THE BUILD (N-center): slab, girder frame, crane, mixer, lumber —
        for yT in 6..<20 { for xT in 24..<44 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-gravel-\((xT * 5 + yT * 3) % 3)-32"),
                             z: PaintLayer.ground.z + 0.1)
        } }
        prop("prop-girderframe-224x160", SpecRect(29, 7, 7, 5))
        painter.placeSprite(SpecRect(23, 3, 5, 8),
                            texture: ImportedArt.genTile("prop-crane-160x240"), layer: .props)
        painter.addBlockingRect(SpecRect(24, 9, 3, 2))
        prop("prop-cementmixer-64x96", SpecRect(38, 14, 2, 3))
        prop("prop-lumberstack-96x48", SpecRect(29, 15, 3, 2))
        for (xT, yT) in [(41, 8), (41, 10)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-barrel-32x40"), layer: .props)
        }

        // — THE DIG (center-south): pit, excavator on the lip, spoil ring —
        let pitRect = SpecRect(28, 24, 12, 7)
        painter.autotile(painter.tiles([pitRect]),
                         z: PaintLayer.ground.z + 0.2,
                         interior: { ImportedArt.genTile("tile-pit-\(($0 * 5 + $1 * 7) % 3)-32") },
                         tile: { ImportedArt.genBlobTile("sheet-pit-blob-128", col: $0, rowFromTop: $1) })
        painter.addBlockingRect(pitRect)
        prop("prop-excavator-128x96", SpecRect(23, 27, 4, 3))
        prop("prop-mound-96x64", SpecRect(26, 22, 3, 2), block: false)
        prop("prop-mound-96x64", SpecRect(40, 23, 3, 2), block: false)
        prop("prop-mound-96x64", SpecRect(33, 31, 3, 2), block: false)
        for (xT, yT) in [(27, 23), (40, 22), (27, 31), (40, 31)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-cone-24x32"), layer: .decor)
        }

        // — MATERIAL YARD (NW): ordered rows on gravel —
        for yT in 24..<40 { for xT in 4..<18 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-gravel-\((xT * 7 + yT) % 3)-32"),
                             z: PaintLayer.ground.z + 0.1)
        } }
        prop("prop-container-160x96", SpecRect(5, 25, 5, 3))
        prop("prop-container-160x96", SpecRect(11, 25, 5, 3))
        prop("prop-lumberstack-96x48", SpecRect(5, 30, 3, 2))
        prop("prop-lumberstack-96x48", SpecRect(9, 30, 3, 2))
        prop("prop-pipes-128x48", SpecRect(13, 31, 4, 2))
        prop("prop-mound-96x64", SpecRect(6, 35, 3, 2), block: false)
        for (xT, yT) in [(12, 36), (14, 35)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-barrel-32x40"), layer: .props)
        }

        // — PHASE-2 LOT (E): surveyor stakes + foundation trenches —
        for (xT, yT) in [(54, 14), (62, 14), (70, 14), (54, 22), (62, 22), (70, 22),
                         (54, 30), (62, 30), (70, 30)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-stake-16x32"), layer: .decor)
        }
        for r in [SpecRect(56, 17, 12, 1), SpecRect(56, 26, 12, 1)] {
            painter.autotile(painter.tiles([r]),
                             z: PaintLayer.ground.z + 0.2,
                             tile: { ImportedArt.genBlobTile("sheet-pit-blob-128", col: $0, rowFromTop: $1) })
            painter.addBlockingRect(r)
        }
        for (xT, yT) in [(58, 20), (66, 24), (60, 28)] {
            painter.placeRock(SpecRect(xT, yT, 1, 1), variant: xT % 3 + 1)
        }

        // — SITE OFFICE (SE): trailer, welfare, parking —
        prop("prop-trailer-192x128", SpecRect(76, 36, 6, 4))
        prop("prop-portapotty-48x80", SpecRect(72, 36, 1, 2))
        prop("prop-portapotty-48x80", SpecRect(74, 36, 1, 2))
        prop("prop-dumpster-96x64", SpecRect(70, 42, 3, 2))
        painter.placeSprite(SpecRect(80, 42, 3, 2),
                            texture: ImportedArt.genTile("prop-car-red-96x48"), layer: .props)
        painter.addBlockingRect(SpecRect(80, 42, 3, 2))
        painter.placeSprite(SpecRect(76, 34, 2, 1),
                            texture: ImportedArt.genTile("prop-bench-64x40"), layer: .props)

        // — OLD-PARK REMNANT (NE): what the site is burying —
        painter.placeTree(SpecRect(78, 2, 3, 4), texture: ImportedArt.parkMediumTree())
        painter.placeSprite(SpecRect(70, 6, 2, 1),
                            texture: ImportedArt.genTile("prop-bench-64x40"), layer: .props)
        painter.placeSprite(SpecRect(83, 7, 1, 1),
                            texture: ImportedArt.genTile("prop-tallgrass-0-32"), layer: .decor)
        painter.placeSprite(SpecRect(68, 4, 1, 1),
                            texture: ImportedArt.genTile("prop-tallgrass-1-32"), layer: .decor)

        // — Route dressing: cones along the haul roads, stray gear,
        //   variation rubble in the open in-between ground —
        for (xT, yT) in [(41, 20), (45, 24), (41, 28), (45, 34), (41, 42),
                         (20, 29), (28, 33), (36, 33), (50, 37), (58, 41), (66, 37)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-cone-24x32"), layer: .decor)
        }
        prop("prop-dumpster-96x64", SpecRect(48, 6, 3, 2))
        for (xT, yT) in [(20, 14), (48, 22), (50, 28), (76, 16), (82, 24), (12, 10),
                         (30, 40), (60, 6), (36, 42), (52, 44), (10, 44), (84, 30)] {
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
            npcSpawns: [SpecRect(33, 13, 1, 1), SpecRect(26, 33, 1, 1),
                        SpecRect(58, 24, 1, 1), SpecRect(74, 41, 1, 1)].map(painter.center),
            itemSpawns: [SpecRect(10, 22, 1, 1), SpecRect(62, 42, 1, 1),
                         SpecRect(33, 43, 1, 1)].map(painter.center),
            fixedItems: [],
            enemySpawns: [
                (.wasp,           painter.center(SpecRect(52, 10, 1, 1))),
                (.wasp,           painter.center(SpecRect(66, 18, 1, 1))),
                (.raccoon,        painter.center(SpecRect(12, 20, 1, 1))),
                (.vendingMachine, painter.center(SpecRect(66, 44, 1, 1))),
                (.sternAdult,     painter.center(SpecRect(38, 21, 1, 1)))
            ],
            playerSpawn: painter.center(SpecRect(43, rows - 4, 1, 1)),
            benchPositions: [],
            zoneExitNodes: exits,
            quackNode: quack
        )
    }
}
