import SpriteKit

// City South (88×42): the frayed edge where the park meets the city.
// Grass gives way to concrete, the corner store anchors the southwest,
// and raccoon-governed alleys run between brownstones. Park exit north,
// city center exit south.
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
        painter.fillGrass(rect: SpecRect(0, 0, cols, 6))
        // dirt path continues from the park gap down to the road
        painter.autotile(painter.tiles([SpecRect(44, 0, 4, 14)]),
                         z: PaintLayer.ground.z + 0.2,
                         interior: { ImportedArt.genTile("tile-dirt-\(($0 * 5 + $1 * 3) % 3)-32") },
                         tile: ImportedArt.parkPathBlobTile)

        // Cross street through the middle.
        let road = SpecRect(0, 14, cols, 4)
        for yT in road.y..<(road.y + road.h) { for xT in 0..<cols {
            let tex = yT == road.y + 2
                ? ImportedArt.genTile("tile-road-dash-32")
                : ImportedArt.genTile("tile-road-\((xT + yT) % 2)-32")
            painter.place1x1(at: xT, yT, texture: tex, z: PaintLayer.ground.z + 0.1)
        } }
        // zebra crosswalk where the park path crosses the road
        for yT in 14..<18 { for xT in 44..<48 {
            painter.place1x1(at: xT, yT,
                             texture: ImportedArt.genTile("tile-road-cross-32"),
                             z: PaintLayer.ground.z + 0.15)
        } }
        // south spur to city center
        for yT in 18..<rows { for xT in 44..<48 {
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
        // Corner store (shopkeeper NPC stands at its door — GameScene pins
        // them at tile (22, SK y=8) ≈ row 34).
        building("bldg-store-256x192", SpecRect(17, 26, 8, 6), door: .store)
        // Alley block: two brownstones with a dumpster alley between.
        building("bldg-apartment-256x256", SpecRect(54, 22, 8, 8), door: .apartment)
        building("bldg-apartment-256x256", SpecRect(66, 22, 8, 8), door: .apartment)
        painter.placeSprite(SpecRect(62, 24, 3, 2),
                            texture: ImportedArt.genTile("prop-dumpster-96x64"), layer: .props)
        painter.addBlockingRect(SpecRect(62, 24, 3, 2))
        painter.placeSprite(SpecRect(63, 27, 1, 1),
                            texture: ImportedArt.genTile("prop-trashcan-32x48"), layer: .props)
        // North-row buildings framing the park entrance (kept one row off
        // the road so the door trigger sits on sidewalk, not asphalt).
        building("bldg-apartment-256x256", SpecRect(6, 5, 8, 8), door: .apartment)
        building("bldg-cafe-256x192", SpecRect(70, 6, 8, 6), door: .cafe)

        // Street furniture.
        for (xT, yT) in [(6, 13), (30, 13), (60, 13), (80, 13), (30, 31), (70, 31)] {
            painter.placeSprite(SpecRect(xT, yT - 1, 1, 2),
                                texture: ImportedArt.lampTexture(city: true), layer: .props)
        }
        painter.placeSprite(SpecRect(36, 19, 3, 2),
                            texture: ImportedArt.genTile("prop-car-blue-96x48"), layer: .props)
        painter.placeSprite(SpecRect(12, 19, 1, 1),
                            texture: ImportedArt.genTile("prop-hydrant-24x36"), layer: .props)
        painter.placeSprite(SpecRect(28, 11, 1, 2),
                            texture: ImportedArt.genTile("prop-phonebooth-40x80"), layer: .props)
        painter.addBlockingRect(SpecRect(28, 12, 1, 1))
        for (xT, yT) in [(30, 20), (68, 20)] {
            painter.placeSprite(SpecRect(xT, yT, 2, 1),
                                texture: ImportedArt.genTile("prop-planter-64x48"), layer: .props)
            painter.addBlockingRect(SpecRect(xT, yT, 2, 1))
        }
        for (xT, yT) in [(52, 8), (32, 34)] {
            painter.placeTree(SpecRect(xT, yT, 2, 3), texture: ImportedArt.parkSmallConifer())
        }

        painter.addSceneBoundary()

        var exits: [ZoneExitNode] = []
        let nExit = ZoneExitNode(
            destination: .parkCenter,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "Park"
        )
        nExit.position = painter.center(SpecRect(44, 0, 4, 1))
        root.addChild(nExit); exits.append(nExit)
        let sExit = ZoneExitNode(
            destination: .cityCenter,
            triggerSize: CGSize(width: GameConstants.tileSize * 4, height: GameConstants.tileSize),
            arrowCount: 5, edgeLabel: "City Center"
        )
        sExit.position = painter.center(SpecRect(44, rows - 1, 4, 1))
        root.addChild(sExit); exits.append(sExit)

        let benchSpots = [(50, 34)]
        painter.placeSprite(SpecRect(50, 34, 2, 1),
                            texture: ImportedArt.genTile("prop-bench-64x40"), layer: .props)

        return BuildResult(
            root: root,
            npcSpawns: [SpecRect(30, 22, 1, 1), SpecRect(58, 34, 1, 1),
                        SpecRect(14, 22, 1, 1)].map(painter.center),
            itemSpawns: [SpecRect(64, 26, 1, 1), SpecRect(8, 30, 1, 1),
                         SpecRect(78, 20, 1, 1)].map(painter.center),
            enemySpawns: [
                (.raccoon, painter.center(SpecRect(63, 29, 1, 1))),
                (.pigeon,  painter.center(SpecRect(30, 10, 1, 1))),
                (.pigeon,  painter.center(SpecRect(70, 34, 1, 1)))
            ],
            playerSpawn: painter.center(SpecRect(46, 3, 1, 1)),
            benchPositions: benchSpots.map { painter.center(SpecRect($0.0, $0.1, 1, 1)) },
            zoneExitNodes: exits
        )
    }
}
