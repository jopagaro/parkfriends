import CoreGraphics
import SpriteKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Procedurally draws all four park-friends characters in an Earthbound-ish
/// chunky top-down style: flat colours, black outlines, walk cycles.
@MainActor
enum CharacterSprites {

    enum WalkFrame: Int, CaseIterable { case a = 0, b = 1 }

    private static var cache: [String: SKTexture] = [:]

    static func texture(species: Species, frame: WalkFrame = .a) -> SKTexture {
        let key = "\(species.rawValue)-\(frame.rawValue)"
        if let t = cache[key] { return t }
        let image = render(species: species, frame: frame)
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        cache[key] = tex
        return tex
    }

    /// Warm up the cache off the critical path.
    static func preload() {
        for s in Species.allCases {
            for f in WalkFrame.allCases { _ = texture(species: s, frame: f) }
        }
    }

    // MARK: - Platform render bridge

#if canImport(UIKit)
    private static func render(species: Species, frame: WalkFrame) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { ctx in
            paint(species: species, frame: frame, ctx: ctx.cgContext)
        }
    }
#elseif canImport(AppKit)
    private static func render(species: Species, frame: WalkFrame) -> NSImage {
        let img = NSImage(size: CGSize(width: 128, height: 128))
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            // Flip to Y-down so drawing code matches iOS behaviour
            ctx.translateBy(x: 0, y: 128)
            ctx.scaleBy(x: 1, y: -1)
            paint(species: species, frame: frame, ctx: ctx)
        }
        img.unlockFocus()
        return img
    }
#endif

    // MARK: - Dispatch

    private static func paint(species: Species, frame: WalkFrame, ctx: CGContext) {
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        // Walk bob: frame B shifts body up 3 px, legs alternate
        let bob: CGFloat     = frame == .b ? -3 : 0
        let legSwing: CGFloat = frame == .b ?  5 : -5
        switch species {
        case .turtle:   drawTurtle(ctx,   bob, legSwing)
        case .squirrel: drawSquirrel(ctx, bob, legSwing)
        case .hedgehog: drawHedgehog(ctx, bob, legSwing)
        case .hamster:  drawHamster(ctx,  bob, legSwing)
        }
    }

    // MARK: - Drawing helpers

    /// Shorthand RGBA CGColor
    private static func col(_ r: CGFloat, _ g: CGFloat,
                             _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }

    private static let ink = CGColor(red: 0.10, green: 0.08, blue: 0.05, alpha: 1)

    /// Fill + optional stroke an ellipse, centred on (cx, cy).
    private static func ellipse(
        _ ctx: CGContext,
        cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat,
        fill: CGColor,
        stroke: CGColor? = nil, lw: CGFloat = 3
    ) {
        let rect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        ctx.setFillColor(fill)
        ctx.fillEllipse(in: rect)
        if let s = stroke {
            ctx.setStrokeColor(s)
            ctx.setLineWidth(lw)
            ctx.strokeEllipse(in: rect)
        }
    }

    private static func shadow(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, w: CGFloat) {
        ellipse(ctx, cx: cx, cy: cy, w: w, h: w * 0.25,
                fill: col(0, 0, 0, 0.22))
    }

    // MARK: - 🐢 Shelly the Turtle

    private static func drawTurtle(_ ctx: CGContext, _ bob: CGFloat, _ leg: CGFloat) {

        shadow(ctx, cx: 64, cy: 115, w: 52)

        // Rear feet
        ellipse(ctx, cx: 42 + leg * 0.3, cy: 99 + bob, w: 22, h: 12,
                fill: col(0.35, 0.62, 0.32), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 86 - leg * 0.3, cy: 99 + bob, w: 22, h: 12,
                fill: col(0.35, 0.62, 0.32), stroke: ink, lw: 2.5)

        // Shell body
        ellipse(ctx, cx: 64, cy: 71 + bob, w: 72, h: 56,
                fill: col(0.22, 0.42, 0.20), stroke: ink, lw: 4)

        // Shell segment patches (lighter)
        for (px, py) in [(64.0,68.0),(44.0,58.0),(84.0,58.0),(44.0,82.0),(84.0,82.0)] {
            ellipse(ctx, cx: px, cy: py + bob, w: 24, h: 18,
                    fill: col(0.35, 0.58, 0.32))
        }

        // Shell outline on top of patches
        let sr = CGRect(x: 28, y: 43 + bob, width: 72, height: 56)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(4)
        ctx.strokeEllipse(in: sr)

        // Subtle segment divider lines
        ctx.setStrokeColor(col(0.14, 0.28, 0.13))
        ctx.setLineWidth(1.5)
        for xs in [CGFloat(50), 78] {
            ctx.move(to: CGPoint(x: xs, y: 49 + bob))
            ctx.addLine(to: CGPoint(x: xs, y: 91 + bob))
            ctx.strokePath()
        }
        ctx.move(to: CGPoint(x: 31, y: 71 + bob))
        ctx.addLine(to: CGPoint(x: 97, y: 71 + bob))
        ctx.strokePath()

        // Front arms
        ellipse(ctx, cx: 27, cy: 72 + bob, w: 16, h: 24,
                fill: col(0.45, 0.75, 0.42), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 101, cy: 72 + bob, w: 16, h: 24,
                fill: col(0.45, 0.75, 0.42), stroke: ink, lw: 2.5)

        // Neck
        ellipse(ctx, cx: 52, cy: 50 + bob, w: 20, h: 14,
                fill: col(0.45, 0.75, 0.42), stroke: ink, lw: 2)

        // Head
        ellipse(ctx, cx: 48, cy: 34 + bob, w: 34, h: 30,
                fill: col(0.50, 0.82, 0.46), stroke: ink, lw: 3.5)

        // Eyes
        ellipse(ctx, cx: 40, cy: 30 + bob, w: 7, h: 8, fill: col(0.05, 0.05, 0.05))
        ellipse(ctx, cx: 54, cy: 28 + bob, w: 7, h: 8, fill: col(0.05, 0.05, 0.05))
        ellipse(ctx, cx: 41, cy: 28.5 + bob, w: 2.5, h: 2.5, fill: col(1, 1, 1, 0.9))
        ellipse(ctx, cx: 55, cy: 26.5 + bob, w: 2.5, h: 2.5, fill: col(1, 1, 1, 0.9))

        // Smile
        ctx.setStrokeColor(ink); ctx.setLineWidth(1.5)
        let sm = CGMutablePath()
        sm.move(to: CGPoint(x: 42, y: 40 + bob))
        sm.addQuadCurve(to: CGPoint(x: 56, y: 40 + bob),
                        control: CGPoint(x: 49, y: 45 + bob))
        ctx.addPath(sm); ctx.strokePath()
    }

    // MARK: - 🐿️ Nutsy the Squirrel

    private static func drawSquirrel(_ ctx: CGContext, _ bob: CGFloat, _ leg: CGFloat) {

        shadow(ctx, cx: 64, cy: 115, w: 46)

        // Big fluffy tail (drawn behind body)
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: 58, y: 90 + bob))
        tail.addCurve(to: CGPoint(x: 98, y: 22 + bob),
                      control1: CGPoint(x: 108, y: 88 + bob),
                      control2: CGPoint(x: 114, y: 40 + bob))
        tail.addCurve(to: CGPoint(x: 64, y: 68 + bob),
                      control1: CGPoint(x: 82, y: 10 + bob),
                      control2: CGPoint(x: 72, y: 30 + bob))
        tail.closeSubpath()
        ctx.setFillColor(col(0.65, 0.32, 0.12))
        ctx.addPath(tail); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(3)
        ctx.addPath(tail); ctx.strokePath()

        // Tail inner tuft (lighter)
        let inner = CGMutablePath()
        inner.move(to: CGPoint(x: 62, y: 84 + bob))
        inner.addCurve(to: CGPoint(x: 92, y: 26 + bob),
                       control1: CGPoint(x: 98, y: 80 + bob),
                       control2: CGPoint(x: 104, y: 44 + bob))
        inner.addCurve(to: CGPoint(x: 67, y: 70 + bob),
                       control1: CGPoint(x: 80, y: 18 + bob),
                       control2: CGPoint(x: 70, y: 36 + bob))
        inner.closeSubpath()
        ctx.setFillColor(col(0.82, 0.52, 0.24))
        ctx.addPath(inner); ctx.fillPath()

        // Legs
        ellipse(ctx, cx: 50 - leg * 0.5, cy: 100 + bob, w: 18, h: 13,
                fill: col(0.55, 0.28, 0.10), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 70 + leg * 0.5, cy: 102 + bob, w: 18, h: 13,
                fill: col(0.55, 0.28, 0.10), stroke: ink, lw: 2.5)

        // Body
        ellipse(ctx, cx: 58, cy: 76 + bob, w: 48, h: 42,
                fill: col(0.58, 0.32, 0.12), stroke: ink, lw: 3.5)

        // Belly
        ellipse(ctx, cx: 56, cy: 78 + bob, w: 26, h: 24,
                fill: col(0.84, 0.64, 0.36))

        // Arms
        ellipse(ctx, cx: 36, cy: 80 + bob, w: 14, h: 20,
                fill: col(0.55, 0.28, 0.10), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 80, cy: 80 + bob, w: 14, h: 20,
                fill: col(0.55, 0.28, 0.10), stroke: ink, lw: 2.5)

        // Ears
        ellipse(ctx, cx: 43, cy: 27 + bob, w: 14, h: 18,
                fill: col(0.55, 0.28, 0.10), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 67, cy: 25 + bob, w: 14, h: 18,
                fill: col(0.55, 0.28, 0.10), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 43, cy: 27 + bob, w: 7, h: 10, fill: col(0.88, 0.58, 0.58))
        ellipse(ctx, cx: 67, cy: 25 + bob, w: 7, h: 10, fill: col(0.88, 0.58, 0.58))

        // Head
        ellipse(ctx, cx: 55, cy: 46 + bob, w: 38, h: 34,
                fill: col(0.58, 0.32, 0.12), stroke: ink, lw: 3.5)

        // Cheeks / snout
        ellipse(ctx, cx: 52, cy: 54 + bob, w: 18, h: 12, fill: col(0.72, 0.46, 0.22))

        // Eyes
        ellipse(ctx, cx: 45, cy: 44 + bob, w: 8, h: 9, fill: col(0.05, 0.05, 0.05))
        ellipse(ctx, cx: 64, cy: 43 + bob, w: 8, h: 9, fill: col(0.05, 0.05, 0.05))
        ellipse(ctx, cx: 46, cy: 42.5 + bob, w: 3, h: 3, fill: col(1, 1, 1, 0.9))
        ellipse(ctx, cx: 65, cy: 41.5 + bob, w: 3, h: 3, fill: col(1, 1, 1, 0.9))

        // Nose
        ellipse(ctx, cx: 52, cy: 55 + bob, w: 5, h: 4, fill: col(0.88, 0.38, 0.38))
    }

    // MARK: - 🦔 Prickle the Hedgehog

    private static func drawHedgehog(_ ctx: CGContext, _ bob: CGFloat, _ leg: CGFloat) {

        shadow(ctx, cx: 64, cy: 115, w: 54)

        // Spiny dark back
        ellipse(ctx, cx: 64, cy: 55 + bob, w: 66, h: 54,
                fill: col(0.26, 0.16, 0.08), stroke: ink, lw: 4)

        // Individual spines
        ctx.setStrokeColor(col(0.18, 0.10, 0.04))
        ctx.setLineWidth(2.5)
        let spineCount = 16
        for i in 0..<spineCount {
            let angle = CGFloat(i) / CGFloat(spineCount) * .pi + 0.08
            let x1 = 64 + cos(angle) * 26
            let y1 = (55 + bob) - sin(angle) * 22
            let x2 = 64 + cos(angle) * 38
            let y2 = (55 + bob) - sin(angle) * 34
            ctx.move(to: CGPoint(x: x1, y: y1))
            ctx.addLine(to: CGPoint(x: x2, y: y2))
            ctx.strokePath()
        }

        // Smooth sandy belly
        ellipse(ctx, cx: 64, cy: 78 + bob, w: 54, h: 42,
                fill: col(0.86, 0.76, 0.56), stroke: ink, lw: 3.5)

        // Feet
        ellipse(ctx, cx: 49 - leg * 0.4, cy: 102 + bob, w: 22, h: 14,
                fill: col(0.55, 0.36, 0.20), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 79 + leg * 0.4, cy: 102 + bob, w: 22, h: 14,
                fill: col(0.55, 0.36, 0.20), stroke: ink, lw: 2.5)

        // Head
        ellipse(ctx, cx: 53, cy: 42 + bob, w: 40, h: 36,
                fill: col(0.32, 0.20, 0.10), stroke: ink, lw: 3.5)

        // Snout (pointy, lighter)
        ellipse(ctx, cx: 41, cy: 47 + bob, w: 18, h: 13,
                fill: col(0.80, 0.62, 0.42), stroke: ink, lw: 2)

        // Nose
        ellipse(ctx, cx: 34, cy: 47 + bob, w: 7, h: 5,
                fill: col(0.90, 0.42, 0.42))

        // Ear
        ellipse(ctx, cx: 64, cy: 27 + bob, w: 13, h: 16,
                fill: col(0.32, 0.20, 0.10), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 64, cy: 27 + bob, w: 7, h: 9, fill: col(0.90, 0.58, 0.58))

        // Eye
        ellipse(ctx, cx: 55, cy: 40 + bob, w: 9, h: 10,
                fill: col(0.05, 0.05, 0.05), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 56.5, cy: 38.5 + bob, w: 3.5, h: 3.5, fill: col(1, 1, 1, 0.9))
    }

    // MARK: - 🐹 Biscuit the Hamster

    private static func drawHamster(_ ctx: CGContext, _ bob: CGFloat, _ leg: CGFloat) {

        shadow(ctx, cx: 64, cy: 115, w: 60)

        // Feet
        ellipse(ctx, cx: 46 - leg * 0.5, cy: 104 + bob, w: 20, h: 13,
                fill: col(0.80, 0.60, 0.30), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 82 + leg * 0.5, cy: 104 + bob, w: 20, h: 13,
                fill: col(0.80, 0.60, 0.30), stroke: ink, lw: 2.5)

        // Big chubby body
        ellipse(ctx, cx: 64, cy: 80 + bob, w: 68, h: 52,
                fill: col(0.86, 0.62, 0.28), stroke: ink, lw: 4)

        // Belly highlight
        ellipse(ctx, cx: 64, cy: 82 + bob, w: 38, h: 30,
                fill: col(0.96, 0.84, 0.54))

        // Chunky cheek pouches
        ellipse(ctx, cx: 32, cy: 78 + bob, w: 30, h: 26,
                fill: col(0.92, 0.70, 0.34), stroke: ink, lw: 3)
        ellipse(ctx, cx: 96, cy: 78 + bob, w: 30, h: 26,
                fill: col(0.92, 0.70, 0.34), stroke: ink, lw: 3)

        // Tiny arms
        ellipse(ctx, cx: 33, cy: 92 + bob, w: 15, h: 11,
                fill: col(0.80, 0.60, 0.30), stroke: ink, lw: 2)
        ellipse(ctx, cx: 95, cy: 92 + bob, w: 15, h: 11,
                fill: col(0.80, 0.60, 0.30), stroke: ink, lw: 2)

        // Round ears
        ellipse(ctx, cx: 41, cy: 25 + bob, w: 22, h: 22,
                fill: col(0.86, 0.62, 0.28), stroke: ink, lw: 3.5)
        ellipse(ctx, cx: 87, cy: 25 + bob, w: 22, h: 22,
                fill: col(0.86, 0.62, 0.28), stroke: ink, lw: 3.5)
        ellipse(ctx, cx: 41, cy: 25 + bob, w: 12, h: 12, fill: col(0.96, 0.66, 0.66))
        ellipse(ctx, cx: 87, cy: 25 + bob, w: 12, h: 12, fill: col(0.96, 0.66, 0.66))

        // Head (large & round)
        ellipse(ctx, cx: 64, cy: 46 + bob, w: 50, h: 46,
                fill: col(0.86, 0.62, 0.28), stroke: ink, lw: 4)

        // Big cute eyes
        ellipse(ctx, cx: 50, cy: 43 + bob, w: 11, h: 12,
                fill: col(0.06, 0.04, 0.04), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 78, cy: 43 + bob, w: 11, h: 12,
                fill: col(0.06, 0.04, 0.04), stroke: ink, lw: 1.5)
        // Shine
        ellipse(ctx, cx: 52, cy: 41 + bob, w: 4.5, h: 4.5, fill: col(1, 1, 1, 0.95))
        ellipse(ctx, cx: 80, cy: 41 + bob, w: 4.5, h: 4.5, fill: col(1, 1, 1, 0.95))
        // Tiny secondary shine
        ellipse(ctx, cx: 56, cy: 46 + bob, w: 2, h: 2, fill: col(1, 1, 1, 0.6))
        ellipse(ctx, cx: 84, cy: 46 + bob, w: 2, h: 2, fill: col(1, 1, 1, 0.6))

        // Nose
        ellipse(ctx, cx: 64, cy: 54 + bob, w: 7, h: 6, fill: col(0.96, 0.56, 0.56))

        // Smile
        ctx.setStrokeColor(ink); ctx.setLineWidth(1.8)
        let sm = CGMutablePath()
        sm.move(to: CGPoint(x: 57, y: 60 + bob))
        sm.addQuadCurve(to: CGPoint(x: 71, y: 60 + bob),
                        control: CGPoint(x: 64, y: 65 + bob))
        ctx.addPath(sm); ctx.strokePath()
    }
}
