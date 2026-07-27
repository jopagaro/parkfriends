import SpriteKit

// City Center (64×48, compact per EB density rules): a tight downtown
// grid — shops on the north row, apartments + police + Development Corp
// in the middle band, cafe row south. Streets are corridors between
// buildings, not oceans. North spur → construction, south → city south.
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
        // streets: two vertical avenues, two horizontal, N+S exit spurs
        let streets = [
            SpecRect(14, 0, 4, rows), SpecRect(46, 0, 4, rows),
            SpecRect(0, 14, cols, 4), SpecRect(0, 32, cols, 4),
            SpecRect(30, 0, 4, 14), SpecRect(30, 36, 4, rows - 36)
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
        // zebra crosswalks on the walking routes
        let crossings = [
            SpecRect(7, 14, 2, 4), SpecRect(26, 14, 2, 4), SpecRect(56, 14, 2, 4),
            SpecRect(7, 32, 2, 4), SpecRect(26, 32, 2, 4), SpecRect(56, 32, 2, 4),
            SpecRect(30, 14, 4, 4), SpecRect(30, 32, 4, 4),
            SpecRect(14, 24, 4, 2), SpecRect(46, 24, 4, 2)
        ]
        for r in crossings {
            for yT in r.y..<(r.y + r.h) { for xT in r.x..<(r.x + r.w) {
                painter.place1x1(at: xT, yT,
                                 texture: ImportedArt.genTile("tile-road-cross-32"),
                                 z: PaintLayer.ground.z + 0.15)
            } }
        }

        // Buildings (blocking rect = footprint, door trigger below the facade).
        func building(_ name: String, _ rect: SpecRect, door interior: InteriorKind? = nil) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            painter.addBlockingRect(rect)
            if let interior {
                DoorNode.place(interior,
                               at: SpecRect(rect.x + rect.w / 2 - 1, rect.y + rect.h, 2, 1),
                               in: root, painter: painter)
            }
        }
        // North row (shops face the first street).
        building("bldg-cafe-256x192",      SpecRect(3, 6, 8, 6),   door: .cafe)
        building("bldg-hospital-256x224",  SpecRect(20, 5, 8, 7),  door: .hospital)
        building("bldg-store-256x192",     SpecRect(36, 6, 8, 6),  door: .store)
        building("bldg-store-256x192",     SpecRect(52, 6, 8, 6),  door: .store)
        // Middle band between the streets.
        building("bldg-apartment-256x256", SpecRect(2, 19, 8, 8),  door: .apartment)
        building("bldg-police-256x224",    SpecRect(20, 20, 8, 7), door: .police)
        building("bldg-devcorp-224x288",   SpecRect(36, 19, 7, 9))   // locked until the story says so
        building("bldg-apartment-256x256", SpecRect(52, 19, 8, 8), door: .apartment)
        // South row.
        building("bldg-apartment-256x256", SpecRect(3, 37, 8, 8),  door: .apartment)
        building("bldg-cafe-256x192",      SpecRect(20, 38, 8, 6), door: .cafe)
        building("bldg-store-256x192",     SpecRect(52, 38, 8, 6), door: .store)

        // Street furniture: lamps at corners, hydrants, trash, trees, cars.
        for (xT, yT) in [(2, 13), (20, 13), (44, 13), (61, 13),
                         (2, 31), (20, 31), (44, 31), (61, 31)] {
            painter.placeSprite(SpecRect(xT, yT - 1, 1, 2),
                                texture: ImportedArt.lampTexture(city: true), layer: .props)
        }
        for (xT, yT) in [(12, 13), (50, 31)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-hydrant-24x36"), layer: .props)
        }
        for (xT, yT) in [(12, 19), (34, 30), (5, 35), (58, 35)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 1),
                                texture: ImportedArt.genTile("prop-trashcan-32x48"), layer: .props)
        }
        for (xT, yT) in [(11, 28), (44, 19), (34, 44), (12, 45)] {
            painter.placeTree(SpecRect(xT, yT, 2, 3), texture: ImportedArt.parkSmallConifer())
        }
        // parked cars + the police cruiser outside HQ
        for (xT, yT, name) in [(6, 15, "prop-car-red-96x48"), (38, 15, "prop-car-blue-96x48"),
                               (52, 33, "prop-car-red-96x48"), (10, 33, "prop-car-blue-96x48")] {
            painter.placeSprite(SpecRect(xT, yT, 3, 2), texture: ImportedArt.genTile(name), layer: .props)
        }
        painter.placeSprite(SpecRect(22, 33, 3, 2),
                            texture: ImportedArt.genTile("prop-car-police-96x48"), layer: .props)

        // Phone booths + flower planters — EB street dressing.
        for (xT, yT) in [(12, 8), (44, 27)] {
            painter.placeSprite(SpecRect(xT, yT, 1, 2),
                                texture: ImportedArt.genTile("prop-phonebooth-40x80"), layer: .props)
            painter.addBlockingRect(SpecRect(xT, yT + 1, 1, 1))
        }
        for (xT, yT) in [(4, 12), (30, 19), (34, 12), (46, 44)] {
            painter.placeSprite(SpecRect(xT, yT, 2, 1),
                                texture: ImportedArt.genTile("prop-planter-64x48"), layer: .props)
            painter.addBlockingRect(SpecRect(xT, yT, 2, 1))
        }
        // Benches: pocket plaza beside Development Corp + street corners.
        let benchTex = ImportedArt.genTile("prop-bench-64x40")
        let benchSpots = [(45, 21), (45, 29), (12, 24), (34, 41)]
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
        nExit.position = painter.center(SpecRect(30, 0, 4, 1))
        root.addChild(nExit); exits.append(nExit)
        let sExit = ZoneExitNode(
            destination: .citySouth,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "City South"
        )
        sExit.position = painter.center(SpecRect(30, rows - 1, 4, 1))
        root.addChild(sExit); exits.append(sExit)

        let npcSpawns: [CGPoint] = [
            SpecRect(8, 13, 1, 1), SpecRect(26, 19, 1, 1), SpecRect(50, 26, 1, 1),
            SpecRect(12, 37, 1, 1), SpecRect(36, 46, 1, 1), SpecRect(56, 13, 1, 1),
            SpecRect(44, 37, 1, 1)
        ].map(painter.center)
        let itemSpawns: [CGPoint] = [
            SpecRect(4, 26, 1, 1), SpecRect(58, 26, 1, 1), SpecRect(26, 45, 1, 1),
            SpecRect(40, 12, 1, 1)
        ].map(painter.center)
        let enemySpawns: [(EnemyKind, CGPoint)] = [
            (.pigeon,        painter.center(SpecRect(10, 18, 1, 1))),
            (.pigeon,        painter.center(SpecRect(38, 28, 1, 1))),
            (.sternAdult,    painter.center(SpecRect(52, 28, 1, 1))),
            (.skateboardKid, painter.center(SpecRect(16, 40, 1, 1))),
            (.vendingMachine, painter.center(SpecRect(33, 24, 1, 1)))
        ]

        return BuildResult(
            root: root,
            npcSpawns: npcSpawns,
            itemSpawns: itemSpawns,
            enemySpawns: enemySpawns,
            playerSpawn: painter.center(SpecRect(31, rows - 4, 1, 1)),
            benchPositions: benchSpots.map { painter.center(SpecRect($0.0, $0.1, 1, 1)) },
            zoneExitNodes: exits
        )
    }
}
