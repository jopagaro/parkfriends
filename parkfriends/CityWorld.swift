import SpriteKit

// Generated from MAP_SPEC.md §5 (scene `city_main`), adapted to 88×65.
// Downtown block grid: cafe/store/hospital on the north row, apartments,
// police HQ and the Development Corp tower below, streets between.
enum CityWorld {

    struct BuildResult {
        let root: SKNode
        let npcSpawns: [CGPoint]
        let itemSpawns: [CGPoint]
        let enemySpawns: [(EnemyKind, CGPoint)]
        let playerSpawn: CGPoint
        let benchPositions: [CGPoint]
        let zoneExitNodes: [ZoneExitNode]
    }

    static func build() -> BuildResult {
        let root = SKNode(); root.name = "world"
        let painter = ScenePainter(
            root: root,
            cols: GameConstants.cityCenterCols,
            rows: GameConstants.cityCenterRows
        )
        let cols = painter.cols, rows = painter.rows

        // L0 — concrete sidewalk everywhere, asphalt streets on top.
        for yT in 0..<rows { for xT in 0..<cols {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.parkStoneTile(variant: (xT * 7 + yT * 13) % 3),
                             z: PaintLayer.ground.z)
        } }
        // streets: two vertical, two horizontal (drive lanes 4 wide)
        let streets = [
            SpecRect(26, 0, 4, rows), SpecRect(58, 0, 4, rows),
            SpecRect(0, 20, cols, 4), SpecRect(0, 44, cols, 4),
            SpecRect(42, 0, 4, 20), SpecRect(42, 48, 4, rows - 48)   // exit spurs N + S
        ]
        for r in streets {
            for yT in r.y..<(r.y + r.h) { for xT in r.x..<(r.x + r.w) {
                let horizontal = r.h <= 4
                let isCenter = horizontal ? (yT == r.y + 2) : (xT == r.x + 2)
                let tex = isCenter
                    ? ImportedArt.genTile("tile-road-dash-32")
                    : ImportedArt.genTile("tile-road-\((xT + yT) % 2)-32")
                painter.place1x1(at: xT, yT, texture: tex, z: PaintLayer.ground.z + 0.1)
            } }
        }

        // Buildings (blocking rect = footprint).
        func building(_ name: String, _ rect: SpecRect) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            painter.addBlockingRect(rect)
        }
        building("bldg-cafe-256x192",      SpecRect(4, 12, 8, 6))
        building("bldg-store-256x192",     SpecRect(15, 12, 8, 6))
        building("bldg-hospital-256x224",  SpecRect(32, 11, 8, 7))
        building("bldg-store-256x192",     SpecRect(64, 12, 8, 6))
        building("bldg-apartment-256x256", SpecRect(4, 34, 8, 8))
        building("bldg-apartment-256x256", SpecRect(14, 34, 8, 8))
        building("bldg-police-256x224",    SpecRect(34, 35, 8, 7))
        building("bldg-devcorp-224x288",   SpecRect(66, 33, 7, 9))
        building("bldg-apartment-256x256", SpecRect(6, 54, 8, 8))
        building("bldg-cafe-256x192",      SpecRect(64, 56, 8, 6))

        // Street furniture: lamps, hydrants, trash cans, sidewalk trees, cars.
        for (xT, yT) in [(3, 19), (24, 19), (32, 19), (55, 19), (63, 19), (84, 19),
                         (3, 43), (24, 43), (32, 43), (55, 43), (63, 43), (84, 43)] {
            painter.placeSprite(SpecRect(xT, yT - 1, 1, 2),
                                texture: ImportedArt.lampTexture(city: true), layer: .props)
        }
        for (xT, yT) in [(13, 19), (48, 43), (75, 19)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-hydrant-24x36"), layer: .props)
        }
        for (xT, yT) in [(24, 25), (52, 25), (13, 49), (75, 49)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-trashcan-32x48"), layer: .props)
        }
        for (xT, yT) in [(8, 26), (50, 26), (20, 50), (80, 26)] {
            painter.placeTree(SpecRect(xT, yT, 2, 3), texture: ImportedArt.parkSmallConifer())
        }
        // parked cars
        for (xT, yT, name) in [(8, 21, "prop-car-red-96x48"), (48, 21, "prop-car-blue-96x48"),
                               (70, 45, "prop-car-red-96x48")] {
            painter.placeSprite(SpecRect(xT, yT, 3, 2), texture: ImportedArt.genTile(name), layer: .props)
        }
        // police cruiser outside HQ
        painter.placeSprite(SpecRect(36, 44, 3, 2),
                            texture: ImportedArt.genTile("prop-car-police-96x48"), layer: .props)

        // Benches near the hospital plaza.
        let benchTex = ImportedArt.genTile("prop-bench-64x40")
        let benchSpots = [(46, 26), (14, 26)]
        for (xT, yT) in benchSpots {
            painter.placeSprite(SpecRect(xT, yT, 2, 1), texture: benchTex, layer: .props)
        }

        painter.addSceneBoundary()

        // Exits: north spur → construction, south spur → city south.
        var exits: [ZoneExitNode] = []
        let nExit = ZoneExitNode(
            destination: .cityNorth,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "Construction"
        )
        nExit.position = painter.center(SpecRect(42, 0, 4, 1))
        root.addChild(nExit); exits.append(nExit)
        let sExit = ZoneExitNode(
            destination: .citySouth,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "City South"
        )
        sExit.position = painter.center(SpecRect(42, rows - 1, 4, 1))
        root.addChild(sExit); exits.append(sExit)

        let npcSpawns: [CGPoint] = [
            SpecRect(20, 27, 1, 1), SpecRect(50, 28, 1, 1), SpecRect(70, 50, 1, 1),
            SpecRect(10, 50, 1, 1), SpecRect(46, 52, 1, 1)
        ].map(painter.center)
        let itemSpawns: [CGPoint] = [
            SpecRect(6, 28, 1, 1), SpecRect(80, 28, 1, 1), SpecRect(30, 52, 1, 1),
            SpecRect(60, 28, 1, 1)
        ].map(painter.center)
        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.pigeon,        painter.center(SpecRect(16, 24, 1, 1))),
            (.pigeon,        painter.center(SpecRect(52, 30, 1, 1))),
            (.sternAdult,    painter.center(SpecRect(70, 28, 1, 1))),
            (.skateboardKid, painter.center(SpecRect(24, 52, 1, 1))),
            (.vendingMachine, painter.center(SpecRect(45, 33, 1, 1)))
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawns,
            enemySpawns: enemySpawns,
            playerSpawn: painter.center(SpecRect(43, rows - 4, 1, 1)),
            benchPositions: benchSpots.map { painter.center(SpecRect($0.0, $0.1, 1, 1)) },
            zoneExitNodes: exits
        )
    }
}
