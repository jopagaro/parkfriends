import SpriteKit

// City South (60×30, compact per EB density rules): the frayed edge where
// the park meets the city. Corner store anchors the south side, brownstone
// pair with a dumpster alley east, apartment + cafe framing the park gate.
// Park exit north, city center exit south.
enum CitySouthWorld {

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
            cols: GameConstants.citySouthCols,
            rows: GameConstants.citySouthRows
        )
        let cols = painter.cols, rows = painter.rows

        // L0 — concrete base with a grass fringe along the park (north) edge.
        for yT in 0..<rows { for xT in 0..<cols {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.parkStoneTile(variant: (xT * 5 + yT * 11) % 3),
                             z: PaintLayer.ground.z)
        } }
        painter.fillGrass(rect: SpecRect(0, 0, cols, 4))
        // dirt path continues from the park gap down to the road
        painter.autotile(painter.tiles([SpecRect(28, 0, 4, 11)]),
                         z: PaintLayer.ground.z + 0.2,
                         interior: { ImportedArt.genTile("tile-dirt-\(($0 * 5 + $1 * 3) % 3)-32") },
                         tile: ImportedArt.parkPathBlobTile)

        // Cross street through the middle.
        let road = SpecRect(0, 11, cols, 4)
        for yT in road.y..<(road.y + road.h) { for xT in 0..<cols {
            let tex = yT == road.y + 2
                ? ImportedArt.genTile("tile-road-dash-32")
                : ImportedArt.genTile("tile-road-\((xT + yT) % 2)-32")
            painter.place1x1(at: xT, yT, texture: tex, z: PaintLayer.ground.z + 0.1)
        } }
        // zebra crosswalk where the park path crosses the road
        for yT in 11..<15 { for xT in 28..<32 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-road-cross-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }
        // south spur to city center
        for yT in 15..<rows { for xT in 28..<32 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-road-\((xT + yT) % 2)-32"),
                             z: PaintLayer.ground.z + 0.1)
        } }

        func building(_ name: String, _ rect: SpecRect, door interior: InteriorKind? = nil) {
            painter.placeSprite(rect, texture: ImportedArt.genTile(name), layer: .props)
            painter.addBlockingRect(rect)
            if let interior {
                DoorNode.place(interior,
                               at: SpecRect(rect.x + rect.w / 2 - 1, rect.y + rect.h, 2, 1),
                               in: root, painter: painter)
            }
        }
        // North row framing the park gate.
        building("bldg-apartment-256x256", SpecRect(4, 2, 8, 8), door: .apartment)
        building("bldg-cafe-256x192", SpecRect(46, 4, 8, 6), door: .cafe)
        // Corner store (shopkeeper stands by its door, pinned in GameScene).
        building("bldg-store-256x192", SpecRect(8, 16, 8, 6), door: .store)
        // Brownstone pair with the raccoon-governed dumpster alley between.
        building("bldg-apartment-256x256", SpecRect(36, 16, 8, 8), door: .apartment)
        building("bldg-apartment-256x256", SpecRect(48, 16, 8, 8), door: .apartment)
        painter.placeSprite(SpecRect(44, 18, 3, 2),
                            texture: ImportedArt.genTile("prop-dumpster-96x64"), layer: .props)
        painter.addBlockingRect(SpecRect(44, 18, 3, 2))
        painter.placeSprite(SpecRect(45, 21, 1, 1),
                            texture: ImportedArt.genTile("prop-trashcan-32x48"), layer: .props)

        // Street furniture.
        for (xT, yT) in [(4, 10), (20, 10), (40, 10), (56, 10), (20, 24), (42, 27)] {
            painter.placeSprite(SpecRect(xT, yT - 1, 1, 2),
                                texture: ImportedArt.lampTexture(city: true), layer: .props)
        }
        painter.placeSprite(SpecRect(20, 15, 3, 2),
                            texture: ImportedArt.genTile("prop-car-blue-96x48"), layer: .props)
        painter.placeSprite(SpecRect(48, 12, 3, 2),
                            texture: ImportedArt.genTile("prop-car-red-96x48"), layer: .props)
        painter.placeSprite(SpecRect(6, 15, 1, 1),
                            texture: ImportedArt.genTile("prop-hydrant-24x36"), layer: .props)
        painter.placeSprite(SpecRect(14, 6, 1, 2),
                            texture: ImportedArt.genTile("prop-phonebooth-40x80"), layer: .props)
        painter.addBlockingRect(SpecRect(14, 7, 1, 1))
        for (xT, yT) in [(18, 16), (36, 27)] {
            painter.placeSprite(SpecRect(xT, yT, 2, 1),
                                texture: ImportedArt.genTile("prop-planter-64x48"), layer: .props)
            painter.addBlockingRect(SpecRect(xT, yT, 2, 1))
        }
        for (xT, yT) in [(24, 5), (18, 25)] {
            painter.placeTree(SpecRect(xT, yT, 2, 3), texture: ImportedArt.parkSmallConifer())
        }

        painter.addSceneBoundary()

        var exits: [ZoneExitNode] = []
        let nExit = ZoneExitNode(
            destination: .parkCenter,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "Park"
        )
        nExit.position = painter.center(SpecRect(28, 0, 4, 1))
        root.addChild(nExit); exits.append(nExit)
        let sExit = ZoneExitNode(
            destination: .cityCenter,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "City Center"
        )
        sExit.position = painter.center(SpecRect(28, rows - 1, 4, 1))
        root.addChild(sExit); exits.append(sExit)

        let benchSpots = [(24, 22)]
        painter.placeSprite(SpecRect(24, 22, 2, 1),
                            texture: ImportedArt.genTile("prop-bench-64x40"), layer: .props)

        return BuildResult(
            root: root,
            npcSpawns: [SpecRect(20, 18, 1, 1), SpecRect(40, 25, 1, 1),
                        SpecRect(10, 13, 1, 1)].map(painter.center),
            itemSpawns: [SpecRect(46, 20, 1, 1), SpecRect(5, 22, 1, 1),
                         SpecRect(54, 13, 1, 1)].map(painter.center),
            enemySpawns: [
                (.raccoon, painter.center(SpecRect(45, 22, 1, 1))),
                (.pigeon,  painter.center(SpecRect(20, 7, 1, 1))),
                (.pigeon,  painter.center(SpecRect(48, 26, 1, 1)))
            ],
            playerSpawn: painter.center(SpecRect(30, 2, 1, 1)),
            benchPositions: benchSpots.map { painter.center(SpecRect($0.0, $0.1, 1, 1)) },
            zoneExitNodes: exits
        )
    }
}
