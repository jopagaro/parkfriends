import SpriteKit
import CoreGraphics

/// Chunk metadata from the design bible (Part 1.2).
struct MapChunk: Sendable {
    let id: String
    let name: String
    let narrative: String
    let col0: Int
    let row0: Int
    let width: Int
    let height: Int

    func contains(col: Int, row: Int) -> Bool {
        col >= col0 && col < col0 + width && row >= row0 && row < row0 + height
    }
}

// MARK: - Zone 1A / 1B split (row index local to each park map; north = higher row)

/// **Zone 1B — Park Center** map height (fountain, amphitheater, entrance, dog run).
enum ParkCenterMap {
    static let cols = GameConstants.parkCenterCols
    static let rows = GameConstants.parkCenterRows
}

/// **Zone 1A — Park North** map height (pond, ruins, meadow, forest).
enum ParkNorthMap {
    static let cols = GameConstants.parkNorthCols
    static let rows = GameConstants.parkNorthRows
}

// MARK: - Park (shared chunk table uses “canonical” 72×54 coordinates: center = rows 0–31, north = rows 32–53)

enum ParkMapDesign {

    static let chunks: [MapChunk] = [
        MapChunk(id: "PK-01", name: "Park Entrance",
                 narrative: "City meets nature. Cracked walk, fence, dead flowers.",
                 col0: 28, row0: 2, width: 16, height: 10),
        MapChunk(id: "PK-02", name: "Fountain Plaza",
                 narrative: "Pigeons own the benches; sun-angled seating.",
                 col0: 28, row0: 20, width: 14, height: 12),
        MapChunk(id: "PK-03", name: "Pond Cluster",
                 narrative: "Rotten dock energy; 3-tile water edge blend.",
                 col0: 2, row0: 38, width: 18, height: 14),
        MapChunk(id: "PK-04", name: "Dog Run",
                 narrative: "Dirt worn into desire paths; fence gaps.",
                 col0: 44, row0: 6, width: 12, height: 10),
        MapChunk(id: "PK-05", name: "Amphitheater",
                 narrative: "2002 stone seats; last show 2004.",
                 col0: 2, row0: 14, width: 20, height: 16),
        MapChunk(id: "PK-06", name: "Puzzle Ruins",
                 narrative: "2011 public art; 16×16 brick bounds.",
                 col0: 52, row0: 36, width: 16, height: 16),
        MapChunk(id: "PK-07", name: "Meadow North",
                 narrative: "Maintenance skips it; mushrooms and hidden paths.",
                 col0: 20, row0: 40, width: 22, height: 14),
    ]

    static let shadeCenters: [(Int, Int)] = [
        (5, 44), (8, 43), (15, 42), (18, 44), (3, 48),
        (50, 38), (53, 40), (56, 42), (58, 38), (62, 39),
        (20, 16), (24, 20), (44, 18), (48, 22), (16, 32), (52, 32),
        (3, 15), (6, 14), (2, 25), (4, 28),
    ]

    static func chunk(at col: Int, row: Int) -> MapChunk? {
        chunks.first { $0.contains(col: col, row: row) }
    }

    // Canonical coords (full park): row 0 south … 53 north
    static func isRoadRow(_ row: Int) -> Bool { row == 0 }
    static func isSidewalkRow(_ row: Int) -> Bool { row == 1 }

    static func isPathCanonical(col: Int, row: Int) -> Bool {
        guard row >= 2, row < GameConstants.worldRowsFull else { return false }
        if (34...36).contains(col) { return true }
        if (25...27).contains(row) { return true }
        for i in 0..<12 {
            let c = 52 + i
            let r = 35 + i / 2
            if (c...c+1).contains(col), r == row { return true }
        }
        if (14..<22).contains(row), (10...11).contains(col) { return true }
        if chunks.first(where: { $0.id == "PK-04" })?.contains(col: col, row: row) == true {
            return true
        }
        return false
    }

    static func inPondCanonical(col: Int, row: Int) -> Bool {
        let tile = CGFloat(GameConstants.tileSize)
        func inEllipse(cx: CGFloat, cy: CGFloat, rw: CGFloat, rh: CGFloat) -> Bool {
            let px = (CGFloat(col) + 0.5) * tile
            let py = (CGFloat(row) + 0.5) * tile
            let dx = (px - cx) / rw
            let dy = (py - cy) / rh
            return dx * dx + dy * dy <= 1.0
        }
        let rows = CGFloat(GameConstants.worldRowsFull)
        if inEllipse(cx: 12 * tile, cy: (rows - 10) * tile, rw: 4.6 * tile, rh: 3.2 * tile) { return true }
        if inEllipse(cx: 55 * tile, cy: 30 * tile, rw: 2.7 * tile, rh: 1.9 * tile) { return true }
        return false
    }

    static func isStoneSlabCanonical(col: Int, row: Int) -> Bool {
        if let pk5 = chunks.first(where: { $0.id == "PK-05" }), pk5.contains(col: col, row: row) { return true }
        return false
    }

    static func wantsShadeGrassCanonical(col: Int, row: Int) -> Bool {
        for (sc, sr) in shadeCenters {
            let dc = col - sc
            let dr = row - sr
            if dc * dc + dr * dr <= 12 { return true }
        }
        if chunks.first(where: { $0.id == "PK-07" })?.contains(col: col, row: row) == true {
            return (col + row) % 5 == 0
        }
        return false
    }

    static func dogRunCanonical(col: Int, row: Int) -> Bool {
        chunks.first(where: { $0.id == "PK-04" })?.contains(col: col, row: row) == true
    }

    static func isWornPathCanonical(col: Int, row: Int) -> Bool {
        isPathCanonical(col: col, row: row)
            && ((col == 35 && row >= 20 && row <= 32) || (row == 26 && (28...42).contains(col)))
    }

    static func isBusyPathIntersectionCanonical(col: Int, row: Int) -> Bool {
        guard isPathCanonical(col: col, row: row) else { return false }
        return (col == 35 && row == 26) || (row == 26 && col == 35)
    }

    /// Map **center** local (0…71, 0…parkCenterRows-1) → canonical row for chunk/path logic.
    static func canonicalRowForCenter(localRow: Int) -> Int { localRow }

    /// Map **north** local row → canonical row (offset by split).
    static func canonicalRowForNorth(localRow: Int) -> Int {
        GameConstants.parkNorthCanonicalRow0 + localRow
    }

    static func centerGroundColor(col: Int, localRow: Int) -> SKColor {
        let cr = canonicalRowForCenter(localRow: localRow)
        return WorldTerrain.parkTileColor(
            col: col, row: localRow, cols: ParkCenterMap.cols, rows: ParkCenterMap.rows,
            isRoadRow: isRoadRow,
            isSidewalkRow: isSidewalkRow,
            isPath: { c, r in isPathCanonical(col: c, row: canonicalRowForCenter(localRow: r)) },
            inPond: { _, _ in false },
            isStoneSlab: { c, r in isStoneSlabCanonical(col: c, row: canonicalRowForCenter(localRow: r)) },
            wantsShadeGrass: { c, r in wantsShadeGrassCanonical(col: c, row: canonicalRowForCenter(localRow: r)) },
            dogRunDirt: { c, r in dogRunCanonical(col: c, row: canonicalRowForCenter(localRow: r)) },
            isWornPath: { c, r in isWornPathCanonical(col: c, row: canonicalRowForCenter(localRow: r)) },
            isBusyPathIntersection: { c, r in isBusyPathIntersectionCanonical(col: c, row: canonicalRowForCenter(localRow: r)) },
            checker: { c, r in (c + r) % 2 == 0 }
        )
    }

    static func northGroundColor(col: Int, localRow: Int) -> SKColor {
        let canon = canonicalRowForNorth(localRow: localRow)
        return WorldTerrain.parkTileColor(
            col: col, row: localRow, cols: ParkNorthMap.cols, rows: ParkNorthMap.rows,
            isRoadRow: { _ in false },
            isSidewalkRow: { _ in false },
            isPath: { c, r in isPathCanonical(col: c, row: canonicalRowForNorth(localRow: r)) },
            inPond: { c, r in inPondCanonical(col: c, row: canonicalRowForNorth(localRow: r)) },
            isStoneSlab: { c, r in
                let ch = canonicalRowForNorth(localRow: r)
                if isStoneSlabCanonical(col: c, row: ch) { return true }
                if let pk6 = chunks.first(where: { $0.id == "PK-06" }), pk6.contains(col: c, row: ch) {
                    return true
                }
                return false
            },
            wantsShadeGrass: { c, r in wantsShadeGrassCanonical(col: c, row: canonicalRowForNorth(localRow: r)) },
            dogRunDirt: { c, r in dogRunCanonical(col: c, row: canonicalRowForNorth(localRow: r)) },
            isWornPath: { c, r in isWornPathCanonical(col: c, row: canonicalRowForNorth(localRow: r)) },
            isBusyPathIntersection: { c, r in isBusyPathIntersectionCanonical(col: c, row: canonicalRowForNorth(localRow: r)) },
            checker: { c, r in (c + r) % 2 == 0 }
        )
    }
}

// MARK: - City chunks (Zone 2A / 2 / 3)

enum CityMapDesign {
    // Matches GameConstants.cityCenterCols / cityCenterRows
    static let cols = GameConstants.cityCenterCols   // 88
    static let rows = GameConstants.cityCenterRows   // 65

    static let chunks: [MapChunk] = [
        MapChunk(id: "CT-01", name: "Corner Store",
                 narrative: "Open 24h; owner asleep 2–6am.",
                 col0: 22, row0: 10, width: 18, height: 14),
        MapChunk(id: "CT-02", name: "Main Street",
                 narrative: "Pothole older than your cousin.",
                 col0: 0, row0: 27, width: 88, height: 12),
        MapChunk(id: "CT-03", name: "Alley West",
                 narrative: "Raccoon municipal government.",
                 col0: 19, row0: 10, width: 10, height: 24),
        MapChunk(id: "CT-04", name: "Plaza East",
                 narrative: "Food cart stuck since 2019.",
                 col0: 30, row0: 40, width: 24, height: 18),
        MapChunk(id: "CT-05", name: "Apartment Row",
                 narrative: "Building C: do not knock.",
                 col0: 1, row0: 34, width: 32, height: 16),
        MapChunk(id: "CT-06", name: "Subway Entrance",
                 narrative: "Sign says UPTOWN; only goes to construction.",
                 col0: 36, row0: 1, width: 14, height: 10),
    ]

    static func chunk(at col: Int, row: Int) -> MapChunk? {
        chunks.first { $0.contains(col: col, row: row) }
    }

    // Scaled up from old 60×40 → new 88×65
    static func isSidewalk(col: Int, row: Int) -> Bool {
        if (30...31).contains(row) { return true }          // main crosswalk sidewalks
        if (40...49).contains(col) { return true }          // vertical street corridor
        if (6...7).contains(row) { return true }            // top sidewalk
        if (19...21).contains(col), (10...28).contains(row) { return true }
        if (66...68).contains(col), (10...28).contains(row) { return true }
        return false
    }

    static func isMainStreetRoad(col: Int, row: Int) -> Bool {
        guard (27...39).contains(row) else { return false }
        return !isSidewalk(col: col, row: row)
    }

    static func roadHasCenterLine(col: Int, row: Int) -> Bool {
        guard row == 33, !((40...49).contains(col)) else { return false }
        return isMainStreetRoad(col: col, row: row) && col % 4 < 2
    }

    static func isCrosswalkArea(col: Int, row: Int) -> Bool {
        (30...31).contains(row) && (39...52).contains(col)
    }

    static func isCrosswalkStripe(col: Int, row: Int) -> Bool {
        guard isCrosswalkArea(col: col, row: row) else { return false }
        return col % 3 != 0
    }

    static func isCurbLip(col: Int, row: Int) -> Bool {
        if row == 26 && isMainStreetRoad(col: col, row: 27) { return true }
        if row == 38 && isMainStreetRoad(col: col, row: 37) { return true }
        return false
    }

    static func groundColor(col: Int, row: Int) -> SKColor {
        WorldTerrain.cityTileColor(
            col: col, row: row, cols: cols, rows: rows,
            isSidewalk: isSidewalk,
            isMainStreetRoad: isMainStreetRoad,
            roadHasCenterLine: roadHasCenterLine,
            isCrosswalkArea: isCrosswalkArea,
            isCrosswalkStripe: isCrosswalkStripe,
            isCurbLip: isCurbLip,
            checker: { c, r in (c + r) % 2 == 0 }
        )
    }
}
