import SpriteKit
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
enum ImportedArt {
    private static var imageCache: [String: CGImage] = [:]
    private static var textureCache: [String: SKTexture] = [:]

    private static var projectRootURL: URL {
        // #filePath = .../parkfriends/parkfriends/ImportedArt.swift
        // Two levels up = .../parkfriends/  ← project root where textures.downloaded.sprites lives
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // → .../parkfriends/parkfriends/
            .deletingLastPathComponent()  // → .../parkfriends/
    }

    private static func cgImage(at relativePath: String) -> CGImage? {
        if let cached = imageCache[relativePath] { return cached }

        // ── Locate the file ───────────────────────────────────────────────────
        // Xcode's PBXFileSystemSynchronizedRootGroup copies ALL resources flat
        // into Contents/Resources/ — subdirectory structure is NOT preserved.
        // So we try three paths in order:
        //   1. filename-only in bundle resources  (the common case)
        //   2. full relative path in resources    (future-proof if structure preserved)
        //   3. full path via #filePath            (dev machine fallback, may be sandboxed)
        let resourceBase = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let filename     = URL(fileURLWithPath: relativePath).lastPathComponent
        let flatURL      = resourceBase.appendingPathComponent(filename)
        let fullBundleURL = resourceBase.appendingPathComponent(relativePath)
        let devURL       = projectRootURL.appendingPathComponent(relativePath)

        let fm = FileManager.default
        let url: URL
        if fm.fileExists(atPath: flatURL.path) {
            url = flatURL
        } else if fm.fileExists(atPath: fullBundleURL.path) {
            url = fullBundleURL
        } else if fm.fileExists(atPath: devURL.path) {
            url = devURL
        } else {
            print("⚠️ [ImportedArt] not found: \(filename)")
            return nil
        }

        // ── Decode ────────────────────────────────────────────────────────────
#if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: url.path)?.cgImage else {
            print("⚠️ [ImportedArt] UIImage decode failed: \(url.lastPathComponent)")
            return nil
        }
#elseif canImport(AppKit)
        guard let sourceImage = NSImage(contentsOf: url),
              let image = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("⚠️ [ImportedArt] NSImage decode failed: \(url.lastPathComponent)")
            return nil
        }
#endif

        imageCache[relativePath] = image
        return image
    }

    private static func croppedTexture(relativePath: String, rect: CGRect) -> SKTexture? {
        let key = "\(relativePath)#\(Int(rect.origin.x))_\(Int(rect.origin.y))_\(Int(rect.width))_\(Int(rect.height))"
        if let cached = textureCache[key] { return cached }
        guard let image = cgImage(at: relativePath), let crop = image.cropping(to: rect) else { return nil }
        let tex = SKTexture(cgImage: crop)
        tex.filteringMode = .nearest
        textureCache[key] = tex
        return tex
    }

    static func fileTexture(relativePath: String) -> SKTexture? {
        let key = "file:\(relativePath)"
        if let cached = textureCache[key] { return cached }
        guard let image = cgImage(at: relativePath) else { return nil }
        let tex = SKTexture(cgImage: image)
        tex.filteringMode = .nearest
        textureCache[key] = tex
        return tex
    }

    static func sheetTexture(relativePath: String, tileSize: CGSize, col: Int, row: Int) -> SKTexture? {
        guard let image = cgImage(at: relativePath) else { return nil }
        let pixelHeight = CGFloat(image.height)
        let rect = CGRect(
            x: CGFloat(col) * tileSize.width,
            y: pixelHeight - CGFloat(row + 1) * tileSize.height,
            width: tileSize.width,
            height: tileSize.height
        )
        return croppedTexture(relativePath: relativePath, rect: rect)
    }

    static func sheetTextureFromTop(relativePath: String, tileSize: CGSize, col: Int, rowFromTop: Int) -> SKTexture? {
        guard let image = cgImage(at: relativePath) else { return nil }
        let rows = Int(CGFloat(image.height) / tileSize.height)
        let rowFromBottom = max(0, rows - 1 - rowFromTop)
        return sheetTexture(relativePath: relativePath, tileSize: tileSize, col: col, row: rowFromBottom)
    }

    // MARK: - Sprout Lands terrain (single source of truth for world tiles)

    private static let sproutBase = "textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/"
    private static let genericPropsBase = "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/"
    private static let modernOldBase = "textures.downloaded.sprites/Modern tiles_Free/Old/"

    /// Plain grass — rows 0-1 of Grass.png (11×7 grid of 16×16).
    /// Cols 0-5 are solid-fill grass; cols 6-10 are lighter variants.
    static func sproutGrassTexture(variant: Int) -> SKTexture? {
        let v = abs(variant)
        let col = v % 6          // solid grass cols
        let row = (v / 6) % 2   // rows 0-1
        return sheetTexture(relativePath: "\(sproutBase)Tilesets/Grass.png",
                            tileSize: CGSize(width: 16, height: 16), col: col, row: row)
    }

    /// Shade grass — row 2 of Grass.png (darker fill patches).
    static func sproutShadeGrassTexture(variant: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(sproutBase)Tilesets/Grass.png",
                     tileSize: CGSize(width: 16, height: 16),
                     col: abs(variant) % 6, row: 2)
    }

    /// Dirt path — row 0 of Paths.png (4×4 grid of 16×16 worn-dirt tiles).
    static func sproutPathTexture(variant: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(sproutBase)Objects/Paths.png",
                     tileSize: CGSize(width: 16, height: 16),
                     col: abs(variant) % 4, row: 0)
    }

    static func sproutWaterTexture(variant: Int) -> SKTexture? {
        return sheetTexture(
            relativePath: "textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Tilesets/Water.png",
            tileSize: CGSize(width: 16, height: 16),
            col: abs(variant) % 4,
            row: 0
        )
    }

    static func sproutHillTexture(col: Int, row: Int) -> SKTexture? {
        sheetTexture(
            relativePath: "textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Tilesets/Hills.png",
            tileSize: CGSize(width: 16, height: 16),
            col: col,
            row: row
        )
    }

    static func sproutNatureTexture(for glyph: String) -> SKTexture? {
        let coords: (String, Int, Int)?
        switch glyph {
        case "🌿":
            coords = ("textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Basic Plants.png", 3, 0)
        case "🌷", "🌸", "🌺", "🌻":
            coords = ("textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Basic Plants.png", 2, 0)
        case "🍄":
            coords = ("textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Basic Grass Biom things 1.png", 5, 1)
        case "🌲":
            coords = ("textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Basic Grass Biom things 1.png", 7, 0)
        case "🌳":
            coords = ("textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Basic Grass Biom things 1.png", 8, 0)
        default:
            coords = nil
        }
        guard let (path, col, row) = coords else { return nil }
        return sheetTexture(relativePath: path, tileSize: CGSize(width: 16, height: 16), col: col, row: row)
    }

    static func sproutFenceTexture(col: Int, row: Int) -> SKTexture? {
        sheetTexture(
            relativePath: "textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Tilesets/Fences.png",
            tileSize: CGSize(width: 16, height: 16),
            col: col,
            row: row
        )
    }

    // MARK: - World park terrain (world.park/)

    private static let worldParkBase  = "textures.downloaded.sprites/world.park/"
    private static let worldSuburbBase = "textures.downloaded.sprites/world.suburb/"

    /// Pebbled dirt path fill tile (interior of golden cross-paths).
    /// Sheet is 64×64 = 4 cols × 4 rows of 16×16.
    /// col 1, row 1 = interior fill; col 0/3, row 0/3 = corners/edges.
    static func parkPathTile(col: Int = 1, row: Int = 1) -> SKTexture? {
        sheetTexture(relativePath: "\(worldParkBase)pixel-art-pebbled-brown-dirt-path-corner-and-edge-tileset-64x64.png",
                     tileSize: CGSize(width: 16, height: 16), col: col, row: row)
    }

    /// Solid blue pond water (32×32 single tile).
    static func pondWaterTile() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-solid-blue-water-pond-square-tile-32x32.png")
    }

    /// Pond shore / border tileset (64×64 = 4×4 grid of 16×16).
    static func pondShoreTile(col: Int, row: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(worldParkBase)pixel-art-blue-pond-water-border-corners-and-edges-tileset-64x64.png",
                     tileSize: CGSize(width: 16, height: 16), col: col, row: row)
    }

    /// Gray stone ground (single 16×16 tile). Pass cracked/mottled variant.
    static func parkStoneTile(variant: Int = 0) -> SKTexture? {
        switch variant % 3 {
        case 1:  return fileTexture(relativePath: "\(worldParkBase)pixel-art-gray-stone-ground-with-cracks-tile-16x16.png")
        case 2:  return fileTexture(relativePath: "\(worldParkBase)pixel-art-gray-stone-ground-with-mottled-texture-tile-16x16.png")
        default: return fileTexture(relativePath: "\(worldParkBase)pixel-art-gray-stone-ground-tile-16x16.png")
        }
    }

    /// Dark forest floor grass (single 16×16 tiles, 3 variants).
    static func darkGrassTile(variant: Int = 0) -> SKTexture? {
        switch variant % 3 {
        case 1:  return fileTexture(relativePath: "\(worldParkBase)pixel-art-dark-green-grass-with-bottom-sprouts-tile-16x16.png")
        case 2:  return fileTexture(relativePath: "\(worldParkBase)pixel-art-dark-green-grass-with-corner-sprouts-tile-16x16.png")
        default: return fileTexture(relativePath: "\(worldParkBase)pixel-art-dark-green-grass-with-small-sprouts-tile-16x16.png")
        }
    }

    /// Biom things sheet (144×80, 16×16 = 9 cols × 5 rows).
    /// Row 0: stones/crystals, logs; row 1-2: flowers, mushrooms; row 3-4: bushes/plants.
    static func parkBiomSprite(col: Int, row: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(worldParkBase)pixel-art-basic-grass-biome-props-flowers-rocks-bushes-mushrooms-and-plants-tileset-144x80.png",
                     tileSize: CGSize(width: 16, height: 16), col: col, row: row)
    }

    /// Large round green tree sprite (48×48 standalone PNG).
    static func parkLargeTree() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-large-round-green-tree-sprite-48x48.png")
    }

    /// Medium round green tree sprite (32×32 standalone PNG).
    static func parkMediumTree() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-medium-round-green-tree-sprite-32x32.png")
    }

    /// Wide medium round tree (32×32).
    static func parkWideTree() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-medium-wide-round-green-tree-sprite-32x32.png")
    }

    /// Tall conifer / pine sprite (32×48).
    static func parkTallConifer() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-tall-conical-green-tree-sprite-32x48.png")
    }

    /// Small conifer sprite (16×32).
    static func parkSmallConifer() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-small-conical-green-tree-sprite-16x32.png")
    }

    /// Complete suburban house exterior sprite (112×80).
    static func suburbHouseExterior() -> SKTexture? {
        fileTexture(relativePath: "\(worldSuburbBase)pixel-art-complete-small-wooden-house-exterior-sprite-112x80.png")
    }

    /// Wood post-and-rail fence tileset (64×64 = 4 cols × 4 rows of 16×16).
    static func woodFenceTile(col: Int, row: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(worldSuburbBase)pixel-art-wood-post-and-rail-fence-corners-and-segments-tileset-64x64.png",
                     tileSize: CGSize(width: 16, height: 16), col: col, row: row)
    }

    static func sproutBridgeTexture(col: Int, row: Int) -> SKTexture? {
        sheetTexture(
            relativePath: "textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Wood Bridge.png",
            tileSize: CGSize(width: 16, height: 16),
            col: col,
            row: row
        )
    }

    static func critterTexture(sheet: String, frame: Int) -> SKTexture? {
        sheetTexture(
            relativePath: "textures.downloaded.sprites/\(sheet)",
            tileSize: CGSize(width: 32, height: 32),
            col: frame % 4,
            row: frame / 4
        )
    }

    static func critterFrontTexture(sheet: String, rowFromTop: Int = 0, frame: Int = 0) -> SKTexture? {
        sheetTextureFromTop(
            relativePath: "textures.downloaded.sprites/\(sheet)",
            tileSize: CGSize(width: 32, height: 32),
            col: frame,
            rowFromTop: rowFromTop
        )
    }

    static func rpgCharTexture(relativePath: String, frame: Int, frameSize: CGSize = CGSize(width: 32, height: 32)) -> SKTexture? {
        sheetTexture(relativePath: relativePath, tileSize: frameSize, col: frame, row: 0)
    }

    // ── Human-character helper paths ────────────────────────────────────────
    // gabe / mani are 168×24 sheets = 7 cols × 1 row of *24×24* frames.
    // hat-guy / sensei / vendor are SINGLE-frame sprites — no sub-framing.
    private static let charBase = "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/"
    private static func gabeFrame(_ frame: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(charBase)gabe/gabe-idle-run.png",
                     tileSize: CGSize(width: 24, height: 24), col: frame % 7, row: 0)
    }
    private static func maniFrame(_ frame: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(charBase)mani/mani-idle-run.png",
                     tileSize: CGSize(width: 24, height: 24), col: frame % 7, row: 0)
    }
    private static func hatGuyTexture() -> SKTexture? {
        fileTexture(relativePath: "\(charBase)hat-guy/hat-guy.png")
    }
    private static func senseiTexture() -> SKTexture? {
        fileTexture(relativePath: "\(charBase)sensei/sensei.png")
    }
    private static func vendorTexture() -> SKTexture? {
        fileTexture(relativePath: "\(charBase)vendor/generic-rpg-vendor.png")
    }

    // ── Mana Seed Character Base v1 — char_a_p1_*.png ────────────────────────
    // 512×512 sheets, 8 cols × 8 rows of 64×64 cells.
    // 11 variants (v00–v10) used for: Mayor Johnson + pride-parade crowd (Act 3).
    // Frame indices follow the standard Mana Seed layout
    // (row 0 col 0 = south-facing idle pose, "frame 0" by convention).
    private static let manaSeedBase = "textures.downloaded.sprites/animation frames /pride parade charcters/"
    static func manaSeedCharTexture(variant: Int, frame: Int = 0) -> SKTexture? {
        let v = String(format: "%02d", abs(variant) % 11)
        return sheetTexture(relativePath: "\(manaSeedBase)char_a_p1_0bas_humn_v\(v).png",
                            tileSize: CGSize(width: 64, height: 64),
                            col: frame % 8, row: frame / 8)
    }

    // ── Wizard grunts (Act 6) — two variants from generic-rpg-pack ───────────
    // Both sources are single-frame sprites, so frame param is ignored.
    static func wizardTexture(variant: Int) -> SKTexture? {
        (variant % 2 == 0) ? senseiTexture() : hatGuyTexture()
    }

    static func npcTexture(kind: NPCKind) -> SKTexture? {
        switch kind {
        // ── Animal ambient NPCs — use sprite sheet frame 0 ──────────────────
        case .cat:     return catFrames(directionRow: 0).first
        case .dog:     return dogFrames().first
        case .raccoon: return raccoonFrames(directionRow: 0).first
        case .bird:    return birdFrames(white: false, directionRow: 0).first
        case .hazel:   return foxFrames(directionRow: 0).first
        // ── Human / story NPCs (each gets a distinct visual) ────────────────
        case .rangerGuide: return hatGuyTexture()         // hat suits a ranger
        case .jogger:      return gabeFrame(1)            // gabe running pose
        case .child:       return manaSeedCharTexture(variant: 2, frame: 0)
        case .birdwatcher: return maniFrame(0)            // mani idle
        case .dogwalker:   return gabeFrame(4)            // gabe alt pose
        case .gardener:    return senseiTexture()         // older gardener — sensei OK here
        case .worker:      return maniFrame(3)            // mani action pose (was broken hat-guy frame 2)
        case .shopkeeper:  return vendorTexture()
        }
    }

    static func enemyTexture(kind: EnemyKind) -> SKTexture? {
        switch kind {
        case .pigeon:
            return critterFrontTexture(sheet: "BIRDSPRITESHEET_Blue.png")
        case .goose, .grandGooseGerald:
            return critterFrontTexture(sheet: "BIRDSPRITESHEET_White.png")
        case .raccoon:
            return critterFrontTexture(sheet: "RACCOONSPRITESHEET.png")
        case .wasp:
            return fileTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/mobs/boss_bee.png"
            )
        case .ranger:        return npcTexture(kind: .rangerGuide)
        case .sternAdult:    return gabeFrame(5)
        case .flockLeader:   return critterTexture(sheet: "BIRDSPRITESHEET_Blue.png", frame: 12)
        case .vendingMachine:
            return fileTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-house-inn.png"
            )
        case .skateboardKid: return maniFrame(4)
        case .officerGrumble: return senseiTexture()      // single-frame; was broken frame 3
        case .foremanRex:    return hatGuyTexture()       // single-frame; was broken frame 4
        }
    }

    // MARK: - City ground textures (Tiny Pixel Fantasy – CityExterior tiles)

    private static let tpfCityBase = "textures.downloaded.sprites/Tiny Pixel Fantasy - Base Pack/Tiles/CityExterior/"
    private static let tpfCityInteriorBase = "textures.downloaded.sprites/Tiny Pixel Fantasy - Base Pack/Tiles/CityInterior/"

    private static func modernOldTileTexture(sheet: String, col: Int, row: Int) -> SKTexture? {
        sheetTexture(
            relativePath: "\(modernOldBase)\(sheet)",
            tileSize: CGSize(width: 16, height: 16),
            col: col,
            row: row
        )
    }

    /// Road / asphalt surface — use a calm tile from the uploaded modern pack.
    static func cityRoadTexture(variant: Int) -> SKTexture? {
        let options = [(0, 7), (1, 7), (2, 7)]
        let pick = options[abs(variant) % options.count]
        return modernOldTileTexture(sheet: "Tileset_16x16_1.png", col: pick.0, row: pick.1)
    }

    /// Sidewalk paving — use pale uploaded paving tiles instead of noisy city-detail tiles.
    static func citySidewalkTexture(variant: Int) -> SKTexture? {
        let options = [(4, 6), (5, 6), (6, 6)]
        let pick = options[abs(variant) % options.count]
        return modernOldTileTexture(sheet: "Tileset_16x16_1.png", col: pick.0, row: pick.1)
    }

    /// Generic city ground / plaza fill — keep it calm and readable.
    static func cityAsphaltTexture(variant: Int) -> SKTexture? {
        let options = [(0, 7), (1, 7), (4, 6)]
        let pick = options[abs(variant) % options.count]
        return modernOldTileTexture(sheet: "Tileset_16x16_1.png", col: pick.0, row: pick.1)
    }

    /// Crosswalk marking tile; falls back to road when `stripe` is false.
    static func cityCrosswalkTexture(stripe: Bool) -> SKTexture? {
        stripe
            ? nil
            : cityRoadTexture(variant: 0)
    }

    /// Dirt / gravel ground — construction zone uses Sprout Lands path tiles (row 1 = rougher dirt).
    static func cityDirtTexture(variant: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(sproutBase)Objects/Paths.png",
                     tileSize: CGSize(width: 16, height: 16),
                     col: abs(variant) % 4, row: 1)
    }

    // MARK: - Interior textures

    static func interiorFloorTexture(variant: Int) -> SKTexture? {
        let names = ["CityInterior_1_1.png", "CityInterior_1_2.png"]
        return fileTexture(relativePath: "\(tpfCityInteriorBase)\(names[abs(variant) % names.count])")
    }

    static func interiorWallTexture(variant: Int) -> SKTexture? {
        let names = ["CityInterior_2_1.png", "CityInterior_2_2.png", "CityInterior_2_3.png", "CityInterior_2_4.png"]
        return fileTexture(relativePath: "\(tpfCityInteriorBase)\(names[abs(variant) % names.count])")
    }

    static func interiorFeatureTexture(kind: String, variant: Int = 0) -> SKTexture? {
        let relativePath: String
        switch kind {
        case "window":
            relativePath = "\(tpfCityInteriorBase)CityInterior_6_1.png"
        case "banner":
            relativePath = "\(tpfCityInteriorBase)CityInterior_6_2.png"
        case "counter":
            relativePath = "\(tpfCityInteriorBase)CityInterior_11_1.png"
        case "shelf":
            relativePath = "\(tpfCityInteriorBase)CityInterior_8_1.png"
        case "stairs":
            relativePath = "\(tpfCityInteriorBase)CityInterior_7_1.png"
        case "hearth":
            let names = [
                "CityInterior_9_1.png",
                "CityInterior_9_2.png",
                "CityInterior_9_3.png",
                "CityInterior_9_4.png",
                "CityInterior_9_5.png"
            ]
            relativePath = "\(tpfCityInteriorBase)\(names[abs(variant) % names.count])"
        default:
            let names = ["CityInterior_10_1.png", "CityInterior_8_1.png"]
            relativePath = "\(tpfCityInteriorBase)\(names[abs(variant) % names.count])"
        }
        return fileTexture(relativePath: relativePath)
    }

    // MARK: - Animal walk-cycle animation frames
    // All 128×416 sheets = 4 cols × 13 rows of 32×32.
    // Row 0 = walk-south (toward camera) — the "forward-facing" row.

    /// Returns an ordered array of SKTextures for one walk-cycle row.
    static func animFrames(sheet: String, frameSize: CGSize = CGSize(width: 32, height: 32),
                           row: Int, count: Int, fromTop: Bool = false) -> [SKTexture] {
        (0..<count).compactMap {
            fromTop
                ? sheetTextureFromTop(relativePath: "textures.downloaded.sprites/\(sheet)",
                                      tileSize: frameSize, col: $0, rowFromTop: row)
                : sheetTexture(relativePath: "textures.downloaded.sprites/\(sheet)",
                               tileSize: frameSize, col: $0, row: row)
        }
    }

    /// Cat walk-south frames (gray cat, 4-frame cycle).
    static func catFrames(directionRow: Int = 0) -> [SKTexture] {
        animFrames(sheet: "CATSPRITESHEET_Gray.png", row: directionRow, count: 4, fromTop: true)
    }

    /// Raccoon walk-south frames (4-frame cycle).
    static func raccoonFrames(directionRow: Int = 0) -> [SKTexture] {
        animFrames(sheet: "RACCOONSPRITESHEET.png", row: directionRow, count: 4, fromTop: true)
    }

    /// One static dog sprite — 48DogSpriteSheet has 8 different breeds in a
    /// single row (NOT walk frames). Pass a per-NPC variant (0-7) to pick breed.
    /// Used for static icons / glyphs only; live NPCs use `dogFrames` (56Dogs walk cycle).
    static func dogTexture(variant: Int) -> SKTexture? {
        sheetTexture(relativePath: "textures.downloaded.sprites/48DogSpriteSheet.png",
                     tileSize: CGSize(width: 32, height: 48),
                     col: abs(variant) % 8, row: 0)
    }

    /// Dog walk cycle — 56Dogs.png is 7 cols × 8 rows of 16×16 frames.
    /// Each row = a breed; cols 0-6 = a 7-frame walk cycle. `variant` picks the breed.
    static func dogFrames(variant: Int = 0) -> [SKTexture] {
        let breed = abs(variant) % 8
        return (0..<7).compactMap {
            sheetTexture(relativePath: "textures.downloaded.sprites/56Dogs.png",
                         tileSize: CGSize(width: 16, height: 16),
                         col: $0, row: breed)
        }
    }

    /// Bird walk frames — BIRDSPRITESHEET is 4 cols × 13 rows of 32×32.
    /// Row 0 = south-facing walk (toward camera), matching the cat/fox/raccoon layout.
    static func birdFrames(white: Bool = false, directionRow: Int = 0) -> [SKTexture] {
        let sheet = white ? "BIRDSPRITESHEET_White.png" : "BIRDSPRITESHEET_Blue.png"
        return animFrames(sheet: sheet, row: directionRow, count: 4, fromTop: true)
    }

    /// Fox frames (used for Hazel NPC).
    static func foxFrames(directionRow: Int = 0) -> [SKTexture] {
        animFrames(sheet: "FOXSPRITESHEET.png", row: directionRow, count: 4, fromTop: true)
    }

    static func lampTexture(city: Bool) -> SKTexture? {
        fileTexture(relativePath: "textures.downloaded.sprites/SKTiled-master/Demo/Assets/sticker-knight/torch.png")
    }

    static func suburbHouseTexture(variant: Int) -> SKTexture? {
        let options = [
            "\(sproutBase)Objects/Free_Chicken_House.png",
            "\(genericPropsBase)generic-rpg-house-inn.png"
        ]
        return fileTexture(relativePath: options[abs(variant) % options.count])
    }

    static func storefrontTexture(variant: Int) -> SKTexture? {
        let options = [
            "\(genericPropsBase)generic-rpg-house-inn.png",
            "\(sproutBase)Objects/Free_Chicken_House.png"
        ]
        return fileTexture(relativePath: options[abs(variant) % options.count])
    }

    static func buildingTexture(widthTiles: Int, heightTiles: Int, palette: String, seed: UInt64) -> SKTexture? {
        switch palette {
        case "wood":
            return suburbHouseTexture(variant: Int(seed))
        case "brick", "concrete":
            return storefrontTexture(variant: Int(seed + UInt64(widthTiles + heightTiles)))
        default:
            return storefrontTexture(variant: Int(seed))
        }
    }

    static func placeholderTexture() -> SKTexture? {
        fileTexture(
            relativePath: "\(genericPropsBase)generic-rpg-crate01.png"
        )
    }

    static func textureForGlyph(_ glyph: String) -> SKTexture? {
        switch glyph {
        case "🌳":
            return parkLargeTree() ?? sproutNatureTexture(for: glyph)
        case "🌲":
            return parkTallConifer() ?? sproutNatureTexture(for: glyph)
        case "🌿", "🌷", "🌸", "🌺", "🌻":
            return parkBiomSprite(col: 3, row: 1) ?? sproutNatureTexture(for: glyph)
        case "🍄":
            return parkBiomSprite(col: 5, row: 1) ?? sproutNatureTexture(for: glyph)
        case "🪑":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-board01.png")
        case "🗑️":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-barrel01.png")
        case "🚧":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-board01.png")
        case "🪧", "🚫":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-board02.png")
        case "🪨":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-rock01.png")
        case "🧱":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-rock03.png")
        case "⛲":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-mini-lake.png")
        case "🐦":
            return critterFrontTexture(sheet: "BIRDSPRITESHEET_Blue.png")
        case "🐕":
            return dogTexture(variant: 0)
        case "🎤":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-board04.png")
        case "⛵":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-bridge.png")
        case "👣":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-loot01.png")
        case "🏗️":
            return fileTexture(relativePath: "textures.downloaded.sprites/platformConnector1.png")
        case "🏪":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/vendor/generic-rpg-vendor.png")
        case "📦", "🎁":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-crate01.png")
        case "💡", "🔦":
            return fileTexture(relativePath: "textures.downloaded.sprites/SKTiled-master/Demo/Assets/sticker-knight/torch.png")
        case "🪵":
            return fileTexture(relativePath: "textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Wood Bridge.png")
        case "🌰":
            return sheetTexture(relativePath: "textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Basic Grass Biom things 1.png", tileSize: CGSize(width: 16, height: 16), col: 0, row: 1)
        case "🍓", "🫐":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-loot02.png")
        case "🧃", "🥤", "🥫":
            return fileTexture(relativePath: "textures.downloaded.sprites/Sprout Lands - Sprites - Basic pack/Objects/Basic Plants.png")
        case "🪙":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-loot03.png")
        case "🪶":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-loot04.png")
        case "🦆":
            return critterFrontTexture(sheet: "BIRDSPRITESHEET_White.png")
        default:
            return nil
        }
    }
}
