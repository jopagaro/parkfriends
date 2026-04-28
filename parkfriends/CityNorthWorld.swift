import SpriteKit

// Generated from MAP_SPEC.md §6 (scene `construction`).
// Stub: empty world with a player spawn. Fill in per spec.
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
        let tile = GameConstants.tileSize
        let spawn = CGPoint(
            x: CGFloat(GameConstants.cityNorthCols) * tile / 2,
            y: CGFloat(GameConstants.cityNorthRows) * tile / 2
        )
        return BuildResult(
            root: root,
            npcSpawns: [], itemSpawns: [], fixedItems: [], enemySpawns: [],
            playerSpawn: spawn,
            benchPositions: [], zoneExitNodes: [],
            quackNode: nil
        )
    }
}
