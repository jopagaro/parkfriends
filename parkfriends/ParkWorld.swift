import SpriteKit

// Generated from MAP_SPEC.md.
// - buildCenter() → MAP_SPEC §4 (scene `park`)
// - buildNorth()  → MAP_SPEC §3 (scene `suburb_north`)
// Stub: returns an empty world with a player spawn. Fill in per spec one scene at a time.
enum ParkWorld {

    struct BuildResult {
        let root: SKNode
        let npcSpawns: [CGPoint]
        let itemSpawns: [CGPoint]
        let fixedItems: [(ItemKind, CGPoint)]
        let enemySpawns: [(EnemyKind, CGPoint)]
        let playerSpawn: CGPoint
        let benchPositions: [CGPoint]
        let zoneExitNodes: [ZoneExitNode]
        let pressurePlate: PressurePlateNode?
        let gate: GateNode?
        let chest: TreasureChestNode?
        let boulder: PushableRockNode?
    }

    static func buildCenter() -> BuildResult {
        emptyWorld(cols: GameConstants.parkCenterCols, rows: GameConstants.parkCenterRows)
    }

    static func buildNorth() -> BuildResult {
        emptyWorld(cols: GameConstants.parkNorthCols, rows: GameConstants.parkNorthRows)
    }

    private static func emptyWorld(cols: Int, rows: Int) -> BuildResult {
        let root = SKNode(); root.name = "world"
        let tile = GameConstants.tileSize
        let spawn = CGPoint(x: CGFloat(cols) * tile / 2, y: CGFloat(rows) * tile / 2)
        return BuildResult(
            root: root,
            npcSpawns: [], itemSpawns: [], fixedItems: [], enemySpawns: [],
            playerSpawn: spawn,
            benchPositions: [], zoneExitNodes: [],
            pressurePlate: nil, gate: nil, chest: nil, boulder: nil
        )
    }
}
