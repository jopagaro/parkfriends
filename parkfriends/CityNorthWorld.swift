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

        // Equipment + clutter.
        func prop(_ name: String, _ rect: SpecRect, block: Bool = true) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            if block { painter.addBlockingRect(rect) }
        }
        prop("prop-container-160x96", SpecRect(4, 26, 5, 3))
        prop("prop-container-160x96", SpecRect(16, 6, 5, 3))
        prop("prop-pipes-128x48",     SpecRect(30, 40, 4, 2))
        prop("prop-mound-96x64",      SpecRect(12, 22, 3, 2), block: false)
        prop("prop-mound-96x64",      SpecRect(56, 24, 3, 2), block: false)
        prop("prop-dumpster-96x64",   SpecRect(36, 6, 3, 2))
        prop("prop-trailer-192x128",  SpecRect(76, 38, 6, 4))
        prop("prop-pipes-128x48",     SpecRect(8, 38, 4, 2))
        prop("prop-mound-96x64",      SpecRect(48, 16, 3, 2), block: false)
        prop("prop-mound-96x64",      SpecRect(24, 8, 3, 2), block: false)
        prop("prop-dumpster-96x64",   SpecRect(60, 30, 3, 2))
        for (xT, yT) in [(20, 20), (23, 21), (26, 20), (40, 32), (43, 33), (46, 32),
                         (30, 14), (33, 15), (52, 28), (55, 29), (58, 28)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-cone-24x32"), layer: .decor)
        }
        for (xT, yT) in [(12, 12), (14, 13), (66, 22)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-barrel-32x40"), layer: .props)
        }
        // rubble around the dig + along the old-park grass edge
        for (xT, yT) in [(34, 12), (36, 13), (52, 36), (64, 10), (66, 7), (70, 11),
                         (78, 12), (84, 11)] {
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
            npcSpawns: [SpecRect(30, 30, 1, 1), SpecRect(56, 12, 1, 1)].map(painter.center),
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
