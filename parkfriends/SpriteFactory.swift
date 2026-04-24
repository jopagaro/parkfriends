import CoreGraphics
import SpriteKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Shared icon factory for props and pickups.
/// The API keeps the old `emojiTexture` name so the existing map code can stay
/// intact, but the output is now hand-drawn pixel-style art instead of emoji.
enum SpriteFactory {
    private static var cache: [String: SKTexture] = [:]

    static func emojiTexture(_ glyph: String, size: CGFloat = 64) -> SKTexture {
        let key = "\(glyph)@\(Int(size))"
        if let cached = cache[key] { return cached }

        let pixelSize = CGSize(width: size, height: size)
        let texture = SKTexture(image: renderIcon(glyph, size: pixelSize))
        texture.filteringMode = .nearest
        cache[key] = texture
        return texture
    }

    // MARK: - Platform rendering

#if canImport(UIKit)
    private static func renderIcon(_ glyph: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            drawIcon(glyph, in: ctx.cgContext, size: size)
        }
    }
#elseif canImport(AppKit)
    private static func renderIcon(_ glyph: String, size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
            drawIcon(glyph, in: ctx, size: size)
        }
        image.unlockFocus()
        return image
    }
#endif

    // MARK: - Drawing

    private static func drawIcon(_ glyph: String, in ctx: CGContext, size: CGSize) {
        ctx.setAllowsAntialiasing(false)
        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none

        switch glyph {
        case "🌳": drawTree(in: ctx, size: size, round: true)
        case "🌲": drawTree(in: ctx, size: size, round: false)
        case "🌿": drawBush(in: ctx, size: size)
        case "🌷", "🌸", "🌺", "🌻": drawFlower(in: ctx, size: size, glyph: glyph)
        case "🍄": drawMushroom(in: ctx, size: size)
        case "🪑": drawBench(in: ctx, size: size)
        case "🗑️": drawTrashCan(in: ctx, size: size)
        case "🚧": drawBarricade(in: ctx, size: size)
        case "🪧", "🚫": drawSign(in: ctx, size: size, warning: glyph == "🚫")
        case "🪨": drawRock(in: ctx, size: size)
        case "🧱": drawBrick(in: ctx, size: size)
        case "⛲": drawFountain(in: ctx, size: size)
        case "🐦": drawBird(in: ctx, size: size)
        case "🐕": drawDog(in: ctx, size: size)
        case "🦴": drawBone(in: ctx, size: size)
        case "🎾": drawBall(in: ctx, size: size)
        case "🥣": drawBowl(in: ctx, size: size)
        case "🎤": drawMicrophone(in: ctx, size: size)
        case "⛵": drawBoat(in: ctx, size: size)
        case "👣": drawFootprints(in: ctx, size: size)
        case "🚇": drawSubway(in: ctx, size: size)
        case "🏗️": drawCrane(in: ctx, size: size)
        case "🏪": drawStorefront(in: ctx, size: size)
        case "📦", "🎁": drawBox(in: ctx, size: size, tied: glyph == "🎁")
        case "💡", "🔦": drawLight(in: ctx, size: size, portable: glyph == "🔦")
        case "🪣": drawBucket(in: ctx, size: size)
        case "🪵": drawPlank(in: ctx, size: size)
        case "🫐", "🍓": drawBerry(in: ctx, size: size, large: glyph == "🍓")
        case "🌰": drawAcorn(in: ctx, size: size)
        case "🍫": drawSnackBar(in: ctx, size: size)
        case "🧃", "🥤", "🥫": drawDrink(in: ctx, size: size, sealed: glyph != "🥤")
        case "🧴": drawBottle(in: ctx, size: size)
        case "🍪", "🥨", "🥖": drawSnack(in: ctx, size: size, glyph: glyph)
        case "💧": drawWaterDrop(in: ctx, size: size)
        case "🛍️": drawBag(in: ctx, size: size)
        case "✨": drawSparkleToken(in: ctx, size: size)
        case "🪙": drawCoin(in: ctx, size: size)
        case "🗝️": drawKey(in: ctx, size: size)
        case "🪪", "🏷️": drawTag(in: ctx, size: size, punched: glyph == "🪪")
        case "🪶": drawFeather(in: ctx, size: size)
        case "📋", "📄", "📇", "📰": drawPaper(in: ctx, size: size, glyph: glyph)
        case "📢": drawWhistle(in: ctx, size: size)
        case "⚙️": drawGear(in: ctx, size: size)
        case "☕": drawThermos(in: ctx, size: size)
        default: drawFallbackGlyph(glyph, in: ctx, size: size)
        }
    }

    // MARK: - Palette helpers

    private static let ink = SKColor(hex: "1E1E22") ?? .black
    private static let paper = SKColor(hex: "E7DFBF") ?? .white
    private static let metal = SKColor(hex: "7A7A7A") ?? .gray
    private static let metalHi = SKColor(hex: "BEBEBE") ?? .lightGray
    private static let wood = SKColor(hex: "7A5C2E") ?? .brown

    private static func fill(_ ctx: CGContext, color: SKColor, _ rect: CGRect) {
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
    }

    private static func stroke(_ ctx: CGContext, color: SKColor, _ rect: CGRect, lineWidth: CGFloat = 2) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.stroke(rect)
    }

    private static func shadowBase(in ctx: CGContext, size: CGSize, width: CGFloat = 0.48) {
        let rect = CGRect(
            x: size.width * (0.5 - width / 2),
            y: size.height * 0.80,
            width: size.width * width,
            height: size.height * 0.10
        )
        ctx.setFillColor(SKColor(white: 0, alpha: 0.20).cgColor)
        ctx.fill(rect)
    }

    // MARK: - World props

    private static func drawTree(in ctx: CGContext, size: CGSize, round: Bool) {
        shadowBase(in: ctx, size: size, width: 0.44)
        fill(ctx, color: wood, CGRect(x: size.width * 0.43, y: size.height * 0.50, width: size.width * 0.14, height: size.height * 0.26))
        fill(ctx, color: SKColor(hex: "5A3E1E") ?? wood, CGRect(x: size.width * 0.49, y: size.height * 0.50, width: size.width * 0.04, height: size.height * 0.26))

        if round {
            fill(ctx, color: GamePalette.grassG3, CGRect(x: size.width * 0.18, y: size.height * 0.14, width: size.width * 0.64, height: size.height * 0.22))
            fill(ctx, color: GamePalette.grassG1, CGRect(x: size.width * 0.12, y: size.height * 0.28, width: size.width * 0.76, height: size.height * 0.26))
            fill(ctx, color: GamePalette.grassG4Worn, CGRect(x: size.width * 0.24, y: size.height * 0.16, width: size.width * 0.22, height: size.height * 0.10))
        } else {
            fill(ctx, color: GamePalette.grassG3Deep, CGRect(x: size.width * 0.26, y: size.height * 0.14, width: size.width * 0.48, height: size.height * 0.14))
            fill(ctx, color: GamePalette.grassG3, CGRect(x: size.width * 0.20, y: size.height * 0.28, width: size.width * 0.60, height: size.height * 0.14))
            fill(ctx, color: GamePalette.grassG1, CGRect(x: size.width * 0.14, y: size.height * 0.42, width: size.width * 0.72, height: size.height * 0.16))
            fill(ctx, color: GamePalette.grassG4Worn, CGRect(x: size.width * 0.28, y: size.height * 0.18, width: size.width * 0.16, height: size.height * 0.08))
        }
    }

    private static func drawBush(in ctx: CGContext, size: CGSize) {
        shadowBase(in: ctx, size: size, width: 0.44)
        fill(ctx, color: GamePalette.grassG3Deep, CGRect(x: size.width * 0.16, y: size.height * 0.48, width: size.width * 0.68, height: size.height * 0.18))
        fill(ctx, color: GamePalette.grassG3, CGRect(x: size.width * 0.10, y: size.height * 0.56, width: size.width * 0.78, height: size.height * 0.16))
        fill(ctx, color: GamePalette.grassG4Worn, CGRect(x: size.width * 0.28, y: size.height * 0.52, width: size.width * 0.18, height: size.height * 0.06))
    }

    private static func drawFlower(in ctx: CGContext, size: CGSize, glyph: String) {
        let petal: SKColor
        switch glyph {
        case "🌷": petal = SKColor(hex: "D97A88") ?? .systemPink
        case "🌻": petal = SKColor(hex: "D4B030") ?? .yellow
        case "🌺": petal = SKColor(hex: "C83030") ?? .red
        default: petal = SKColor(hex: "E8A0B8") ?? .systemPink
        }
        fill(ctx, color: GamePalette.grassG3, CGRect(x: size.width * 0.46, y: size.height * 0.40, width: size.width * 0.08, height: size.height * 0.30))
        fill(ctx, color: petal, CGRect(x: size.width * 0.34, y: size.height * 0.22, width: size.width * 0.32, height: size.height * 0.18))
        fill(ctx, color: GamePalette.grassG4Worn, CGRect(x: size.width * 0.54, y: size.height * 0.50, width: size.width * 0.10, height: size.height * 0.06))
    }

    private static func drawMushroom(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "C47A52") ?? .systemRed, CGRect(x: size.width * 0.26, y: size.height * 0.30, width: size.width * 0.48, height: size.height * 0.20))
        fill(ctx, color: paper, CGRect(x: size.width * 0.40, y: size.height * 0.48, width: size.width * 0.18, height: size.height * 0.18))
        fill(ctx, color: paper, CGRect(x: size.width * 0.33, y: size.height * 0.36, width: size.width * 0.06, height: size.height * 0.05))
    }

    private static func drawBench(in ctx: CGContext, size: CGSize) {
        shadowBase(in: ctx, size: size, width: 0.52)
        fill(ctx, color: SKColor(hex: "A07840") ?? .brown, CGRect(x: size.width * 0.24, y: size.height * 0.34, width: size.width * 0.52, height: size.height * 0.10))
        fill(ctx, color: SKColor(hex: "BF8F52") ?? .brown, CGRect(x: size.width * 0.20, y: size.height * 0.48, width: size.width * 0.44, height: size.height * 0.10))
        fill(ctx, color: metal, CGRect(x: size.width * 0.26, y: size.height * 0.58, width: size.width * 0.06, height: size.height * 0.16))
        fill(ctx, color: metal, CGRect(x: size.width * 0.58, y: size.height * 0.58, width: size.width * 0.06, height: size.height * 0.16))
    }

    private static func drawTrashCan(in ctx: CGContext, size: CGSize) {
        shadowBase(in: ctx, size: size, width: 0.36)
        fill(ctx, color: metal, CGRect(x: size.width * 0.32, y: size.height * 0.28, width: size.width * 0.36, height: size.height * 0.40))
        fill(ctx, color: metalHi, CGRect(x: size.width * 0.32, y: size.height * 0.28, width: size.width * 0.08, height: size.height * 0.40))
        fill(ctx, color: SKColor(hex: "484860") ?? .darkGray, CGRect(x: size.width * 0.28, y: size.height * 0.22, width: size.width * 0.44, height: size.height * 0.07))
    }

    private static func drawBarricade(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "C83030") ?? .red, CGRect(x: size.width * 0.18, y: size.height * 0.28, width: size.width * 0.64, height: size.height * 0.16))
        fill(ctx, color: paper, CGRect(x: size.width * 0.18, y: size.height * 0.42, width: size.width * 0.64, height: size.height * 0.12))
        fill(ctx, color: metal, CGRect(x: size.width * 0.26, y: size.height * 0.54, width: size.width * 0.08, height: size.height * 0.20))
        fill(ctx, color: metal, CGRect(x: size.width * 0.66, y: size.height * 0.54, width: size.width * 0.08, height: size.height * 0.20))
    }

    private static func drawSign(in ctx: CGContext, size: CGSize, warning: Bool) {
        fill(ctx, color: warning ? (SKColor(hex: "C83030") ?? .red) : paper, CGRect(x: size.width * 0.20, y: size.height * 0.20, width: size.width * 0.60, height: size.height * 0.26))
        fill(ctx, color: wood, CGRect(x: size.width * 0.46, y: size.height * 0.46, width: size.width * 0.08, height: size.height * 0.28))
        if warning {
            fill(ctx, color: paper, CGRect(x: size.width * 0.46, y: size.height * 0.25, width: size.width * 0.08, height: size.height * 0.16))
        } else {
            fill(ctx, color: SKColor(hex: "484860") ?? .darkGray, CGRect(x: size.width * 0.28, y: size.height * 0.28, width: size.width * 0.30, height: size.height * 0.05))
            fill(ctx, color: SKColor(hex: "484860") ?? .darkGray, CGRect(x: size.width * 0.28, y: size.height * 0.36, width: size.width * 0.22, height: size.height * 0.05))
        }
    }

    private static func drawRock(in ctx: CGContext, size: CGSize) {
        shadowBase(in: ctx, size: size, width: 0.40)
        fill(ctx, color: SKColor(hex: "7A7A7A") ?? .gray, CGRect(x: size.width * 0.22, y: size.height * 0.34, width: size.width * 0.50, height: size.height * 0.28))
        fill(ctx, color: SKColor(hex: "B0B0B0") ?? .lightGray, CGRect(x: size.width * 0.28, y: size.height * 0.38, width: size.width * 0.18, height: size.height * 0.08))
    }

    private static func drawBrick(in ctx: CGContext, size: CGSize) {
        let brick = GamePalette.brickWall
        fill(ctx, color: brick, CGRect(origin: .zero, size: size))
        let mortar = SKColor(hex: "7A4028") ?? .brown
        fill(ctx, color: mortar, CGRect(x: 0, y: size.height * 0.28, width: size.width, height: size.height * 0.04))
        fill(ctx, color: mortar, CGRect(x: 0, y: size.height * 0.60, width: size.width, height: size.height * 0.04))
        fill(ctx, color: mortar, CGRect(x: size.width * 0.30, y: 0, width: size.width * 0.04, height: size.height * 0.28))
        fill(ctx, color: mortar, CGRect(x: size.width * 0.62, y: size.height * 0.28, width: size.width * 0.04, height: size.height * 0.32))
        fill(ctx, color: mortar, CGRect(x: size.width * 0.18, y: size.height * 0.60, width: size.width * 0.04, height: size.height * 0.40))
    }

    private static func drawFountain(in ctx: CGContext, size: CGSize) {
        shadowBase(in: ctx, size: size, width: 0.56)
        fill(ctx, color: GamePalette.concreteShadow, CGRect(x: size.width * 0.18, y: size.height * 0.54, width: size.width * 0.64, height: size.height * 0.14))
        fill(ctx, color: GamePalette.concreteWall, CGRect(x: size.width * 0.24, y: size.height * 0.50, width: size.width * 0.52, height: size.height * 0.12))
        fill(ctx, color: GamePalette.waterDeep, CGRect(x: size.width * 0.30, y: size.height * 0.54, width: size.width * 0.40, height: size.height * 0.06))
        fill(ctx, color: GamePalette.concreteWall, CGRect(x: size.width * 0.44, y: size.height * 0.22, width: size.width * 0.12, height: size.height * 0.28))
        fill(ctx, color: GamePalette.waterHighlight, CGRect(x: size.width * 0.48, y: size.height * 0.12, width: size.width * 0.04, height: size.height * 0.16))
    }

    private static func drawBird(in ctx: CGContext, size: CGSize) {
        shadowBase(in: ctx, size: size, width: 0.30)
        fill(ctx, color: SKColor(hex: "7F858C") ?? .gray, CGRect(x: size.width * 0.24, y: size.height * 0.40, width: size.width * 0.42, height: size.height * 0.20))
        fill(ctx, color: paper, CGRect(x: size.width * 0.44, y: size.height * 0.30, width: size.width * 0.16, height: size.height * 0.12))
        fill(ctx, color: SKColor(hex: "D97A2B") ?? .orange, CGRect(x: size.width * 0.62, y: size.height * 0.34, width: size.width * 0.08, height: size.height * 0.06))
        fill(ctx, color: SKColor(hex: "C83030") ?? .red, CGRect(x: size.width * 0.50, y: size.height * 0.34, width: size.width * 0.05, height: size.height * 0.05))
    }

    private static func drawDog(in ctx: CGContext, size: CGSize) {
        shadowBase(in: ctx, size: size, width: 0.40)
        fill(ctx, color: SKColor(hex: "8B5C28") ?? .brown, CGRect(x: size.width * 0.22, y: size.height * 0.34, width: size.width * 0.42, height: size.height * 0.22))
        fill(ctx, color: SKColor(hex: "A07840") ?? .brown, CGRect(x: size.width * 0.56, y: size.height * 0.28, width: size.width * 0.18, height: size.height * 0.18))
        fill(ctx, color: ink, CGRect(x: size.width * 0.60, y: size.height * 0.34, width: size.width * 0.04, height: size.height * 0.04))
    }

    private static func drawBone(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: paper, CGRect(x: size.width * 0.26, y: size.height * 0.42, width: size.width * 0.48, height: size.height * 0.12))
        fill(ctx, color: paper, CGRect(x: size.width * 0.18, y: size.height * 0.36, width: size.width * 0.12, height: size.height * 0.12))
        fill(ctx, color: paper, CGRect(x: size.width * 0.70, y: size.height * 0.36, width: size.width * 0.12, height: size.height * 0.12))
    }

    private static func drawBall(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.28, y: size.height * 0.28, width: size.width * 0.44, height: size.height * 0.44))
        fill(ctx, color: paper, CGRect(x: size.width * 0.40, y: size.height * 0.32, width: size.width * 0.06, height: size.height * 0.36))
    }

    private static func drawBowl(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "5A5A5A") ?? .gray, CGRect(x: size.width * 0.24, y: size.height * 0.48, width: size.width * 0.52, height: size.height * 0.12))
        fill(ctx, color: SKColor(hex: "8AA9C4") ?? .systemBlue, CGRect(x: size.width * 0.30, y: size.height * 0.44, width: size.width * 0.40, height: size.height * 0.06))
    }

    private static func drawMicrophone(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: metalHi, CGRect(x: size.width * 0.40, y: size.height * 0.20, width: size.width * 0.18, height: size.height * 0.22))
        fill(ctx, color: metal, CGRect(x: size.width * 0.47, y: size.height * 0.42, width: size.width * 0.04, height: size.height * 0.26))
        fill(ctx, color: SKColor(hex: "484860") ?? .darkGray, CGRect(x: size.width * 0.34, y: size.height * 0.68, width: size.width * 0.30, height: size.height * 0.05))
    }

    private static func drawBoat(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: GamePalette.waterMid, CGRect(x: size.width * 0.18, y: size.height * 0.58, width: size.width * 0.64, height: size.height * 0.08))
        fill(ctx, color: wood, CGRect(x: size.width * 0.28, y: size.height * 0.44, width: size.width * 0.40, height: size.height * 0.12))
        fill(ctx, color: paper, CGRect(x: size.width * 0.52, y: size.height * 0.22, width: size.width * 0.10, height: size.height * 0.20))
    }

    private static func drawFootprints(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: GamePalette.dirtShadow, CGRect(x: size.width * 0.26, y: size.height * 0.32, width: size.width * 0.14, height: size.height * 0.24))
        fill(ctx, color: GamePalette.dirtShadow, CGRect(x: size.width * 0.56, y: size.height * 0.42, width: size.width * 0.14, height: size.height * 0.24))
    }

    private static func drawSubway(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: GamePalette.urbanBlue, CGRect(x: size.width * 0.18, y: size.height * 0.18, width: size.width * 0.64, height: size.height * 0.52))
        fill(ctx, color: paper, CGRect(x: size.width * 0.28, y: size.height * 0.30, width: size.width * 0.18, height: size.height * 0.16))
        fill(ctx, color: paper, CGRect(x: size.width * 0.54, y: size.height * 0.30, width: size.width * 0.18, height: size.height * 0.16))
        fill(ctx, color: ink, CGRect(x: size.width * 0.44, y: size.height * 0.52, width: size.width * 0.12, height: size.height * 0.12))
    }

    private static func drawCrane(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.22, y: size.height * 0.24, width: size.width * 0.12, height: size.height * 0.50))
        fill(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.34, y: size.height * 0.24, width: size.width * 0.42, height: size.height * 0.10))
        fill(ctx, color: ink, CGRect(x: size.width * 0.62, y: size.height * 0.34, width: size.width * 0.03, height: size.height * 0.20))
    }

    private static func drawStorefront(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: GamePalette.brickWall, CGRect(x: size.width * 0.16, y: size.height * 0.22, width: size.width * 0.68, height: size.height * 0.52))
        fill(ctx, color: SKColor(hex: "C83030") ?? .red, CGRect(x: size.width * 0.16, y: size.height * 0.22, width: size.width * 0.68, height: size.height * 0.10))
        fill(ctx, color: GamePalette.windowLit, CGRect(x: size.width * 0.26, y: size.height * 0.38, width: size.width * 0.18, height: size.height * 0.14))
        fill(ctx, color: GamePalette.windowDark, CGRect(x: size.width * 0.52, y: size.height * 0.38, width: size.width * 0.16, height: size.height * 0.24))
    }

    private static func drawBox(in ctx: CGContext, size: CGSize, tied: Bool) {
        fill(ctx, color: SKColor(hex: "C4955A") ?? .brown, CGRect(x: size.width * 0.22, y: size.height * 0.26, width: size.width * 0.56, height: size.height * 0.48))
        fill(ctx, color: SKColor(hex: "A07840") ?? .brown, CGRect(x: size.width * 0.22, y: size.height * 0.26, width: size.width * 0.56, height: size.height * 0.08))
        if tied {
            fill(ctx, color: SKColor(hex: "C83030") ?? .red, CGRect(x: size.width * 0.46, y: size.height * 0.26, width: size.width * 0.08, height: size.height * 0.48))
            fill(ctx, color: SKColor(hex: "C83030") ?? .red, CGRect(x: size.width * 0.22, y: size.height * 0.46, width: size.width * 0.56, height: size.height * 0.08))
        }
    }

    private static func drawLight(in ctx: CGContext, size: CGSize, portable: Bool) {
        if portable {
            fill(ctx, color: SKColor(hex: "484860") ?? .darkGray, CGRect(x: size.width * 0.22, y: size.height * 0.34, width: size.width * 0.30, height: size.height * 0.22))
            fill(ctx, color: GamePalette.windowLit, CGRect(x: size.width * 0.52, y: size.height * 0.36, width: size.width * 0.16, height: size.height * 0.18))
        } else {
            fill(ctx, color: GamePalette.windowLit, CGRect(x: size.width * 0.34, y: size.height * 0.18, width: size.width * 0.32, height: size.height * 0.32))
            fill(ctx, color: metal, CGRect(x: size.width * 0.44, y: size.height * 0.50, width: size.width * 0.12, height: size.height * 0.22))
        }
    }

    private static func drawBucket(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: metal, CGRect(x: size.width * 0.28, y: size.height * 0.30, width: size.width * 0.44, height: size.height * 0.36))
        stroke(ctx, color: metalHi, CGRect(x: size.width * 0.34, y: size.height * 0.20, width: size.width * 0.32, height: size.height * 0.14))
    }

    private static func drawPlank(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "A07840") ?? .brown, CGRect(x: size.width * 0.18, y: size.height * 0.34, width: size.width * 0.64, height: size.height * 0.18))
        fill(ctx, color: wood, CGRect(x: size.width * 0.24, y: size.height * 0.38, width: size.width * 0.04, height: size.height * 0.10))
        fill(ctx, color: wood, CGRect(x: size.width * 0.66, y: size.height * 0.38, width: size.width * 0.04, height: size.height * 0.10))
    }

    // MARK: - Items

    private static func drawBerry(in ctx: CGContext, size: CGSize, large: Bool) {
        let color = large ? (SKColor(hex: "C83030") ?? .red) : (SKColor(hex: "4A5FA0") ?? .systemBlue)
        fill(ctx, color: color, CGRect(x: size.width * 0.28, y: size.height * 0.30, width: size.width * 0.36, height: size.height * 0.34))
        fill(ctx, color: GamePalette.grassG3, CGRect(x: size.width * 0.40, y: size.height * 0.22, width: size.width * 0.10, height: size.height * 0.08))
        fill(ctx, color: paper, CGRect(x: size.width * 0.50, y: size.height * 0.36, width: size.width * 0.05, height: size.height * 0.05))
    }

    private static func drawAcorn(in ctx: CGContext, size: CGSize) {
        shadowBase(in: ctx, size: size, width: 0.28)
        fill(ctx, color: SKColor(hex: "8F5C30") ?? .brown, CGRect(x: size.width * 0.32, y: size.height * 0.34, width: size.width * 0.30, height: size.height * 0.30))
        fill(ctx, color: SKColor(hex: "B87A44") ?? .brown, CGRect(x: size.width * 0.36, y: size.height * 0.40, width: size.width * 0.10, height: size.height * 0.12))
        fill(ctx, color: wood, CGRect(x: size.width * 0.28, y: size.height * 0.24, width: size.width * 0.38, height: size.height * 0.14))
        fill(ctx, color: SKColor(hex: "6A4524") ?? wood, CGRect(x: size.width * 0.34, y: size.height * 0.26, width: size.width * 0.10, height: size.height * 0.05))
        fill(ctx, color: wood, CGRect(x: size.width * 0.46, y: size.height * 0.18, width: size.width * 0.04, height: size.height * 0.08))
        fill(ctx, color: paper, CGRect(x: size.width * 0.54, y: size.height * 0.43, width: size.width * 0.04, height: size.height * 0.04))
    }

    private static func drawSnackBar(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "7A4028") ?? .brown, CGRect(x: size.width * 0.24, y: size.height * 0.34, width: size.width * 0.52, height: size.height * 0.22))
        fill(ctx, color: paper, CGRect(x: size.width * 0.24, y: size.height * 0.34, width: size.width * 0.14, height: size.height * 0.22))
    }

    private static func drawDrink(in ctx: CGContext, size: CGSize, sealed: Bool) {
        let body = sealed ? (SKColor(hex: "C47A52") ?? .systemOrange) : (SKColor(hex: "D4B030") ?? .yellow)
        fill(ctx, color: body, CGRect(x: size.width * 0.34, y: size.height * 0.24, width: size.width * 0.28, height: size.height * 0.42))
        fill(ctx, color: paper, CGRect(x: size.width * 0.38, y: size.height * 0.34, width: size.width * 0.20, height: size.height * 0.12))
        if !sealed {
            fill(ctx, color: SKColor(hex: "C83030") ?? .red, CGRect(x: size.width * 0.58, y: size.height * 0.16, width: size.width * 0.06, height: size.height * 0.18))
        }
    }

    private static func drawBottle(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "7FBF9F") ?? .systemGreen, CGRect(x: size.width * 0.36, y: size.height * 0.20, width: size.width * 0.24, height: size.height * 0.48))
        fill(ctx, color: paper, CGRect(x: size.width * 0.40, y: size.height * 0.34, width: size.width * 0.16, height: size.height * 0.14))
    }

    private static func drawSnack(in ctx: CGContext, size: CGSize, glyph: String) {
        switch glyph {
        case "🍪":
            fill(ctx, color: SKColor(hex: "C4955A") ?? .brown, CGRect(x: size.width * 0.26, y: size.height * 0.28, width: size.width * 0.42, height: size.height * 0.42))
            fill(ctx, color: SKColor(hex: "7A5C2E") ?? .brown, CGRect(x: size.width * 0.34, y: size.height * 0.38, width: size.width * 0.05, height: size.height * 0.05))
        case "🥨":
            fill(ctx, color: SKColor(hex: "A85F3A") ?? .brown, CGRect(x: size.width * 0.26, y: size.height * 0.34, width: size.width * 0.42, height: size.height * 0.26))
        default:
            fill(ctx, color: SKColor(hex: "BF8F52") ?? .brown, CGRect(x: size.width * 0.24, y: size.height * 0.34, width: size.width * 0.52, height: size.height * 0.16))
        }
    }

    private static func drawWaterDrop(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: GamePalette.waterMid, CGRect(x: size.width * 0.34, y: size.height * 0.24, width: size.width * 0.24, height: size.height * 0.36))
        fill(ctx, color: GamePalette.waterHighlight, CGRect(x: size.width * 0.42, y: size.height * 0.30, width: size.width * 0.06, height: size.height * 0.12))
    }

    private static func drawBag(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "A07840") ?? .brown, CGRect(x: size.width * 0.28, y: size.height * 0.24, width: size.width * 0.44, height: size.height * 0.42))
        stroke(ctx, color: paper, CGRect(x: size.width * 0.36, y: size.height * 0.18, width: size.width * 0.28, height: size.height * 0.16))
    }

    private static func drawSparkleToken(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.42, y: size.height * 0.18, width: size.width * 0.10, height: size.height * 0.44))
        fill(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.28, y: size.height * 0.32, width: size.width * 0.38, height: size.height * 0.10))
    }

    private static func drawCoin(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.26, y: size.height * 0.24, width: size.width * 0.42, height: size.height * 0.42))
        fill(ctx, color: SKColor(hex: "F0E890") ?? .white, CGRect(x: size.width * 0.34, y: size.height * 0.32, width: size.width * 0.10, height: size.height * 0.10))
    }

    private static func drawKey(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.24, y: size.height * 0.40, width: size.width * 0.42, height: size.height * 0.08))
        stroke(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.52, y: size.height * 0.28, width: size.width * 0.18, height: size.height * 0.18))
    }

    private static func drawTag(in ctx: CGContext, size: CGSize, punched: Bool) {
        fill(ctx, color: paper, CGRect(x: size.width * 0.22, y: size.height * 0.30, width: size.width * 0.52, height: size.height * 0.26))
        if punched {
            fill(ctx, color: ink, CGRect(x: size.width * 0.60, y: size.height * 0.36, width: size.width * 0.06, height: size.height * 0.06))
        }
        fill(ctx, color: SKColor(hex: "C83030") ?? .red, CGRect(x: size.width * 0.28, y: size.height * 0.38, width: size.width * 0.18, height: size.height * 0.04))
    }

    private static func drawFeather(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: paper, CGRect(x: size.width * 0.34, y: size.height * 0.20, width: size.width * 0.24, height: size.height * 0.46))
        fill(ctx, color: GamePalette.urbanBlue, CGRect(x: size.width * 0.44, y: size.height * 0.20, width: size.width * 0.10, height: size.height * 0.12))
    }

    private static func drawPaper(in ctx: CGContext, size: CGSize, glyph: String) {
        fill(ctx, color: paper, CGRect(x: size.width * 0.24, y: size.height * 0.18, width: size.width * 0.44, height: size.height * 0.52))
        fill(ctx, color: ink, CGRect(x: size.width * 0.32, y: size.height * 0.30, width: size.width * 0.24, height: size.height * 0.04))
        fill(ctx, color: ink, CGRect(x: size.width * 0.32, y: size.height * 0.40, width: size.width * 0.18, height: size.height * 0.04))
        if glyph == "📰" {
            fill(ctx, color: SKColor(hex: "C47A52") ?? .orange, CGRect(x: size.width * 0.48, y: size.height * 0.30, width: size.width * 0.12, height: size.height * 0.18))
        }
    }

    private static func drawWhistle(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "D4B030") ?? .yellow, CGRect(x: size.width * 0.26, y: size.height * 0.34, width: size.width * 0.38, height: size.height * 0.18))
        fill(ctx, color: ink, CGRect(x: size.width * 0.54, y: size.height * 0.40, width: size.width * 0.12, height: size.height * 0.06))
    }

    private static func drawGear(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: metalHi, CGRect(x: size.width * 0.28, y: size.height * 0.28, width: size.width * 0.36, height: size.height * 0.36))
        fill(ctx, color: ink, CGRect(x: size.width * 0.40, y: size.height * 0.40, width: size.width * 0.12, height: size.height * 0.12))
        fill(ctx, color: metal, CGRect(x: size.width * 0.42, y: size.height * 0.18, width: size.width * 0.08, height: size.height * 0.12))
    }

    private static func drawThermos(in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "484860") ?? .darkGray, CGRect(x: size.width * 0.34, y: size.height * 0.20, width: size.width * 0.28, height: size.height * 0.48))
        fill(ctx, color: paper, CGRect(x: size.width * 0.38, y: size.height * 0.30, width: size.width * 0.20, height: size.height * 0.12))
    }

    // MARK: - Fallback

    private static func drawFallbackGlyph(_ glyph: String, in ctx: CGContext, size: CGSize) {
        fill(ctx, color: SKColor(hex: "2A2A30") ?? .darkGray, CGRect(origin: .zero, size: size))

#if canImport(UIKit)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedBoldSystemFont(ofSize: size.width * 0.42, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]
        let str = NSAttributedString(string: glyph, attributes: attrs)
        let lineSize = str.size()
        str.draw(in: CGRect(x: 0, y: (size.height - lineSize.height) / 2, width: size.width, height: lineSize.height))
#elseif canImport(AppKit)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size.width * 0.42, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let str = NSAttributedString(string: glyph, attributes: attrs)
        let lineSize = str.size()
        str.draw(in: CGRect(x: 0, y: (size.height - lineSize.height) / 2, width: size.width, height: lineSize.height))
#endif
    }
}
