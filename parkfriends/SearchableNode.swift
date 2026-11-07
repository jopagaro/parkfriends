import SpriteKit

// MARK: - SearchableKind

/// One-time "check" spots in the EarthBound tradition: ordinary park
/// furniture that quietly holds an item. The joke is observational — the
/// prop looks slightly interfered-with, which in Bellwether Park it is.
enum SearchableKind: String {
    case trashCan
    case bush
    case flowerbed

    var texture: SKTexture? {
        switch self {
        case .trashCan:  ImportedArt.genTile("prop-trashcan-32x48")
        case .bush:      ImportedArt.genTile("prop-bush-0-32")
        case .flowerbed: ImportedArt.genTile("prop-flowerbed-96x40")
        }
    }

    var displaySize: CGSize {
        switch self {
        case .trashCan:  CGSize(width: 32, height: 48)
        case .bush:      CGSize(width: 44, height: 44)
        case .flowerbed: CGSize(width: 96, height: 40)
        }
    }

    /// Items worth finding — consumables and curios only, never story items.
    var lootPool: [ItemKind] {
        switch self {
        case .trashCan:  [.staleChip, .berry, .warmCola, .parkToken, .shinyThing]
        case .bush:      [.feather, .berry, .parkToken, .mysteryBag]
        case .flowerbed: [.parkToken, .berry, .juiceBox]
        }
    }

    /// Deadpan discovery lines; the found item gets announced after them.
    func flavorLines(variant: Int) -> [(speaker: String, text: String)] {
        switch self {
        case .trashCan:
            return [
                [("Shelly", "The trash in this can is sorted by size. Someone did that on purpose.")],
                [("Shelly", "The lid is balanced upside down. Raccoon work. Professional.")],
                [("Shelly", "There's a complaint form IN the can. Filed, technically.")]
            ][variant % 3]
        case .bush:
            return [
                [("Shelly", "The bush rustles back. Formal, but friendly.")],
                [("Shelly", "Something reorganized this bush from the inside.")],
                [("Shelly", "Half the leaves point north. Bushes don't usually vote.")]
            ][variant % 3]
        case .flowerbed:
            return [
                [("Shelly", "Municipally maintained flowerbed. The flowers disagree.")],
                [("Shelly", "The tulips are planted in a pattern. It might be a word.")],
                [("Shelly", "Someone watered exactly half of this.")]
            ][variant % 3]
        }
    }
}

// MARK: - SearchableNode

/// A placed searchable prop. Proximity + the talk button searches it once;
/// the find is remembered in GameState.searchedSpots forever.
@MainActor
final class SearchableNode: SKSpriteNode {
    let kind: SearchableKind
    let spotID: String

    /// Deterministic loot: the spot id seeds the pick so the find is stable
    /// across sessions — it feels authored, not rolled.
    var loot: ItemKind {
        var h: UInt64 = 1469598103934665603
        for b in spotID.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let pool = kind.lootPool
        return pool[Int(h % UInt64(pool.count))]
    }

    var flavorVariant: Int {
        var h: UInt64 = 14695981039346656037 % 1000000007
        for b in spotID.utf8 { h = (h &+ UInt64(b)) &* 31 }
        return Int(h % 3)
    }

    init(kind: SearchableKind, zone: GameZone, position: CGPoint) {
        self.kind = kind
        let px = Int(position.x.rounded()), py = Int(position.y.rounded())
        self.spotID = "search::\(zone.rawValue)::\(kind.rawValue)::\(px)x\(py)"
        super.init(texture: kind.texture, color: .clear, size: kind.displaySize)
        self.position  = position
        name           = "searchable"
        zPosition      = GameConstants.ZPos.entity - 0.1
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    /// Small acknowledging hop when searched.
    func playSearchBounce() {
        run(.sequence([
            .scaleY(to: 0.85, duration: 0.07),
            .scaleY(to: 1.06, duration: 0.09),
            .scaleY(to: 1.0, duration: 0.07)
        ]))
    }
}
