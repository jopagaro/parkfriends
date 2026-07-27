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

    // ── 4×4 blob autotile sheets (shared layout) ─────────────────────────────
    // Row 0 (top): 3-wide horizontal capsule + 1×1 single blob at col 3.
    // Rows 1-3: 3×3 blob (cols 0-2) + vertical capsule at col 3.

    /// Water blob autotile (generated, sand shoreline).
    static func pondBlobTile(col: Int, rowFromTop: Int) -> SKTexture? {
        genBlobTile("sheet-water-blob-128", col: col, rowFromTop: rowFromTop)
            ?? sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-blue-pond-water-border-corners-and-edges-tileset-64x64.png",
                                   tileSize: CGSize(width: 16, height: 16), col: col, rowFromTop: rowFromTop)
    }

    /// Dirt path blob autotile (generated).
    static func parkPathBlobTile(col: Int, rowFromTop: Int) -> SKTexture? {
        genBlobTile("sheet-dirt-blob-128", col: col, rowFromTop: rowFromTop)
            ?? sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-pebbled-brown-dirt-path-corner-and-edge-tileset-64x64.png",
                                   tileSize: CGSize(width: 16, height: 16), col: col, rowFromTop: rowFromTop)
    }

    /// Stone plaza blob autotile (generated, grass border).
    static func parkStoneBlobTile(col: Int, rowFromTop: Int) -> SKTexture? {
        genBlobTile("sheet-stone-blob-128", col: col, rowFromTop: rowFromTop)
            ?? sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-gray-stone-path-with-grass-border-corners-and-edges-tileset-64x64.png",
                                   tileSize: CGSize(width: 16, height: 16), col: col, rowFromTop: rowFromTop)
    }

    /// Hedge blob autotile (generated leafy mass).
    static func parkHedgeBlobTile(col: Int, rowFromTop: Int) -> SKTexture? {
        genBlobTile("sheet-hedge-blob-128", col: col, rowFromTop: rowFromTop)
            ?? sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-dense-leaf-hedge-border-corner-and-edge-tileset-64x64.png",
                                   tileSize: CGSize(width: 16, height: 16), col: col, rowFromTop: rowFromTop)
    }

    /// Plain bright grass fill (MAP_SPEC `grass_fill`, piece 70).
    static func parkBrightGrassTile() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-plain-bright-grass-fill-piece-70-16x16.png")
    }

    private static let genWorld = "textures.downloaded.sprites/world.generated/"

    /// Generated 32px world tile by filename stem.
    static func genTile(_ name: String) -> SKTexture? {
        fileTexture(relativePath: "\(genWorld)\(name).png")
    }

    /// Generated 4x4 blob sheet cell (32px cells), row measured from top.
    static func genBlobTile(_ sheet: String, col: Int, rowFromTop: Int) -> SKTexture? {
        sheetTextureFromTop(relativePath: "\(genWorld)\(sheet).png",
                            tileSize: CGSize(width: 32, height: 32),
                            col: col, rowFromTop: rowFromTop)
    }

    /// Solid grass base — now the generated textured grass (pack fallback).
    static func parkGrassBaseTile() -> SKTexture? {
        genTile("tile-grass-0-32")
            ?? fileTexture(relativePath: "\(worldParkBase)pixel-art-solid-dark-green-grass-square-tile-16x16.png")
    }

    /// Furniture sheet (144×96 = 9×6 of 16×16). (6,2) = rounded wood chair.
    static func parkFurnitureTile(col: Int, rowFromTop: Int) -> SKTexture? {
        sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-basic-furniture-beds-tables-chairs-rugs-cabinets-tileset-144x96.png",
                            tileSize: CGSize(width: 16, height: 16), col: col, rowFromTop: rowFromTop)
    }

    /// Vertical plank walkway (generated).
    static func sproutBridgeVertical() -> SKTexture? {
        genTile("prop-bridge-v-96x144")
            ?? sheetTexture(relativePath: "\(sproutBase)Objects/Wood Bridge.png",
                            tileSize: CGSize(width: 32, height: 48), col: 0, row: 0)
    }

    /// Horizontal plank walkway / pier (generated).
    static func sproutBridgeHorizontal() -> SKTexture? {
        if let gen = genTile("prop-bridge-h-144x48") { return gen }
        guard let full = cgImage(at: "\(sproutBase)Objects/Wood Bridge.png"),
              let crop = full.cropping(to: CGRect(x: 32, y: 0, width: 48, height: 16)) else { return nil }
        let key = "bridge-horizontal-strip"
        if let cached = textureCache[key] { return cached }
        let tex = SKTexture(cgImage: crop)
        tex.filteringMode = .nearest
        textureCache[key] = tex
        return tex
    }

    /// Gray stone block (statue pedestal).
    static func parkStoneBlockTile() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-gray-stone-block-tile-16x16.png")
    }

    /// Curved grass blade tuft (pond reeds).
    static func parkGrassBlade() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-small-curved-grass-blade-sprite-13x7.png")
    }

    /// Water surface shimmer (64×16 = 4 frames of 16×16) — fountain water.
    static func parkWaterSurfaceFrames() -> [SKTexture] {
        (0..<4).compactMap {
            sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-blue-water-surface-animation-strip-64x16.png",
                                tileSize: CGSize(width: 16, height: 16), col: $0, rowFromTop: 0)
        }
    }

    /// Dark wood chair (16×32 front view) — stands in for park bench seats.
    static func parkBenchChair() -> SKTexture? {
        fileTexture(relativePath: "\(worldParkBase)pixel-art-chair-dark-wood-simple-backrest-front-view-sprite-16x32.png")
    }

    /// Sidewalk/concrete tile (generated, slab joints + crack variant).
    static func parkStoneTile(variant: Int = 0) -> SKTexture? {
        genTile("tile-sidewalk-\(abs(variant) % 3)-32")
            ?? fileTexture(relativePath: "\(worldParkBase)pixel-art-gray-stone-ground-tile-16x16.png")
    }

    /// Dark grass tile (generated variants).
    static func darkGrassTile(variant: Int = 0) -> SKTexture? {
        genTile("tile-grassdark-\(abs(variant) % 3)-32")
            ?? fileTexture(relativePath: "\(worldParkBase)pixel-art-dark-green-grass-with-small-sprouts-tile-16x16.png")
    }

    /// Biom things sheet (144×80, 16×16 = 9 cols × 5 rows).
    /// Row 0: stones/crystals, logs; row 1-2: flowers, mushrooms; row 3-4: bushes/plants.
    static func parkBiomSprite(col: Int, row: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(worldParkBase)pixel-art-basic-grass-biome-props-flowers-rocks-bushes-mushrooms-and-plants-tileset-144x80.png",
                     tileSize: CGSize(width: 16, height: 16), col: col, row: row)
    }

    /// White chicken sheet (192×192 = 4 cols × 4 rows of 48×48). Top row = walk-south.
    static func parkChickenFrames(rowFromTop: Int = 0) -> [SKTexture] {
        (0..<4).compactMap {
            sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-white-chicken-yellow-beak-4-direction-walk-idle-spritesheet-192x192.png",
                                tileSize: CGSize(width: 48, height: 48), col: $0, rowFromTop: rowFromTop)
        }
    }

    /// Baby chicks sheet (64×32 of 16×16 cells; top row = 4-frame hop cycle).
    static func parkChicksFrames() -> [SKTexture] {
        (0..<4).compactMap {
            sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-yellow-baby-chicks-5-frame-row-spritesheet-64x32.png",
                                tileSize: CGSize(width: 16, height: 16), col: $0, rowFromTop: 0)
        }
    }

    /// Egg & nest stages (64×16 = 4 frames of 16×16). Stage 0 = nest with egg.
    static func parkEggNest(stage: Int = 0) -> SKTexture? {
        sheetTextureFromTop(relativePath: "\(worldParkBase)pixel-art-egg-and-nest-stages-empty-egg-hatched-spritesheet-64x16.png",
                            tileSize: CGSize(width: 16, height: 16), col: abs(stage) % 4, rowFromTop: 0)
    }

    /// Brown squirrel idle loop — standalone 90×58 frames 02–08.
    static func parkSquirrelIdleFrames() -> [SKTexture] {
        (2...8).compactMap {
            fileTexture(relativePath: String(format: "%@pixel-art-brown-squirrel-idle-animation-frame-%02d-90x58.png", worldParkBase, $0))
        }
    }

    /// Large round tree (generated, form-shaded).
    static func parkLargeTree() -> SKTexture? {
        genTile("tree-large-96x128")
            ?? fileTexture(relativePath: "\(worldParkBase)pixel-art-large-round-green-tree-sprite-48x48.png")
    }

    /// Medium round tree (generated).
    static func parkMediumTree() -> SKTexture? {
        genTile("tree-medium-64x92")
            ?? fileTexture(relativePath: "\(worldParkBase)pixel-art-medium-round-green-tree-sprite-32x32.png")
    }

    /// Wide tree — same generated medium canopy.
    static func parkWideTree() -> SKTexture? {
        genTile("tree-medium-64x92")
            ?? fileTexture(relativePath: "\(worldParkBase)pixel-art-medium-wide-round-green-tree-sprite-32x32.png")
    }

    /// Conifer (generated stacked-tier pine).
    static func parkTallConifer() -> SKTexture? {
        genTile("tree-conifer-64x110")
            ?? fileTexture(relativePath: "\(worldParkBase)pixel-art-tall-conical-green-tree-sprite-32x48.png")
    }

    /// Small tree (generated).
    static func parkSmallConifer() -> SKTexture? {
        genTile("tree-small-48x68")
            ?? fileTexture(relativePath: "\(worldParkBase)pixel-art-small-conical-green-tree-sprite-16x32.png")
    }

    /// Landmark oak (generated, largest canopy).
    static func parkOakTree() -> SKTexture? {
        genTile("tree-oak-140x190") ?? parkLargeTree()
    }

    /// Complete suburban house exterior sprite (112×80).
    /// NOTE: despite the filename this is a PARTS sheet, not a whole house —
    /// prefer `generatedHouse(variant:)`.
    static func suburbHouseExterior() -> SKTexture? {
        fileTexture(relativePath: "\(worldSuburbBase)pixel-art-complete-small-wooden-house-exterior-sprite-112x80.png")
    }

    /// Code-generated 112×80 house (tools/spritegen). Variants are the
    /// MAP_SPEC §3.14 roof colors: blue, brown, green, red_brown, dark_red,
    /// charcoal, tan, dark_purple.
    static func generatedHouse(variant: String) -> SKTexture? {
        fileTexture(relativePath: "textures.downloaded.sprites/world.generated/house-\(variant)-112x80.png")
    }

    /// Wood post-and-rail fence tileset (64×64 = 4 cols × 4 rows of 16×16).
    static func woodFenceTile(col: Int, row: Int) -> SKTexture? {
        sheetTexture(relativePath: "\(worldSuburbBase)pixel-art-wood-post-and-rail-fence-corners-and-segments-tileset-64x64.png",
                     tileSize: CGSize(width: 16, height: 16), col: col, row: row)
    }

    /// Fence sheet adapter for the standard blob autotiler. The fence sheet's
    /// own layout is: 3×3 blob at cols 1-3 / rows 0-2, post column at col 0,
    /// low horizontal rails at row 3.
    static func suburbFenceBlobTile(col: Int, rowFromTop: Int) -> SKTexture? {
        let path = "\(worldSuburbBase)pixel-art-wood-post-and-rail-fence-corners-and-segments-tileset-64x64.png"
        let mapped: (Int, Int)
        switch (col, rowFromTop) {
        case (3, 0):          mapped = (0, 3)                    // isolated post
        case (let c, 0):      mapped = (c < 2 ? 1 : 2, 3)        // horizontal run
        case (3, let r):      mapped = (0, r - 1)                // vertical run
        case (let c, let r):  mapped = (c + 1, r - 1)            // blob
        }
        return sheetTextureFromTop(relativePath: path,
                                   tileSize: CGSize(width: 16, height: 16),
                                   col: mapped.0, rowFromTop: mapped.1)
    }

    /// Asphalt road tile (generated). The suburb's road band centers on
    /// spec row 23 — that row gets the dashed center line.
    static func suburbPavementTile(col: Int, rowFromTop: Int) -> SKTexture? {
        if rowFromTop == 23 { return genTile("tile-road-dash-32") ?? genTile("tile-road-0-32") }
        return genTile("tile-road-\(abs(col + rowFromTop) % 2)-32")
            ?? sheetTextureFromTop(relativePath: "\(worldSuburbBase)pixel-art-purple-blue-brick-street-pavement-tile-48x32.png",
                                   tileSize: CGSize(width: 16, height: 16),
                                   col: ((col % 3) + 3) % 3, rowFromTop: ((rowFromTop % 2) + 2) % 2)
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

    /// Generated human NPC walk frames (2 per direction). Empty for animals.
    static func genNPCWalkFrames(kind: NPCKind, direction: String) -> [SKTexture] {
        let role: String?
        switch kind {
        case .rangerGuide: role = "ranger"
        case .jogger:      role = "jogger"
        case .child:       role = "child"
        case .birdwatcher: role = "birdwatcher"
        case .dogwalker:   role = "dogwalker"
        case .gardener:    role = "gardener"
        case .worker:      role = "worker"
        case .shopkeeper:  role = "shopkeeper"
        default:           role = nil
        }
        guard let role else { return [] }
        return (1...2).compactMap {
            fileTexture(relativePath: "textures.downloaded.sprites/world.generated/npc-\(role)-\(direction)-f\($0)-128x192.png")
        }
    }

    static func npcTexture(kind: NPCKind) -> SKTexture? {
        if let gen = genNPCWalkFrames(kind: kind, direction: "south").first { return gen }
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
        func gen(_ name: String) -> SKTexture? {
            fileTexture(relativePath: "textures.downloaded.sprites/world.generated/\(name).png")
        }
        switch kind {
        case .pigeon:
            return gen("enemy-pigeon-battle-128x128")
                ?? critterFrontTexture(sheet: "BIRDSPRITESHEET_Blue.png")
        case .goose:
            return gen("enemy-goose-battle-128x128")
                ?? critterFrontTexture(sheet: "BIRDSPRITESHEET_White.png")
        case .grandGooseGerald:
            return gen("enemy-gerald-battle-128x128")
                ?? critterFrontTexture(sheet: "BIRDSPRITESHEET_White.png")
        case .raccoon:
            return gen("enemy-raccoon-battle-128x128")
                ?? critterFrontTexture(sheet: "RACCOONSPRITESHEET.png")
        case .wasp:
            return gen("enemy-wasp-battle-128x128") ?? fileTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/mobs/boss_bee.png"
            )
        case .flockLeader:
            return gen("enemy-flockleader-battle-128x128")
                ?? critterTexture(sheet: "BIRDSPRITESHEET_Blue.png", frame: 12)
        case .vendingMachine:
            return gen("enemy-vending-battle-128x128") ?? fileTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-house-inn.png"
            )
        case .ranger:         return gen("enemy-ranger-battle-128x128")     ?? npcTexture(kind: .rangerGuide)
        case .sternAdult:     return gen("enemy-sternadult-battle-128x128") ?? gabeFrame(5)
        case .skateboardKid:  return gen("enemy-skaterkid-battle-128x128")  ?? maniFrame(4)
        case .officerGrumble: return gen("enemy-officer-battle-128x128")    ?? senseiTexture()
        case .foremanRex:     return gen("enemy-foreman-battle-128x128")    ?? hatGuyTexture()
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

    /// Maps a pack-sheet direction row (0=S,1=SW,2=W,3=NW,4=N,5=NE,6=E,7=SE)
    /// onto the four generated-art directions.
    static func genCritterDir(_ row: Int) -> String {
        switch ((row % 8) + 8) % 8 {
        case 0:       return "south"
        case 4:       return "north"
        case 1, 2, 3: return "west"
        default:      return "east"
        }
    }

    /// 4-frame generated critter walk cycle; empty if the PNGs are missing.
    static func genCritterFrames(_ slug: String, _ size: String, directionRow: Int) -> [SKTexture] {
        (1...4).compactMap {
            fileTexture(relativePath:
                "textures.downloaded.sprites/world.generated/critter-\(slug)-walk-\(genCritterDir(directionRow))-f\($0)-\(size).png")
        }
    }

    /// 2-frame generated human walk cycle addressed by role slug + direction row.
    static func genRoleWalkFrames(role: String, directionRow: Int) -> [SKTexture] {
        (1...2).compactMap {
            fileTexture(relativePath:
                "textures.downloaded.sprites/world.generated/npc-\(role)-\(genCritterDir(directionRow))-f\($0)-128x192.png")
        }
    }

    /// Cat walk frames (generated art; pack sheet fallback).
    static func catFrames(directionRow: Int = 0) -> [SKTexture] {
        let gen = genCritterFrames("cat", "44x44", directionRow: directionRow)
        return gen.isEmpty
            ? animFrames(sheet: "CATSPRITESHEET_Gray.png", row: directionRow, count: 4, fromTop: true)
            : gen
    }

    /// Raccoon walk frames (generated art; pack sheet fallback).
    static func raccoonFrames(directionRow: Int = 0) -> [SKTexture] {
        let gen = genCritterFrames("raccoon", "48x48", directionRow: directionRow)
        return gen.isEmpty
            ? animFrames(sheet: "RACCOONSPRITESHEET.png", row: directionRow, count: 4, fromTop: true)
            : gen
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
        let gen = genCritterFrames("dog", "44x44", directionRow: 0)
        if !gen.isEmpty { return gen }
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
        let gen = white
            ? genCritterFrames("goose", "48x56", directionRow: directionRow)
            : genCritterFrames("pigeon", "40x40", directionRow: directionRow)
        if !gen.isEmpty { return gen }
        let sheet = white ? "BIRDSPRITESHEET_White.png" : "BIRDSPRITESHEET_Blue.png"
        return animFrames(sheet: sheet, row: directionRow, count: 4, fromTop: true)
    }

    /// Hazel-the-NPC frames — her own generated walk cycle (fox sheet fallback).
    static func foxFrames(directionRow: Int = 0) -> [SKTexture] {
        let gen = (1...4).compactMap {
            fileTexture(relativePath:
                "textures.downloaded.sprites/world.generated/hazel-walk-\(genCritterDir(directionRow))-f\($0)-64x96.png")
        }
        return gen.isEmpty
            ? animFrames(sheet: "FOXSPRITESHEET.png", row: directionRow, count: 4, fromTop: true)
            : gen
    }

    static func lampTexture(city: Bool) -> SKTexture? {
        genTile("prop-lamppost-32x96")
            ?? fileTexture(relativePath: "textures.downloaded.sprites/SKTiled-master/Demo/Assets/sticker-knight/torch.png")
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
