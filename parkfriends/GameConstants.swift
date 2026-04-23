import CoreGraphics

enum GameConstants {
    static let tileSize: CGFloat = 48
    static let worldCols: Int = 40
    static let worldRows: Int = 30

    static var worldSize: CGSize {
        CGSize(
            width: CGFloat(worldCols) * tileSize,
            height: CGFloat(worldRows) * tileSize
        )
    }

    enum Category {
        static let none: UInt32         = 0
        static let player: UInt32       = 1 << 0
        static let wall: UInt32         = 1 << 1
        static let item: UInt32         = 1 << 2
        static let npc: UInt32          = 1 << 3
        static let enemy: UInt32        = 1 << 4
        static let interact: UInt32     = 1 << 5
        static let attack: UInt32       = 1 << 6   // player attack hitbox / projectile
        static let pushable: UInt32     = 1 << 7   // boulder you can shove
        static let pressurePlate: UInt32 = 1 << 8  // puzzle trigger (sensor)
        static let gate: UInt32         = 1 << 9   // puzzle gate (blocks until opened)
    }

    enum ZPos {
        static let ground: CGFloat  = 0
        static let decor: CGFloat   = 5
        static let item: CGFloat    = 10
        static let entity: CGFloat  = 20
        static let effect: CGFloat  = 30   // damage numbers, attack flashes
        static let ui: CGFloat      = 100
    }

}
