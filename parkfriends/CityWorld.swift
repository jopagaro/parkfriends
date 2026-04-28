import SpriteKit

// Generated from MAP_SPEC.md §5 (scene `city_main`).
// Stub: empty world with a player spawn. Fill in per spec.
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
        let tile = GameConstants.tileSize
        let spawn = CGPoint(
            x: CGFloat(GameConstants.cityCenterCols) * tile / 2,
            y: CGFloat(GameConstants.cityCenterRows) * tile / 2
        )
        return BuildResult(
            root: root,
            npcSpawns: [], itemSpawns: [], enemySpawns: [],
            playerSpawn: spawn,
            benchPositions: [], zoneExitNodes: []
        )
    }
}
