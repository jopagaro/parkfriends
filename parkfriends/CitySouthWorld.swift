import SpriteKit

// Currently unmapped to MAP_SPEC. Folds into `city_main` (§5) or becomes a
// transition strip; decide before populating. Stub returns empty world.
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
        let tile = GameConstants.tileSize
        let spawn = CGPoint(
            x: CGFloat(GameConstants.citySouthCols) * tile / 2,
            y: CGFloat(GameConstants.citySouthRows) * tile / 2
        )
        return BuildResult(
            root: root,
            npcSpawns: [], itemSpawns: [], enemySpawns: [],
            playerSpawn: spawn,
            benchPositions: [], zoneExitNodes: []
        )
    }
}
