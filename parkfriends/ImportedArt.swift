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
        // One level up = .../parkfriends/parkfriends/  ← same dir as textures.downloaded.sprites
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
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

    static func sproutGrassTexture(variant: Int) -> SKTexture? {
        let names = [
            "generic-rpg-tile11.png",
            "generic-rpg-tile13.png",
            "generic-rpg-tile15.png",
            "generic-rpg-tile20.png",
            "generic-rpg-tile22.png",
            "generic-rpg-tile40.png",
            "generic-rpg-tile42.png"
        ]
        return fileTexture(
            relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/tiles/\(names[abs(variant) % names.count])"
        )
    }

    static func sproutPathTexture(variant: Int) -> SKTexture? {
        let names = [
            "generic-rpg-tile09.png",
            "generic-rpg-tile21.png",
            "generic-rpg-tile23.png"
        ]
        let pick = names[abs(variant) % names.count]
        return fileTexture(
            relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/tiles/\(pick)"
        )
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

    static func rpgCharTexture(relativePath: String, frame: Int, frameSize: CGSize = CGSize(width: 32, height: 32)) -> SKTexture? {
        sheetTexture(relativePath: relativePath, tileSize: frameSize, col: frame, row: 0)
    }

    static func npcTexture(kind: NPCKind) -> SKTexture? {
        switch kind {
        case .rangerGuide:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/sensei/sensei.png",
                frame: 0
            )
        case .hazel:
            return critterTexture(sheet: "FOXSPRITESHEET.png", frame: 0)
        case .jogger:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/gabe/gabe-idle-run.png",
                frame: 1
            )
        case .child:
            return critterTexture(sheet: "CATSPRITESHEET_Gray.png", frame: 4)
        case .birdwatcher:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/mani/mani-idle-run.png",
                frame: 0
            )
        case .dogwalker:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/gabe/gabe-idle-run.png",
                frame: 4
            )
        case .gardener:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/hat-guy/hat-guy.png",
                frame: 0
            )
        case .worker:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/hat-guy/hat-guy.png",
                frame: 2
            )
        case .shopkeeper:
            return fileTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/vendor/generic-rpg-vendor.png"
            )
        }
    }

    static func enemyTexture(kind: EnemyKind) -> SKTexture? {
        switch kind {
        case .pigeon:
            return critterTexture(sheet: "BIRDSPRITESHEET_Blue.png", frame: 0)
        case .goose, .grandGooseGerald:
            return critterTexture(sheet: "BIRDSPRITESHEET_White.png", frame: 0)
        case .raccoon:
            return critterTexture(sheet: "RACCOONSPRITESHEET.png", frame: 0)
        case .wasp:
            return fileTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/mobs/boss_bee.png"
            )
        case .ranger:
            return npcTexture(kind: .rangerGuide)
        case .sternAdult:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/gabe/gabe-idle-run.png",
                frame: 5
            )
        case .flockLeader:
            return critterTexture(sheet: "BIRDSPRITESHEET_Blue.png", frame: 12)
        case .vendingMachine:
            return fileTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-house-inn.png"
            )
        case .skateboardKid:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/mani/mani-idle-run.png",
                frame: 4
            )
        case .officerGrumble:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/sensei/sensei.png",
                frame: 3
            )
        case .foremanRex:
            return rpgCharTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/hat-guy/hat-guy.png",
                frame: 4
            )
        }
    }

    // MARK: - City ground textures (Tiny Pixel Fantasy – CityExterior tiles)

    private static let tpfCityBase = "textures.downloaded.sprites/Tiny Pixel Fantasy - Base Pack/Tiles/CityExterior/"

    /// Road / asphalt surface — CityExterior_1_1 is the base city ground tile.
    static func cityRoadTexture(variant: Int) -> SKTexture? {
        fileTexture(relativePath: "\(tpfCityBase)CityExterior_1_1.png")
    }

    /// Sidewalk paving — three 16×16 CityExterior slabs used for variety.
    static func citySidewalkTexture(variant: Int) -> SKTexture? {
        let names = ["CityExterior_2_1.png", "CityExterior_2_2.png", "CityExterior_2_3.png"]
        return fileTexture(relativePath: "\(tpfCityBase)\(names[abs(variant) % names.count])")
    }

    /// Generic city ground / asphalt fill with slight variation.
    static func cityAsphaltTexture(variant: Int) -> SKTexture? {
        let names = ["CityExterior_16_1.png", "CityExterior_16_2.png", "CityExterior_1_1.png"]
        return fileTexture(relativePath: "\(tpfCityBase)\(names[abs(variant) % names.count])")
    }

    /// Crosswalk marking tile; falls back to road when `stripe` is false.
    static func cityCrosswalkTexture(stripe: Bool) -> SKTexture? {
        stripe
            ? fileTexture(relativePath: "\(tpfCityBase)CityExterior_14_1.png")
            : cityRoadTexture(variant: 0)
    }

    /// Dirt / gravel ground — used in construction-zone north map.
    static func cityDirtTexture(variant: Int) -> SKTexture? {
        let names = ["generic-rpg-tile09.png", "generic-rpg-tile21.png", "generic-rpg-tile23.png"]
        return fileTexture(
            relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/tiles/\(names[abs(variant) % names.count])"
        )
    }

    static func lampTexture(city: Bool) -> SKTexture? {
        fileTexture(relativePath: "textures.downloaded.sprites/torch.png")
    }

    static func buildingTexture(widthTiles: Int, heightTiles: Int, palette: String, seed: UInt64) -> SKTexture? {
        if seed % 3 == 0 {
            return fileTexture(
                relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-house-inn.png"
            )
        }
        return fileTexture(
            relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/chars/vendor/generic-rpg-vendor.png"
        )
    }

    static func placeholderTexture() -> SKTexture? {
        fileTexture(
            relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-crate01.png"
        )
    }

    static func textureForGlyph(_ glyph: String) -> SKTexture? {
        switch glyph {
        case "🌳":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-tree01.png")
        case "🌲":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-tree02.png")
        case "🌿":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-grass01.png")
        case "🌷", "🌸", "🌺", "🌻":
            return fileTexture(relativePath: "textures.downloaded.sprites/generic-rpg-pack_v0.4_(alpha-release)_vacaroxa/rpg-pack/props n decorations/generic-rpg-flowers.png")
        case "🍄":
            return sproutNatureTexture(for: glyph)
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
            return critterTexture(sheet: "BIRDSPRITESHEET_Blue.png", frame: 0)
        case "🐕":
            return sheetTexture(relativePath: "textures.downloaded.sprites/48DogSpriteSheet.png", tileSize: CGSize(width: 48, height: 48), col: 0, row: 0)
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
            return critterTexture(sheet: "BIRDSPRITESHEET_White.png", frame: 4)
        default:
            return nil
        }
    }
}
