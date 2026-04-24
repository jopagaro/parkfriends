import SpriteKit

/// Logical surface types for Part 2 edge matrix (§2.5).
enum TerrainSurface: Equatable {
    case grass
    case grassShade
    case path
    case sidewalk
    case road
    case water
    case stone
    case asphalt
}

/// Resolves tile colors using bible families + neighbor blends (G7/G8, D5, W4/W5).
enum WorldTerrain {

    // MARK: - Park

    static func parkSurface(
        col: Int, row: Int, cols: Int, rows: Int,
        isRoadRow: (Int) -> Bool,
        isSidewalkRow: (Int) -> Bool,
        isPath: (Int, Int) -> Bool,
        inPond: (Int, Int) -> Bool,
        isStoneSlab: (Int, Int) -> Bool,
        wantsShadeGrass: (Int, Int) -> Bool,
        dogRunDirt: (Int, Int) -> Bool
    ) -> TerrainSurface {
        if isRoadRow(row) { return .road }
        if isSidewalkRow(row) { return .sidewalk }
        if inPond(col, row) { return .water }
        if isStoneSlab(col, row) { return .stone }
        if isPath(col, row) { return .path }
        if dogRunDirt(col, row) { return .path }
        if wantsShadeGrass(col, row) { return .grassShade }
        return .grass
    }

    /// Two-pass: base fill then edge blend when grass↔path, path↔grass, water↔grass.
    static func parkTileColor(
        col: Int, row: Int, cols: Int, rows: Int,
        isRoadRow: (Int) -> Bool,
        isSidewalkRow: (Int) -> Bool,
        isPath: (Int, Int) -> Bool,
        inPond: (Int, Int) -> Bool,
        isStoneSlab: (Int, Int) -> Bool,
        wantsShadeGrass: (Int, Int) -> Bool,
        dogRunDirt: (Int, Int) -> Bool,
        isWornPath: (Int, Int) -> Bool,
        isBusyPathIntersection: (Int, Int) -> Bool,
        checker: (Int, Int) -> Bool
    ) -> SKColor {
        func surf(_ c: Int, _ r: Int) -> TerrainSurface {
            guard c >= 0, c < cols, r >= 0, r < rows else { return .grass }
            return parkSurface(
                col: c, row: r, cols: cols, rows: rows,
                isRoadRow: isRoadRow, isSidewalkRow: isSidewalkRow,
                isPath: isPath, inPond: inPond, isStoneSlab: isStoneSlab,
                wantsShadeGrass: wantsShadeGrass, dogRunDirt: dogRunDirt
            )
        }

        let me = surf(col, row)

        switch me {
        case .road:
            return checker(col, row) ? GamePalette.roadR1 : GamePalette.roadR2
        case .sidewalk:
            let crack = (col * 7 + row * 11) % 19 == 0
            if crack { return GamePalette.sidewalkCrack }
            return checker(col, row) ? GamePalette.sidewalk1 : GamePalette.sidewalk2
        case .water:
            let hi = (col + row * 3) % 4 == 0
            if hi { return GamePalette.waterHighlight }
            return checker(col, row) ? GamePalette.waterMid : GamePalette.waterDeep
        case .stone:
            return checker(col, row)
                ? SKColor(red: 0.62, green: 0.60, blue: 0.56, alpha: 1)
                : SKColor(red: 0.58, green: 0.56, blue: 0.52, alpha: 1)
        case .grass, .grassShade:
            var base: SKColor = (me == .grassShade) ? GamePalette.grassG3 : (checker(col, row) ? GamePalette.grassG1 : GamePalette.grassG2)
            if me == .grass && (col + row * 3) % 17 == 0 { base = GamePalette.grassG4Worn }

            let nPathW = surf(col - 1, row) == .path
            let nPathE = surf(col + 1, row) == .path
            let nPathN = surf(col, row + 1) == .path
            let nPathS = surf(col, row - 1) == .path
            let nWaterN = surf(col, row + 1) == .water
            let nWaterS = surf(col, row - 1) == .water
            let nWaterW = surf(col - 1, row) == .water
            let nWaterE = surf(col + 1, row) == .water

            if me != .grassShade {
                if nPathW { return GamePalette.grassPathWest }
                if nPathE { return GamePalette.grassPathEast }
                if nWaterN || nWaterS || nWaterW || nWaterE { return GamePalette.waterGrassNorthBlend }
            }
            return base

        case .path:
            var base: SKColor
            if isWornPath(col, row) {
                base = checker(col, row) ? GamePalette.dirtD3 : GamePalette.dirtD2
            } else {
                base = checker(col, row) ? GamePalette.dirtD1 : GamePalette.dirtD2
            }
            let nGrassW = surf(col - 1, row) == .grass || surf(col - 1, row) == .grassShade
            let nGrassE = surf(col + 1, row) == .grass || surf(col + 1, row) == .grassShade
            let nGrassN = surf(col, row + 1) == .grass || surf(col, row + 1) == .grassShade
            let nGrassS = surf(col, row - 1) == .grass || surf(col, row - 1) == .grassShade
            if nGrassW || nGrassE || nGrassN || nGrassS {
                base = GamePalette.dirtGrassEdge
            }
            let nWaterW = surf(col - 1, row) == .water
            let nWaterE = surf(col + 1, row) == .water
            let nWaterN = surf(col, row + 1) == .water
            let nWaterS = surf(col, row - 1) == .water
            if nWaterW || nWaterE || nWaterN || nWaterS {
                base = GamePalette.waterDirtEdgeBlend
            }
            if isBusyPathIntersection(col, row) { return GamePalette.dirtFootprints }
            if (nGrassW != nGrassE) && (surf(col, row) == .path) && ((col + row) % 3 == 0) {
                return GamePalette.dirtPathCrack
            }
            return base

        case .asphalt:
            return checker(col, row) ? GamePalette.asphalt1 : GamePalette.asphalt2
        }
    }

    // MARK: - City

    static func cityTileColor(
        col: Int, row: Int, cols: Int, rows: Int,
        isSidewalk: (Int, Int) -> Bool,
        isMainStreetRoad: (Int, Int) -> Bool,
        roadHasCenterLine: (Int, Int) -> Bool,
        isCrosswalkArea: (Int, Int) -> Bool,
        isCrosswalkStripe: (Int, Int) -> Bool,
        isCurbLip: (Int, Int) -> Bool,
        checker: (Int, Int) -> Bool
    ) -> SKColor {
        if isCrosswalkArea(col, row) {
            return isCrosswalkStripe(col, row) ? GamePalette.crosswalkStripe : GamePalette.roadR1
        }
        if isCurbLip(col, row) {
            return GamePalette.curbLip
        }
        if isSidewalk(col, row) {
            let crack = (col * 5 + row * 13) % 23 == 0
            if crack { return GamePalette.sidewalkCrack }
            let curb = isMainStreetRoad(col, row + 1) || isMainStreetRoad(col, row - 1)
            if curb { return GamePalette.sidewalkCurb }
            return checker(col, row) ? GamePalette.sidewalk1 : GamePalette.sidewalk2
        }
        if isMainStreetRoad(col, row) {
            if roadHasCenterLine(col, row) {
                return GamePalette.roadWithLine
            }
            return checker(col, row) ? GamePalette.roadR1 : GamePalette.roadR2
        }
        return checker(col, row) ? GamePalette.asphalt1 : GamePalette.asphalt2
    }
}
