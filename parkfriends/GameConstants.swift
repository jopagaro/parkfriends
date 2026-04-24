import CoreGraphics

enum GameConstants {
    static let tileSize: CGFloat = 48

    /// Legacy full-park height (1A+1B) for chunk tables & canonical coords.
    static let worldCols: Int = 105
    static let worldRowsFull: Int = 115

    /// Zone 1B — Park Center (south half toward city).
    static let parkCenterCols: Int = 105
    static let parkCenterRows: Int = 65

    /// Zone 1A — Park North (pond, ruins, meadow). Local row 0 = canonical row `parkNorthCanonicalRow0`.
    static let parkNorthCols: Int = 105
    static let parkNorthRows: Int = 50
    static let parkNorthCanonicalRow0: Int = 65

    static var worldSize: CGSize {
        CGSize(width: CGFloat(worldCols) * tileSize, height: CGFloat(worldRowsFull) * tileSize)
    }

    static var parkCenterWorldSize: CGSize {
        CGSize(width: CGFloat(parkCenterCols) * tileSize, height: CGFloat(parkCenterRows) * tileSize)
    }

    static var parkNorthWorldSize: CGSize {
        CGSize(width: CGFloat(parkNorthCols) * tileSize, height: CGFloat(parkNorthRows) * tileSize)
    }

    static let citySouthCols = 88
    static let citySouthRows = 42
    static let cityCenterCols = 88
    static let cityCenterRows = 65
    static let cityNorthCols = 88
    static let cityNorthRows = 48

    static var citySouthWorldSize: CGSize {
        CGSize(width: CGFloat(citySouthCols) * tileSize, height: CGFloat(citySouthRows) * tileSize)
    }
    static var cityCenterWorldSize: CGSize {
        CGSize(width: CGFloat(cityCenterCols) * tileSize, height: CGFloat(cityCenterRows) * tileSize)
    }
    static var cityNorthWorldSize: CGSize {
        CGSize(width: CGFloat(cityNorthCols) * tileSize, height: CGFloat(cityNorthRows) * tileSize)
    }

    enum Category {
        static let none:          UInt32 = 0
        static let player:        UInt32 = 1 << 0
        static let wall:          UInt32 = 1 << 1
        static let item:          UInt32 = 1 << 2
        static let npc:           UInt32 = 1 << 3
        static let enemy:         UInt32 = 1 << 4
        static let interact:      UInt32 = 1 << 5
        static let attack:        UInt32 = 1 << 6
        static let pushable:      UInt32 = 1 << 7
        static let pressurePlate: UInt32 = 1 << 8
        static let gate:          UInt32 = 1 << 9
        static let zoneExit:      UInt32 = 1 << 10
    }

    enum ZPos {
        static let ground:  CGFloat = 0
        static let decor:   CGFloat = 5
        static let item:    CGFloat = 10
        static let entity:  CGFloat = 20
        static let effect:  CGFloat = 30
        static let ui:      CGFloat = 100
        static let battle:  CGFloat = 200   // battle overlay on top of everything
    }
}
