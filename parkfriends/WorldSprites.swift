import CoreGraphics
import SpriteKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Procedural sprites for all non-party humans and creatures in the park world.
/// Same pipeline as CharacterSprites — 128×128 canvas, flat colour + ink outlines.
@MainActor
enum WorldSprites {

    private static var cache: [String: SKTexture] = [:]

    static func texture(enemy kind: EnemyKind) -> SKTexture  {
        if let imported = ImportedArt.enemyTexture(kind: kind) ?? ImportedArt.placeholderTexture() {
            imported.filteringMode = .nearest
            return imported
        }
        return SKTexture()
    }
    static func texture(npc kind: NPCKind)     -> SKTexture  {
        if let imported = ImportedArt.npcTexture(kind: kind) ?? ImportedArt.placeholderTexture() {
            imported.filteringMode = .nearest
            return imported
        }
        return SKTexture()
    }
    static func texture(named key: String, draw: (CGContext) -> Void) -> SKTexture { tex(key, draw: draw) }
    static func overworldTexture(enemy kind: EnemyKind) -> SKTexture {
        texture(enemy: kind)
    }

    private static func tex(_ key: String, draw: (CGContext) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let t = SKTexture(image: render(draw))
        t.filteringMode = .nearest
        cache[key] = t
        return t
    }

    static func preload() {
        for k in EnemyKind.allCases { _ = texture(enemy: k) }
        for k in NPCKind.allCases   { _ = texture(npc: k)   }
        if let lamp = ImportedArt.lampTexture(city: true) { cache["lamp_city"] = lamp }
        if let lamp = ImportedArt.lampTexture(city: false) { cache["lamp_park"] = lamp }
    }

    // MARK: - World object helpers

    /// Returns an `SKNode` containing a pixel-art lamp post + animated glow cone.
    static func makeLampPost(city: Bool = true) -> SKNode {
        let root = SKNode()
        let key  = city ? "lamp_city" : "lamp_park"
        let tex  = cache[key] ?? ImportedArt.lampTexture(city: city) ?? ImportedArt.placeholderTexture() ?? SKTexture()

        let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 48, height: 96))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.zPosition   = GameConstants.ZPos.decor + 1
        root.addChild(sprite)

        // Warm glow cone beneath the lamp head
        let glowR: CGFloat = city ? 52 : 44
        let glow = SKShapeNode(ellipseOf: CGSize(width: glowR * 2.2, height: glowR * 0.7))
        glow.position    = CGPoint(x: 0, y: 110)
        glow.fillColor   = SKColor(red: 0.98, green: 0.90, blue: 0.50, alpha: 0.12)
        glow.strokeColor = .clear
        glow.zPosition   = GameConstants.ZPos.decor
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.18, duration: 1.8),
            .fadeAlpha(to: 0.08, duration: 1.8)
        ])))
        root.addChild(glow)

        // Small bright point at lantern centre
        let dot = SKShapeNode(circleOfRadius: 4)
        dot.position    = CGPoint(x: 0, y: 116)
        dot.fillColor   = SKColor(red: 1.0, green: 0.95, blue: 0.72, alpha: 0.88)
        dot.strokeColor = .clear
        dot.zPosition   = GameConstants.ZPos.decor + 2
        root.addChild(dot)

        return root
    }

    // MARK: - Render bridge

#if canImport(UIKit)
    private static func render(_ draw: (CGContext) -> Void) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { c in
            draw(c.cgContext)
        }
    }
#elseif canImport(AppKit)
    private static func render(_ draw: (CGContext) -> Void) -> NSImage {
        let img = NSImage(size: CGSize(width: 128, height: 128))
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            // Flip to Y-down so drawing code matches iOS behaviour
            ctx.translateBy(x: 0, y: 128)
            ctx.scaleBy(x: 1, y: -1)
            draw(ctx)
        }
        img.unlockFocus()
        return img
    }
#endif

    // MARK: - Shared helpers

    private static let ink = CGColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 1)

    private static func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func ellipse(_ ctx: CGContext,
                                 cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat,
                                 fill: CGColor, stroke: CGColor? = nil, lw: CGFloat = 3) {
        let r = CGRect(x: cx - w/2, y: cy - h/2, width: w, height: h)
        ctx.setFillColor(fill);   ctx.fillEllipse(in: r)
        if let s = stroke {
            ctx.setStrokeColor(s); ctx.setLineWidth(lw); ctx.strokeEllipse(in: r)
        }
    }

    private static func rect(_ ctx: CGContext,
                              x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                              fill: CGColor, stroke: CGColor? = nil, lw: CGFloat = 3, corner: CGFloat = 4) {
        let path = CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                          cornerWidth: corner, cornerHeight: corner, transform: nil)
        ctx.setFillColor(fill);   ctx.addPath(path); ctx.fillPath()
        if let s = stroke {
            ctx.setStrokeColor(s); ctx.setLineWidth(lw)
            ctx.addPath(path); ctx.strokePath()
        }
    }

    private static func shadow(_ ctx: CGContext, cx: CGFloat, cy: CGFloat = 114, w: CGFloat) {
        ellipse(ctx, cx: cx, cy: cy, w: w, h: w * 0.22, fill: c(0, 0, 0, 0.20))
    }

    // Standard human body — reused by most characters.
    // cx = horizontal centre.  skinTone, shirtCol, pantsCol, shoeCol passed in.
    private static func humanBody(_ ctx: CGContext,
                                  cx: CGFloat,
                                  skin: CGColor,
                                  shirt: CGColor,
                                  pants: CGColor,
                                  shoes: CGColor,
                                  bob: CGFloat = 0) {
        // Shoes
        ellipse(ctx, cx: cx-10, cy: 102+bob, w: 20, h: 12, fill: shoes, stroke: ink, lw: 2)
        ellipse(ctx, cx: cx+10, cy: 102+bob, w: 20, h: 12, fill: shoes, stroke: ink, lw: 2)
        // Legs
        ellipse(ctx, cx: cx-10, cy: 87+bob, w: 18, h: 22, fill: pants, stroke: ink, lw: 2)
        ellipse(ctx, cx: cx+10, cy: 87+bob, w: 18, h: 22, fill: pants, stroke: ink, lw: 2)
        // Torso
        ellipse(ctx, cx: cx, cy: 63+bob, w: 46, h: 38, fill: shirt, stroke: ink, lw: 3)
        // Arms
        ellipse(ctx, cx: cx-28, cy: 68+bob, w: 14, h: 26, fill: shirt, stroke: ink, lw: 2.5)
        ellipse(ctx, cx: cx+28, cy: 68+bob, w: 14, h: 26, fill: shirt, stroke: ink, lw: 2.5)
        // Hands
        ellipse(ctx, cx: cx-28, cy: 83+bob, w: 11, h: 11, fill: skin, stroke: ink, lw: 2)
        ellipse(ctx, cx: cx+28, cy: 83+bob, w: 11, h: 11, fill: skin, stroke: ink, lw: 2)
        // Neck
        ellipse(ctx, cx: cx, cy: 45+bob, w: 16, h: 12, fill: skin, stroke: ink, lw: 2)
        // Head
        ellipse(ctx, cx: cx, cy: 30+bob, w: 36, h: 32, fill: skin, stroke: ink, lw: 3)
        // Eyes
        ellipse(ctx, cx: cx-8, cy: 27+bob, w: 6, h: 6, fill: c(0.1,0.1,0.1))
        ellipse(ctx, cx: cx+8, cy: 27+bob, w: 6, h: 6, fill: c(0.1,0.1,0.1))
        ellipse(ctx, cx: cx-7, cy: 26+bob, w: 2.5, h: 2.5, fill: c(1,1,1,0.8))
        ellipse(ctx, cx: cx+9, cy: 26+bob, w: 2.5, h: 2.5, fill: c(1,1,1,0.8))
    }

    // MARK: - Enemies

    private static func drawEnemy(_ kind: EnemyKind, _ ctx: CGContext) {
        ctx.setAllowsAntialiasing(false)
        ctx.setShouldAntialias(false)
        switch kind {
        case .ranger:           drawRanger(ctx)
        case .sternAdult:       drawSternAdult(ctx)
        case .wasp:             drawWasp(ctx)
        case .goose:            drawGoose(ctx)
        case .raccoon:          drawRaccoon(ctx)
        case .pigeon:           drawPigeon(ctx)
        case .flockLeader:      drawFlockLeader(ctx)
        case .vendingMachine:   drawVendingMachine(ctx)
        case .skateboardKid:    drawSkateboardKid(ctx)
        case .grandGooseGerald: drawGrandGooseGerald(ctx)
        case .officerGrumble:   drawOfficerGrumble(ctx)
        case .foremanRex:       drawForemanRex(ctx)
        }
    }

    // ── Park Ranger ──────────────────────────────────────────────────────────
    private static func drawRanger(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 52)
        humanBody(ctx, cx: 64,
                  skin:  c(0.95, 0.80, 0.65),
                  shirt: c(0.25, 0.50, 0.25),   // ranger green
                  pants: c(0.60, 0.50, 0.30),   // khaki
                  shoes: c(0.28, 0.18, 0.08))   // dark brown boots

        // Belt with badge
        rect(ctx, x: 42, y: 71, w: 44, h: 7,
             fill: c(0.38, 0.24, 0.10), stroke: ink, lw: 1.5, corner: 2)
        ellipse(ctx, cx: 64, cy: 74, w: 10, h: 8, fill: c(0.85, 0.72, 0.10), stroke: ink, lw: 1.5)

        // Campaign hat — the most distinctive ranger feature
        // Hat brim (wide flat ellipse)
        ellipse(ctx, cx: 64, cy: 15, w: 58, h: 14, fill: c(0.45, 0.30, 0.12), stroke: ink, lw: 2.5)
        // Hat crown (pinched top)
        ellipse(ctx, cx: 64, cy: 9,  w: 32, h: 14, fill: c(0.42, 0.28, 0.10), stroke: ink, lw: 2.5)
        // Hat band
        ellipse(ctx, cx: 64, cy: 15, w: 30, h: 6,  fill: c(0.20, 0.14, 0.06))

        // Sunglasses
        ellipse(ctx, cx: 55, cy: 27, w: 13, h: 8, fill: c(0.05,0.05,0.05), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 73, cy: 27, w: 13, h: 8, fill: c(0.05,0.05,0.05), stroke: ink, lw: 1.5)
        ctx.setStrokeColor(ink); ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: 62, y: 27)); ctx.addLine(to: CGPoint(x: 66, y: 27))
        ctx.strokePath()
    }

    // ── Stern Adult ───────────────────────────────────────────────────────────
    private static func drawSternAdult(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 50)
        humanBody(ctx, cx: 64,
                  skin:  c(0.85, 0.68, 0.54),
                  shirt: c(0.20, 0.20, 0.28),   // charcoal suit
                  pants: c(0.18, 0.18, 0.24),   // dark slacks
                  shoes: c(0.12, 0.12, 0.14))   // black shoes

        // White shirt collar / tie visible at top of suit
        ellipse(ctx, cx: 64, cy: 47, w: 14, h: 10, fill: c(0.95,0.95,0.95))
        // Tie (thin dark rectangle)
        rect(ctx, x: 61, y: 48, w: 6, h: 16, fill: c(0.60, 0.08, 0.08), corner: 2)

        // Glasses
        ctx.setStrokeColor(c(0.15,0.10,0.05)); ctx.setLineWidth(2.5)
        ctx.stroke(CGRect(x: 50, y: 23, width: 12, height: 8))
        ctx.stroke(CGRect(x: 66, y: 23, width: 12, height: 8))
        ctx.move(to: CGPoint(x: 62, y: 27)); ctx.addLine(to: CGPoint(x: 66, y: 27))
        ctx.strokePath()

        // Dark hair (short, slicked)
        let hair = CGMutablePath()
        hair.addEllipse(in: CGRect(x: 46, y: 11, width: 36, height: 18))
        ctx.setFillColor(c(0.15, 0.10, 0.08))
        ctx.addPath(hair); ctx.fillPath()

        // Stern mouth (flat line)
        ctx.setStrokeColor(c(0.40, 0.18, 0.12)); ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 57, y: 37)); ctx.addLine(to: CGPoint(x: 71, y: 37))
        ctx.strokePath()
    }

    // ── Wasp ─────────────────────────────────────────────────────────────────
    private static func drawWasp(_ ctx: CGContext) {
        shadow(ctx, cx: 64, cy: 118, w: 40)

        // Wings (behind body)
        ellipse(ctx, cx: 42, cy: 55, w: 38, h: 22,
                fill: c(0.85, 0.92, 1.0, 0.55), stroke: c(0.4,0.5,0.7,0.8), lw: 2)
        ellipse(ctx, cx: 86, cy: 55, w: 38, h: 22,
                fill: c(0.85, 0.92, 1.0, 0.55), stroke: c(0.4,0.5,0.7,0.8), lw: 2)

        // Abdomen (lower, striped)
        ellipse(ctx, cx: 64, cy: 90, w: 30, h: 42, fill: c(0.95, 0.80, 0.05), stroke: ink, lw: 3)
        for i in 0..<4 {
            let yy = CGFloat(72 + i * 10)
            let stripeW: CGFloat = 28 - CGFloat(i) * 1.5
            ellipse(ctx, cx: 64, cy: yy, w: stripeW, h: 7, fill: c(0.08,0.08,0.08))
        }

        // Stinger
        let sting = CGMutablePath()
        sting.move(to: CGPoint(x: 58, y: 110))
        sting.addLine(to: CGPoint(x: 70, y: 110))
        sting.addLine(to: CGPoint(x: 64, y: 122))
        sting.closeSubpath()
        ctx.setFillColor(c(0.20, 0.12, 0.04)); ctx.addPath(sting); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2); ctx.addPath(sting); ctx.strokePath()

        // Thorax
        ellipse(ctx, cx: 64, cy: 58, w: 34, h: 28, fill: c(0.10, 0.10, 0.10), stroke: ink, lw: 3)

        // Head
        ellipse(ctx, cx: 64, cy: 36, w: 30, h: 26, fill: c(0.95, 0.80, 0.05), stroke: ink, lw: 3)

        // Compound eyes
        ellipse(ctx, cx: 52, cy: 33, w: 12, h: 12, fill: c(0.55, 0.05, 0.05), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 76, cy: 33, w: 12, h: 12, fill: c(0.55, 0.05, 0.05), stroke: ink, lw: 1.5)

        // Antennae
        ctx.setStrokeColor(c(0.10,0.10,0.10)); ctx.setLineWidth(2.5)
        ctx.move(to: CGPoint(x: 57, y: 25)); ctx.addLine(to: CGPoint(x: 44, y: 10))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: 71, y: 25)); ctx.addLine(to: CGPoint(x: 84, y: 10))
        ctx.strokePath()
        ellipse(ctx, cx: 44, cy: 9,  w: 7, h: 7, fill: c(0.10,0.10,0.10))
        ellipse(ctx, cx: 84, cy: 9,  w: 7, h: 7, fill: c(0.10,0.10,0.10))

        // Mandibles
        ctx.setStrokeColor(c(0.30, 0.20, 0.02)); ctx.setLineWidth(2.5)
        ctx.move(to: CGPoint(x: 58, y: 46)); ctx.addLine(to: CGPoint(x: 50, y: 52))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: 70, y: 46)); ctx.addLine(to: CGPoint(x: 78, y: 52))
        ctx.strokePath()
    }

    // ── Goose ─────────────────────────────────────────────────────────────────
    private static func drawGoose(_ ctx: CGContext) {
        shadow(ctx, cx: 64, cy: 116, w: 56)

        // Body — big white oval
        ellipse(ctx, cx: 64, cy: 80, w: 62, h: 48,
                fill: c(0.95, 0.95, 0.93), stroke: ink, lw: 3.5)

        // Wing detail — slightly grey overlay
        ellipse(ctx, cx: 64, cy: 76, w: 52, h: 36, fill: c(0.88, 0.88, 0.86))

        // Tail feathers
        let tail = CGMutablePath()
        tail.move(to:    CGPoint(x: 88, y: 82))
        tail.addCurve(to: CGPoint(x: 108, y: 72),
                      control1: CGPoint(x: 100, y: 88),
                      control2: CGPoint(x: 114, y: 80))
        tail.addCurve(to: CGPoint(x: 88, y: 68),
                      control1: CGPoint(x: 108, y: 62),
                      control2: CGPoint(x: 96, y: 66))
        tail.closeSubpath()
        ctx.setFillColor(c(0.90,0.90,0.88)); ctx.addPath(tail); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2.5); ctx.addPath(tail); ctx.strokePath()

        // Feet
        ellipse(ctx, cx: 48, cy: 108, w: 22, h: 12,
                fill: c(0.90, 0.55, 0.05), stroke: ink, lw: 2)
        ellipse(ctx, cx: 72, cy: 108, w: 22, h: 12,
                fill: c(0.90, 0.55, 0.05), stroke: ink, lw: 2)

        // Neck (black)
        let neck = CGMutablePath()
        neck.addEllipse(in: CGRect(x: 30, y: 38, width: 22, height: 40))
        ctx.setFillColor(c(0.08,0.08,0.08)); ctx.addPath(neck); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2.5); ctx.addPath(neck); ctx.strokePath()

        // Head (black, small)
        ellipse(ctx, cx: 38, cy: 32, w: 26, h: 24,
                fill: c(0.08,0.08,0.08), stroke: ink, lw: 3)

        // White cheek patch
        ellipse(ctx, cx: 32, cy: 34, w: 11, h: 9, fill: c(0.92,0.92,0.90))

        // Orange beak (wide, honk-ready)
        let beak = CGMutablePath()
        beak.move(to:    CGPoint(x: 24, y: 30))
        beak.addLine(to: CGPoint(x: 10, y: 32))
        beak.addLine(to: CGPoint(x: 24, y: 37))
        beak.closeSubpath()
        ctx.setFillColor(c(0.95, 0.55, 0.05)); ctx.addPath(beak); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2); ctx.addPath(beak); ctx.strokePath()

        // Angry eye (red tint)
        ellipse(ctx, cx: 42, cy: 28, w: 7, h: 7, fill: c(0.80, 0.05, 0.05))
        ellipse(ctx, cx: 43, cy: 27, w: 2.5, h: 2.5, fill: c(1,1,1,0.8))

        // Anger lines above eye
        ctx.setStrokeColor(c(0.70,0.05,0.05)); ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 36, y: 20)); ctx.addLine(to: CGPoint(x: 42, y: 24))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: 40, y: 19)); ctx.addLine(to: CGPoint(x: 44, y: 23))
        ctx.strokePath()
    }

    // ── Raccoon ───────────────────────────────────────────────────────────────
    private static func drawRaccoon(_ ctx: CGContext) {
        shadow(ctx, cx: 64, cy: 114, w: 52)

        // Ringed tail (drawn behind body)
        let tailCX: CGFloat = 98, tailCY: CGFloat = 82
        let rings: [(CGFloat,CGFloat,CGColor)] = [
            (28,20,c(0.30,0.28,0.26)), (22,16,c(0.72,0.70,0.68)),
            (16,11,c(0.30,0.28,0.26)), (10,7, c(0.72,0.70,0.68))
        ]
        for (w,h,col) in rings {
            ellipse(ctx, cx: tailCX, cy: tailCY, w: w, h: h,
                    fill: col, stroke: ink, lw: 1.5)
        }

        // Body
        ellipse(ctx, cx: 60, cy: 76, w: 54, h: 44,
                fill: c(0.58,0.56,0.52), stroke: ink, lw: 3.5)
        // Lighter belly
        ellipse(ctx, cx: 58, cy: 78, w: 30, h: 24, fill: c(0.80,0.78,0.74))

        // Feet
        ellipse(ctx, cx: 46, cy: 104, w: 20, h: 12,
                fill: c(0.22,0.18,0.14), stroke: ink, lw: 2)
        ellipse(ctx, cx: 72, cy: 104, w: 20, h: 12,
                fill: c(0.22,0.18,0.14), stroke: ink, lw: 2)

        // Arms (reaching forward — grabby pose)
        ellipse(ctx, cx: 32, cy: 74, w: 16, h: 22,
                fill: c(0.50,0.48,0.44), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 86, cy: 74, w: 16, h: 22,
                fill: c(0.50,0.48,0.44), stroke: ink, lw: 2.5)
        // Grabby hands (darker)
        ellipse(ctx, cx: 30, cy: 90, w: 14, h: 14,
                fill: c(0.22,0.18,0.14), stroke: ink, lw: 2)
        ellipse(ctx, cx: 88, cy: 90, w: 14, h: 14,
                fill: c(0.22,0.18,0.14), stroke: ink, lw: 2)

        // Head
        ellipse(ctx, cx: 58, cy: 44, w: 40, h: 36,
                fill: c(0.58,0.56,0.52), stroke: ink, lw: 3.5)

        // Bandit mask (black eye patches)
        ellipse(ctx, cx: 48, cy: 42, w: 15, h: 10, fill: c(0.10,0.08,0.06))
        ellipse(ctx, cx: 68, cy: 42, w: 15, h: 10, fill: c(0.10,0.08,0.06))
        // White above mask
        ellipse(ctx, cx: 48, cy: 37, w: 12, h: 8, fill: c(0.88,0.86,0.82))
        ellipse(ctx, cx: 68, cy: 37, w: 12, h: 8, fill: c(0.88,0.86,0.82))

        // Eyes (glinting with mischief)
        ellipse(ctx, cx: 48, cy: 42, w: 7, h: 7, fill: c(0.85,0.62,0.10))
        ellipse(ctx, cx: 68, cy: 42, w: 7, h: 7, fill: c(0.85,0.62,0.10))
        ellipse(ctx, cx: 49, cy: 41, w: 2.5, h: 2.5, fill: c(1,1,1,0.9))
        ellipse(ctx, cx: 69, cy: 41, w: 2.5, h: 2.5, fill: c(1,1,1,0.9))

        // Snout + nose
        ellipse(ctx, cx: 58, cy: 52, w: 16, h: 10, fill: c(0.72,0.70,0.66))
        ellipse(ctx, cx: 58, cy: 50, w: 7, h: 5, fill: c(0.18,0.14,0.10))

        // Sly grin
        ctx.setStrokeColor(c(0.25,0.18,0.10)); ctx.setLineWidth(1.8)
        let sm = CGMutablePath()
        sm.move(to: CGPoint(x: 50, y: 57))
        sm.addQuadCurve(to: CGPoint(x: 66, y: 57), control: CGPoint(x: 58, y: 63))
        ctx.addPath(sm); ctx.strokePath()
    }

    // ── Pigeon ────────────────────────────────────────────────────────────────
    private static func drawPigeon(_ ctx: CGContext) {
        shadow(ctx, cx: 64, cy: 116, w: 42)

        // Tail
        let tail = CGMutablePath()
        tail.move(to:    CGPoint(x: 50, y: 100))
        tail.addLine(to: CGPoint(x: 78, y: 100))
        tail.addLine(to: CGPoint(x: 82, y: 118))
        tail.addLine(to: CGPoint(x: 46, y: 118))
        tail.closeSubpath()
        ctx.setFillColor(c(0.52,0.50,0.54)); ctx.addPath(tail); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2); ctx.addPath(tail); ctx.strokePath()

        // Body
        ellipse(ctx, cx: 64, cy: 82, w: 52, h: 40,
                fill: c(0.62,0.60,0.64), stroke: ink, lw: 3.5)

        // Iridescent neck patch (green-purple shimmer hint)
        ellipse(ctx, cx: 58, cy: 68, w: 24, h: 18,
                fill: c(0.38, 0.65, 0.45), stroke: c(0.30,0.50,0.70), lw: 1.5)

        // Wings
        ellipse(ctx, cx: 46, cy: 84, w: 20, h: 30,
                fill: c(0.55,0.53,0.58), stroke: ink, lw: 2)
        ellipse(ctx, cx: 82, cy: 84, w: 20, h: 30,
                fill: c(0.55,0.53,0.58), stroke: ink, lw: 2)
        // Wing bar stripes
        for i in 0..<2 {
            ctx.setStrokeColor(c(0.32,0.30,0.34)); ctx.setLineWidth(2.5)
            ctx.move(to: CGPoint(x: 38, y: CGFloat(76 + i*8)))
            ctx.addLine(to: CGPoint(x: 54, y: CGFloat(76 + i*8)))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: 74, y: CGFloat(76 + i*8)))
            ctx.addLine(to: CGPoint(x: 90, y: CGFloat(76 + i*8)))
            ctx.strokePath()
        }

        // Feet (scaly orange)
        ellipse(ctx, cx: 52, cy: 106, w: 16, h: 10,
                fill: c(0.85, 0.50, 0.10), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 72, cy: 106, w: 16, h: 10,
                fill: c(0.85, 0.50, 0.10), stroke: ink, lw: 1.5)

        // Head (small, bobbing)
        ellipse(ctx, cx: 48, cy: 52, w: 30, h: 28,
                fill: c(0.58,0.56,0.60), stroke: ink, lw: 3)

        // Short beak
        let beak = CGMutablePath()
        beak.move(to:    CGPoint(x: 32, y: 50))
        beak.addLine(to: CGPoint(x: 22, y: 52))
        beak.addLine(to: CGPoint(x: 32, y: 56))
        beak.closeSubpath()
        ctx.setFillColor(c(0.72,0.68,0.64)); ctx.addPath(beak); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(1.5); ctx.addPath(beak); ctx.strokePath()
        // Nostril bump
        ellipse(ctx, cx: 30, cy: 51, w: 6, h: 4, fill: c(0.80,0.76,0.72))

        // Eye (beady orange)
        ellipse(ctx, cx: 54, cy: 49, w: 9, h: 9,
                fill: c(0.88, 0.42, 0.05), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 55, cy: 48, w: 3, h: 3, fill: c(1,1,1,0.9))
    }

    // ── Pigeon Flock Leader ───────────────────────────────────────────────────
    // Bigger, angrier pigeon. Red eyes. Wings raised. 1.25× scale.
    private static func drawFlockLeader(_ ctx: CGContext) {
        shadow(ctx, cx: 64, cy: 116, w: 52)

        let tail = CGMutablePath()
        tail.move(to:    CGPoint(x: 44, y: 98))
        tail.addLine(to: CGPoint(x: 84, y: 98))
        tail.addLine(to: CGPoint(x: 88, y: 118))
        tail.addLine(to: CGPoint(x: 40, y: 118))
        tail.closeSubpath()
        ctx.setFillColor(c(0.45, 0.43, 0.48)); ctx.addPath(tail); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2.5); ctx.addPath(tail); ctx.strokePath()

        // Puffed body (wider than pigeon)
        ellipse(ctx, cx: 64, cy: 78, w: 64, h: 50, fill: c(0.55, 0.53, 0.58), stroke: ink, lw: 4)
        // Iridescent neck patch
        ellipse(ctx, cx: 58, cy: 63, w: 30, h: 22, fill: c(0.30, 0.60, 0.40), stroke: c(0.25,0.45,0.65), lw: 1.5)

        // Wings raised (aggressive posture)
        ellipse(ctx, cx: 32, cy: 74, w: 22, h: 36, fill: c(0.48, 0.46, 0.52), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 96, cy: 74, w: 22, h: 36, fill: c(0.48, 0.46, 0.52), stroke: ink, lw: 2.5)
        // Wing bars
        for i in 0..<3 {
            ctx.setStrokeColor(c(0.28, 0.26, 0.30)); ctx.setLineWidth(2.5)
            ctx.move(to: CGPoint(x: 24, y: CGFloat(65 + i*8)))
            ctx.addLine(to: CGPoint(x: 42, y: CGFloat(65 + i*8)))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: 86, y: CGFloat(65 + i*8)))
            ctx.addLine(to: CGPoint(x: 104, y: CGFloat(65 + i*8)))
            ctx.strokePath()
        }

        // Feet
        ellipse(ctx, cx: 49, cy: 108, w: 18, h: 12, fill: c(0.80, 0.45, 0.08), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 75, cy: 106, w: 12, h: 9,  fill: c(0.80, 0.45, 0.08), stroke: ink, lw: 1.5) // one foot lifted

        // Head (larger)
        ellipse(ctx, cx: 46, cy: 46, w: 36, h: 34, fill: c(0.52, 0.50, 0.55), stroke: ink, lw: 3.5)

        // Beak
        let beak = CGMutablePath()
        beak.move(to: CGPoint(x: 27, y: 44)); beak.addLine(to: CGPoint(x: 15, y: 47))
        beak.addLine(to: CGPoint(x: 27, y: 52)); beak.closeSubpath()
        ctx.setFillColor(c(0.68, 0.64, 0.60)); ctx.addPath(beak); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(1.5); ctx.addPath(beak); ctx.strokePath()

        // RED eyes (no pupils — contempt)
        ellipse(ctx, cx: 53, cy: 42, w: 11, h: 11, fill: c(0.80, 0.10, 0.10), stroke: ink, lw: 2)
        ellipse(ctx, cx: 53, cy: 42, w: 5, h: 5, fill: c(0.96, 0.04, 0.04))

        // Angry brow lines
        ctx.setStrokeColor(c(0.60, 0.05, 0.05)); ctx.setLineWidth(2.5)
        ctx.move(to: CGPoint(x: 44, y: 33)); ctx.addLine(to: CGPoint(x: 56, y: 37)); ctx.strokePath()
        ctx.move(to: CGPoint(x: 48, y: 31)); ctx.addLine(to: CGPoint(x: 58, y: 35)); ctx.strokePath()
    }

    // ── Possessed Vending Machine ─────────────────────────────────────────────
    // Tall off-white rectangle. Glowing red eye display. Coin slot. No legs.
    private static func drawVendingMachine(_ ctx: CGContext) {
        shadow(ctx, cx: 64, cy: 118, w: 58)

        // Body — tall rounded rect
        let body = CGPath(roundedRect: CGRect(x: 22, y: 14, width: 84, height: 104),
                          cornerWidth: 8, cornerHeight: 8, transform: nil)
        ctx.setFillColor(c(0.82, 0.78, 0.72)); ctx.addPath(body); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(4); ctx.addPath(body); ctx.strokePath()

        // Side shadow / depth
        let side = CGPath(roundedRect: CGRect(x: 98, y: 16, width: 8, height: 100),
                          cornerWidth: 4, cornerHeight: 4, transform: nil)
        ctx.setFillColor(c(0.62, 0.58, 0.52)); ctx.addPath(side); ctx.fillPath()

        // Display screen (showing glowing red eyes)
        let screen = CGPath(roundedRect: CGRect(x: 30, y: 18, width: 68, height: 44),
                            cornerWidth: 4, cornerHeight: 4, transform: nil)
        ctx.setFillColor(c(0.08, 0.04, 0.04)); ctx.addPath(screen); ctx.fillPath()
        ctx.setStrokeColor(c(0.80, 0.10, 0.10)); ctx.setLineWidth(2)
        ctx.addPath(screen); ctx.strokePath()

        // Glowing eyes on screen
        ellipse(ctx, cx: 50, cy: 40, w: 18, h: 14, fill: c(0.92, 0.08, 0.08))
        ellipse(ctx, cx: 78, cy: 40, w: 18, h: 14, fill: c(0.92, 0.08, 0.08))
        ellipse(ctx, cx: 50, cy: 40, w: 9, h: 7,   fill: c(1.0, 0.50, 0.50))
        ellipse(ctx, cx: 78, cy: 40, w: 9, h: 7,   fill: c(1.0, 0.50, 0.50))
        // Angry brow slants on screen
        ctx.setStrokeColor(c(0.92, 0.08, 0.08)); ctx.setLineWidth(3)
        ctx.move(to: CGPoint(x: 39, y: 30)); ctx.addLine(to: CGPoint(x: 61, y: 34)); ctx.strokePath()
        ctx.move(to: CGPoint(x: 89, y: 30)); ctx.addLine(to: CGPoint(x: 67, y: 34)); ctx.strokePath()

        // Faded brand logo (illegible shapes)
        ctx.setFillColor(c(0.65, 0.62, 0.56)); ctx.fill(CGRect(x: 34, y: 66, width: 36, height: 8))
        ctx.setFillColor(c(0.70, 0.66, 0.60)); ctx.fill(CGRect(x: 34, y: 76, width: 24, height: 6))

        // Coin slot (prominent, slightly bent)
        rect(ctx, x: 50, y: 87, w: 28, h: 8,
             fill: c(0.40, 0.36, 0.30), stroke: ink, lw: 1.5, corner: 3)
        // Slot opening (darker)
        ctx.setFillColor(c(0.12, 0.10, 0.08))
        ctx.fill(CGRect(x: 55, y: 89, width: 18, height: 4))

        // Dispense tray at bottom
        rect(ctx, x: 24, y: 100, w: 80, h: 16,
             fill: c(0.60, 0.56, 0.50), stroke: ink, lw: 2, corner: 3)
        rect(ctx, x: 28, y: 103, w: 72, h: 10,
             fill: c(0.18, 0.14, 0.12), stroke: nil, corner: 2)
    }

    // ── Skateboard Kid ────────────────────────────────────────────────────────
    // Teen, oversized hoodie, hair entirely obscuring face, board.
    private static func drawSkateboardKid(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 52)

        // Board (below feet)
        rect(ctx, x: 26, y: 104, w: 76, h: 10,
             fill: c(0.28, 0.26, 0.40), stroke: ink, lw: 2, corner: 4)
        // Wheels (4 dots)
        for wx in [CGFloat(32), 46, 82, 96] {
            ellipse(ctx, cx: wx, cy: 113, w: 9, h: 9, fill: c(0.15, 0.15, 0.15), stroke: ink, lw: 1.5)
        }
        // Grip tape texture
        ctx.setFillColor(c(0.20, 0.18, 0.30))
        for i in 0..<8 {
            ctx.fill(CGRect(x: CGFloat(30 + i*9), y: 105, width: 5, height: 3))
        }

        // Legs (loose pants — baggy)
        ellipse(ctx, cx: 48, cy: 92, w: 22, h: 18, fill: c(0.22, 0.22, 0.30), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 76, cy: 92, w: 22, h: 18, fill: c(0.22, 0.22, 0.30), stroke: ink, lw: 2.5)
        // Shoes (chunky)
        ellipse(ctx, cx: 46, cy: 104, w: 22, h: 12, fill: c(0.12, 0.12, 0.14), stroke: ink, lw: 2)
        ellipse(ctx, cx: 78, cy: 104, w: 22, h: 12, fill: c(0.12, 0.12, 0.14), stroke: ink, lw: 2)

        // Oversized hoodie body
        ellipse(ctx, cx: 64, cy: 68, w: 60, h: 46, fill: c(0.35, 0.35, 0.62), stroke: ink, lw: 3.5)
        // Hood drape (extra width at top)
        ellipse(ctx, cx: 64, cy: 50, w: 52, h: 28, fill: c(0.35, 0.35, 0.62), stroke: ink, lw: 3)
        // Pocket (kangaroo pouch)
        rect(ctx, x: 46, y: 73, w: 36, h: 16,
             fill: c(0.28, 0.28, 0.52), stroke: ink, lw: 2, corner: 4)

        // Arms (hooded, sleeves hang down)
        ellipse(ctx, cx: 26, cy: 72, w: 16, h: 28, fill: c(0.35, 0.35, 0.62), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 102, cy: 72, w: 16, h: 28, fill: c(0.35, 0.35, 0.62), stroke: ink, lw: 2.5)
        // Hands barely visible
        ellipse(ctx, cx: 25, cy: 88, w: 13, h: 10, fill: c(0.78, 0.62, 0.50), stroke: ink, lw: 2)
        ellipse(ctx, cx: 103, cy: 88, w: 13, h: 10, fill: c(0.78, 0.62, 0.50), stroke: ink, lw: 2)

        // Head — hair completely covers face
        ellipse(ctx, cx: 64, cy: 28, w: 48, h: 42, fill: c(0.18, 0.12, 0.06), stroke: ink, lw: 3.5)
        // Hair cascading forward (dark mass)
        let hair = CGMutablePath()
        hair.addEllipse(in: CGRect(x: 28, y: 18, width: 72, height: 36))
        ctx.setFillColor(c(0.14, 0.09, 0.04)); ctx.addPath(hair); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2); ctx.addPath(hair); ctx.strokePath()
        // Hair strands (darker lines)
        ctx.setStrokeColor(c(0.10, 0.06, 0.02)); ctx.setLineWidth(2)
        for x in stride(from: 34.0, through: 92.0, by: 8) {
            ctx.move(to: CGPoint(x: x, y: 18)); ctx.addLine(to: CGPoint(x: x - 4, y: 48))
            ctx.strokePath()
        }

        // Earbuds (white dots visible through hair)
        ellipse(ctx, cx: 37, cy: 34, w: 6, h: 6, fill: c(0.92, 0.92, 0.92), stroke: ink, lw: 1)
        ellipse(ctx, cx: 91, cy: 34, w: 6, h: 6, fill: c(0.92, 0.92, 0.92), stroke: ink, lw: 1)
        // Earbud wires
        ctx.setStrokeColor(c(0.85, 0.85, 0.85)); ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: 37, y: 37)); ctx.addLine(to: CGPoint(x: 50, y: 58)); ctx.strokePath()
        ctx.move(to: CGPoint(x: 91, y: 37)); ctx.addLine(to: CGPoint(x: 78, y: 58)); ctx.strokePath()
    }

    // ── Grand Goose Gerald (Boss) ─────────────────────────────────────────────
    // 3× standard goose size. Tiny mayoral sash. Even more furious.
    private static func drawGrandGooseGerald(_ ctx: CGContext) {
        shadow(ctx, cx: 64, cy: 116, w: 80)

        // Body — massive white oval
        ellipse(ctx, cx: 64, cy: 80, w: 96, h: 70, fill: c(0.96, 0.96, 0.94), stroke: ink, lw: 4.5)
        // Wing detail
        ellipse(ctx, cx: 64, cy: 75, w: 80, h: 54, fill: c(0.88, 0.88, 0.86))

        // Tail feathers (dramatic)
        for i in 0..<3 {
            let tx = CGFloat(90 + i * 8)
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: tx - 4, y: 78))
            tail.addCurve(to: CGPoint(x: tx + 14, y: 62),
                          control1: CGPoint(x: tx + 10, y: 84),
                          control2: CGPoint(x: tx + 20, y: 72))
            tail.addCurve(to: CGPoint(x: tx, y: 72),
                          control1: CGPoint(x: tx + 10, y: 56),
                          control2: CGPoint(x: tx + 2, y: 64))
            tail.closeSubpath()
            ctx.setFillColor(c(0.90, 0.90, 0.88)); ctx.addPath(tail); ctx.fillPath()
            ctx.setStrokeColor(ink); ctx.setLineWidth(2); ctx.addPath(tail); ctx.strokePath()
        }

        // Feet (big orange)
        ellipse(ctx, cx: 44, cy: 112, w: 28, h: 15, fill: c(0.95, 0.58, 0.06), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 78, cy: 112, w: 28, h: 15, fill: c(0.95, 0.58, 0.06), stroke: ink, lw: 2.5)

        // MAYORAL SASH (diagonal ribbon across body)
        let sash = CGMutablePath()
        sash.move(to: CGPoint(x: 22, y: 58))
        sash.addLine(to: CGPoint(x: 44, y: 58))
        sash.addLine(to: CGPoint(x: 96, y: 100))
        sash.addLine(to: CGPoint(x: 74, y: 100))
        sash.closeSubpath()
        ctx.setFillColor(c(0.10, 0.38, 0.80)); ctx.addPath(sash); ctx.fillPath()
        ctx.setStrokeColor(c(0.90, 0.78, 0.10)); ctx.setLineWidth(2); ctx.addPath(sash); ctx.strokePath()
        // Sash star/medal
        ellipse(ctx, cx: 58, cy: 79, w: 12, h: 12, fill: c(0.92, 0.80, 0.10), stroke: c(0.70, 0.58, 0.05), lw: 1.5)

        // Long black neck (S-curve)
        let neck = CGMutablePath()
        neck.move(to: CGPoint(x: 16, y: 44))
        neck.addCurve(to: CGPoint(x: 26, y: 74),
                      control1: CGPoint(x: 8, y: 58),
                      control2: CGPoint(x: 12, y: 70))
        neck.addCurve(to: CGPoint(x: 48, y: 50),
                      control1: CGPoint(x: 40, y: 78),
                      control2: CGPoint(x: 50, y: 68))
        neck.addCurve(to: CGPoint(x: 38, y: 24),
                      control1: CGPoint(x: 46, y: 32),
                      control2: CGPoint(x: 42, y: 28))
        neck.closeSubpath()
        ctx.setFillColor(c(0.06, 0.06, 0.06)); ctx.addPath(neck); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2.5); ctx.addPath(neck); ctx.strokePath()

        // Head (large black)
        ellipse(ctx, cx: 30, cy: 20, w: 36, h: 30, fill: c(0.06, 0.06, 0.06), stroke: ink, lw: 4)
        // White cheek patch (larger)
        ellipse(ctx, cx: 20, cy: 24, w: 16, h: 13, fill: c(0.93, 0.93, 0.91))

        // Big furious beak
        let beak = CGMutablePath()
        beak.move(to: CGPoint(x: 12, y: 16))
        beak.addLine(to: CGPoint(x: -4, y: 20))
        beak.addLine(to: CGPoint(x: -4, y: 27))
        beak.addLine(to: CGPoint(x: 12, y: 27))
        beak.closeSubpath()
        ctx.setFillColor(c(0.95, 0.58, 0.06)); ctx.addPath(beak); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2.5); ctx.addPath(beak); ctx.strokePath()
        // Tongue hint
        ellipse(ctx, cx: 4, cy: 24, w: 8, h: 5, fill: c(0.90, 0.35, 0.35))

        // Furious orange eye (big)
        ellipse(ctx, cx: 37, cy: 16, w: 10, h: 10, fill: c(0.85, 0.08, 0.08))
        ellipse(ctx, cx: 38, cy: 15, w: 4, h: 4, fill: c(1, 1, 1, 0.8))
        // Triple anger lines
        ctx.setStrokeColor(c(0.70, 0.04, 0.04)); ctx.setLineWidth(2.5)
        for i in 0..<3 {
            let y = CGFloat(4 + i * 4)
            ctx.move(to: CGPoint(x: 28, y: y)); ctx.addLine(to: CGPoint(x: 42, y: y + 3))
            ctx.strokePath()
        }
    }

    // ── Officer Grumble (Boss) ────────────────────────────────────────────────
    // Round police officer. Navy uniform. Enormous mustache. Donut holster.
    private static func drawOfficerGrumble(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 70)

        // Very round body (wider than standard)
        ellipse(ctx, cx: 64, cy: 74, w: 80, h: 60, fill: c(0.10, 0.22, 0.42), stroke: ink, lw: 4)
        // Belt (wide)
        ellipse(ctx, cx: 64, cy: 90, w: 74, h: 16, fill: c(0.20, 0.16, 0.08), stroke: ink, lw: 2)
        // Belt buckle
        rect(ctx, x: 56, y: 84, w: 16, h: 12, fill: c(0.85, 0.72, 0.10), stroke: ink, lw: 1.5, corner: 2)

        // Donut holster (LEFT side)
        rect(ctx, x: 18, y: 83, w: 18, h: 14, fill: c(0.28, 0.20, 0.10), stroke: ink, lw: 1.5, corner: 3)
        // Donut (pink with sprinkles)
        ellipse(ctx, cx: 27, cy: 90, w: 14, h: 10, fill: c(0.95, 0.65, 0.72))
        ellipse(ctx, cx: 27, cy: 90, w: 6, h: 4,   fill: c(0.88, 0.42, 0.54))
        // Sprinkles
        for (sx, sy, sc) in [(24.0,87.0,c(0.30,0.70,0.30)),(30.0,92.0,c(0.90,0.30,0.30)),(22.0,92.0,c(0.30,0.30,0.90))] {
            ellipse(ctx, cx: sx, cy: sy, w: 3, h: 2, fill: sc)
        }

        // Arms (chubby)
        ellipse(ctx, cx: 20, cy: 70, w: 18, h: 30, fill: c(0.10, 0.22, 0.42), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 108, cy: 70, w: 18, h: 30, fill: c(0.10, 0.22, 0.42), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 18, cy: 88, w: 14, h: 12, fill: c(0.85, 0.68, 0.54), stroke: ink, lw: 2)
        ellipse(ctx, cx: 110, cy: 88, w: 14, h: 12, fill: c(0.85, 0.68, 0.54), stroke: ink, lw: 2)

        // Badge (prominent, chest left-center)
        let badge = CGPath(roundedRect: CGRect(x: 74, y: 58, width: 18, height: 22),
                           cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.setFillColor(c(0.85, 0.72, 0.10)); ctx.addPath(badge); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(1.5); ctx.addPath(badge); ctx.strokePath()
        ellipse(ctx, cx: 83, cy: 69, w: 9, h: 11, fill: c(0.10, 0.22, 0.42))

        // Legs
        ellipse(ctx, cx: 48, cy: 102, w: 26, h: 22, fill: c(0.10, 0.22, 0.42), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 80, cy: 102, w: 26, h: 22, fill: c(0.10, 0.22, 0.42), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 46, cy: 113, w: 24, h: 13, fill: c(0.14, 0.14, 0.16), stroke: ink, lw: 2)
        ellipse(ctx, cx: 82, cy: 113, w: 24, h: 13, fill: c(0.14, 0.14, 0.16), stroke: ink, lw: 2)

        // Round head (bigger than standard)
        ellipse(ctx, cx: 64, cy: 30, w: 56, h: 50, fill: c(0.82, 0.64, 0.50), stroke: ink, lw: 4)

        // Police cap (flat-topped)
        ellipse(ctx, cx: 64, cy: 8, w: 68, h: 16, fill: c(0.10, 0.22, 0.42), stroke: ink, lw: 2.5)
        rect(ctx, x: 28, y: 6, w: 72, h: 14, fill: c(0.10, 0.22, 0.42), stroke: ink, lw: 2, corner: 3)
        // Cap badge
        ellipse(ctx, cx: 64, cy: 10, w: 14, h: 12, fill: c(0.85, 0.72, 0.10), stroke: ink, lw: 1.5)
        // Cap brim
        ellipse(ctx, cx: 64, cy: 17, w: 72, h: 10, fill: c(0.08, 0.18, 0.36), stroke: ink, lw: 2)

        // THE MUSTACHE (the largest mustache in the game)
        let mPath = CGMutablePath()
        mPath.move(to:    CGPoint(x: 36, y: 38))
        mPath.addCurve(to: CGPoint(x: 92, y: 38),
                       control1: CGPoint(x: 36, y: 26),
                       control2: CGPoint(x: 92, y: 26))
        mPath.addCurve(to: CGPoint(x: 64, y: 36),
                       control1: CGPoint(x: 80, y: 44),
                       control2: CGPoint(x: 72, y: 44))
        mPath.addCurve(to: CGPoint(x: 36, y: 38),
                       control1: CGPoint(x: 56, y: 44),
                       control2: CGPoint(x: 48, y: 44))
        mPath.closeSubpath()
        ctx.setFillColor(c(0.18, 0.10, 0.04)); ctx.addPath(mPath); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2.5); ctx.addPath(mPath); ctx.strokePath()

        // Eyes (small, disapproving)
        ellipse(ctx, cx: 50, cy: 25, w: 8, h: 8, fill: c(0.08, 0.08, 0.08))
        ellipse(ctx, cx: 78, cy: 25, w: 8, h: 8, fill: c(0.08, 0.08, 0.08))
        ellipse(ctx, cx: 51, cy: 23, w: 3, h: 3, fill: c(1, 1, 1, 0.8))
        ellipse(ctx, cx: 79, cy: 23, w: 3, h: 3, fill: c(1, 1, 1, 0.8))
        // Stern brow
        ctx.setStrokeColor(c(0.18, 0.10, 0.04)); ctx.setLineWidth(3)
        ctx.move(to: CGPoint(x: 42, y: 16)); ctx.addLine(to: CGPoint(x: 58, y: 20)); ctx.strokePath()
        ctx.move(to: CGPoint(x: 86, y: 16)); ctx.addLine(to: CGPoint(x: 70, y: 20)); ctx.strokePath()
    }

    // ── Foreman Rex (Boss) ────────────────────────────────────────────────────
    // Enormous. Yellow hard hat. Orange vest. Clipboard + jackhammer. Both in use.
    private static func drawForemanRex(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 76)

        // Chunky legs
        ellipse(ctx, cx: 46, cy: 96, w: 28, h: 24, fill: c(0.28, 0.22, 0.12), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 82, cy: 96, w: 28, h: 24, fill: c(0.28, 0.22, 0.12), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 44, cy: 109, w: 28, h: 15, fill: c(0.22, 0.18, 0.10), stroke: ink, lw: 2)
        ellipse(ctx, cx: 84, cy: 109, w: 28, h: 15, fill: c(0.22, 0.18, 0.10), stroke: ink, lw: 2)

        // Torso — enormous, wearing orange safety vest
        ellipse(ctx, cx: 64, cy: 68, w: 82, h: 56, fill: c(0.55, 0.55, 0.55), stroke: ink, lw: 4)
        // Orange vest panels (left and right, with gap in center)
        let vestL = CGPath(roundedRect: CGRect(x: 22, y: 42, width: 30, height: 46),
                           cornerWidth: 4, cornerHeight: 4, transform: nil)
        let vestR = CGPath(roundedRect: CGRect(x: 76, y: 42, width: 30, height: 46),
                           cornerWidth: 4, cornerHeight: 4, transform: nil)
        ctx.setFillColor(c(0.92, 0.52, 0.05)); ctx.addPath(vestL); ctx.fillPath()
        ctx.addPath(vestR); ctx.fillPath()
        ctx.setStrokeColor(ink); ctx.setLineWidth(2)
        ctx.addPath(vestL); ctx.strokePath()
        ctx.addPath(vestR); ctx.strokePath()
        // Reflective stripe on vest
        ctx.setFillColor(c(0.96, 0.92, 0.30))
        ctx.fill(CGRect(x: 23, y: 74, width: 28, height: 6))
        ctx.fill(CGRect(x: 77, y: 74, width: 28, height: 6))
        // Missing buttons (2 gaps on right vest)
        ctx.setFillColor(c(0.55, 0.55, 0.55))
        ctx.fill(CGRect(x: 88, y: 52, width: 6, height: 5))
        ctx.fill(CGRect(x: 88, y: 62, width: 6, height: 5))

        // LEFT ARM — holding clipboard
        ellipse(ctx, cx: 14, cy: 66, w: 18, h: 36, fill: c(0.55, 0.55, 0.55), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 14, cy: 87, w: 16, h: 14, fill: c(0.88, 0.72, 0.56), stroke: ink, lw: 2)
        // Clipboard
        rect(ctx, x: 2, y: 89, w: 22, h: 28, fill: c(0.85, 0.72, 0.50), stroke: ink, lw: 2, corner: 3)
        rect(ctx, x: 7, y: 84, w: 12, h: 8,  fill: c(0.60, 0.48, 0.30), stroke: ink, lw: 1.5, corner: 2)
        // Paper lines on clipboard
        ctx.setStrokeColor(c(0.40, 0.32, 0.20)); ctx.setLineWidth(1)
        for ly in stride(from: 96.0, through: 114.0, by: 4) {
            ctx.move(to: CGPoint(x: 5, y: ly)); ctx.addLine(to: CGPoint(x: 22, y: ly))
            ctx.strokePath()
        }

        // RIGHT ARM — holding jackhammer
        ellipse(ctx, cx: 114, cy: 66, w: 18, h: 36, fill: c(0.55, 0.55, 0.55), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 114, cy: 87, w: 16, h: 14, fill: c(0.88, 0.72, 0.56), stroke: ink, lw: 2)
        // Jackhammer (upside-down T shape)
        rect(ctx, x: 108, y: 92, w: 12, h: 30, fill: c(0.35, 0.35, 0.38), stroke: ink, lw: 2, corner: 3)
        rect(ctx, x: 100, y: 92, w: 28, h: 10, fill: c(0.38, 0.38, 0.42), stroke: ink, lw: 2, corner: 3)
        // Jackhammer bit/point
        rect(ctx, x: 111, y: 120, w: 6, h: 8, fill: c(0.65, 0.60, 0.50), stroke: ink, lw: 1.5, corner: 1)

        // Neck (thick)
        ellipse(ctx, cx: 64, cy: 44, w: 28, h: 18, fill: c(0.88, 0.72, 0.56), stroke: ink, lw: 2.5)

        // Head (large, stern)
        ellipse(ctx, cx: 64, cy: 28, w: 54, h: 46, fill: c(0.88, 0.72, 0.56), stroke: ink, lw: 4)

        // YELLOW HARD HAT
        ellipse(ctx, cx: 64, cy: 10, w: 66, h: 20, fill: c(0.96, 0.85, 0.04), stroke: ink, lw: 3)
        // Hat brim
        ellipse(ctx, cx: 64, cy: 18, w: 70, h: 12, fill: c(0.90, 0.78, 0.02), stroke: ink, lw: 2.5)
        // Hat crown
        ellipse(ctx, cx: 64, cy: 8, w: 54, h: 16, fill: c(0.96, 0.85, 0.04), stroke: ink, lw: 2)

        // Eyes (small, focused)
        ellipse(ctx, cx: 52, cy: 27, w: 8, h: 8, fill: c(0.08, 0.06, 0.04))
        ellipse(ctx, cx: 76, cy: 27, w: 8, h: 8, fill: c(0.08, 0.06, 0.04))
        ellipse(ctx, cx: 53, cy: 25, w: 3, h: 3, fill: c(1, 1, 1, 0.8))
        ellipse(ctx, cx: 77, cy: 25, w: 3, h: 3, fill: c(1, 1, 1, 0.8))
        // Heavy brow
        ctx.setStrokeColor(c(0.30, 0.18, 0.08)); ctx.setLineWidth(3.5)
        ctx.move(to: CGPoint(x: 44, y: 18)); ctx.addLine(to: CGPoint(x: 60, y: 22)); ctx.strokePath()
        ctx.move(to: CGPoint(x: 84, y: 18)); ctx.addLine(to: CGPoint(x: 68, y: 22)); ctx.strokePath()

        // Flat stern mouth
        ctx.setStrokeColor(c(0.55, 0.28, 0.18)); ctx.setLineWidth(2.5)
        ctx.move(to: CGPoint(x: 52, y: 37)); ctx.addLine(to: CGPoint(x: 76, y: 37))
        ctx.strokePath()
    }

    // MARK: - World Objects

    /// City-style cast-iron lamppost (city=true) or park-style wooden post (city=false).
    private static func drawLampPost(_ ctx: CGContext, city: Bool) {
        ctx.setAllowsAntialiasing(false)
        ctx.setShouldAntialias(false)

        let poleColor    = city ? c(0.18, 0.18, 0.20) : c(0.38, 0.28, 0.14)
        let lanternColor = city ? c(0.22, 0.22, 0.28) : c(0.30, 0.22, 0.10)
        let glassColor   = c(0.98, 0.93, 0.62, 0.90)

        // Pole (centered at x=64)
        let poleX: CGFloat = 58, poleW: CGFloat = 12
        let poleY: CGFloat = 20, poleH: CGFloat = 88

        rect(ctx, x: poleX, y: poleY, w: poleW, h: poleH,
             fill: poleColor, stroke: ink, lw: 2, corner: 4)

        if city {
            // Decorative arm brackets
            ctx.setStrokeColor(poleColor); ctx.setLineWidth(4)
            ctx.move(to: CGPoint(x: 64, y: 95))
            ctx.addLine(to: CGPoint(x: 44, y: 108))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: 64, y: 95))
            ctx.addLine(to: CGPoint(x: 84, y: 108))
            ctx.strokePath()

            // Lantern head (wide hexagonal look)
            rect(ctx, x: 40, y: 106, w: 48, h: 18,
                 fill: lanternColor, stroke: ink, lw: 2, corner: 5)
            // Glass panels
            ellipse(ctx, cx: 56, cy: 115, w: 14, h: 12, fill: glassColor)
            ellipse(ctx, cx: 72, cy: 115, w: 14, h: 12, fill: glassColor)
            // Cap
            rect(ctx, x: 38, y: 122, w: 52, h: 5,
                 fill: poleColor, stroke: ink, lw: 1.5, corner: 2)
        } else {
            // Park lamppost — simple globe lantern
            // Arm
            ctx.setStrokeColor(poleColor); ctx.setLineWidth(5)
            ctx.move(to: CGPoint(x: 64, y: 100))
            ctx.addCurve(to: CGPoint(x: 64, y: 115),
                         control1: CGPoint(x: 64, y: 106),
                         control2: CGPoint(x: 64, y: 110))
            ctx.strokePath()
            // Globe lantern
            ellipse(ctx, cx: 64, cy: 118, w: 22, h: 20,
                    fill: glassColor, stroke: lanternColor, lw: 2.5)
            // Top cap
            ellipse(ctx, cx: 64, cy: 126, w: 14, h: 6, fill: poleColor)
            // Post base
            rect(ctx, x: 54, y: 16, w: 20, h: 8,
                 fill: poleColor, stroke: ink, lw: 2, corner: 3)
        }

        // Base plate (ground level)
        rect(ctx, x: 50, y: 16, w: 28, h: 10,
             fill: c(0.30, 0.28, 0.25), stroke: ink, lw: 2, corner: 3)
    }

    // MARK: - NPCs

    private static func drawNPC(_ kind: NPCKind, _ ctx: CGContext) {
        ctx.setAllowsAntialiasing(false)
        ctx.setShouldAntialias(false)
        switch kind {
        case .rangerGuide: drawRangerGuide(ctx)
        case .hazel:       drawHazelNPC(ctx)
        case .jogger:      drawJogger(ctx)
        case .child:       drawChild(ctx)
        case .birdwatcher: drawBirdwatcher(ctx)
        case .dogwalker:   drawDogWalker(ctx)
        case .gardener:    drawGardener(ctx)
        case .worker:      drawWorker(ctx)
        case .shopkeeper:  drawShopkeeper(ctx)
        }
    }

    private static func drawRangerGuide(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 48)
        humanBody(ctx, cx: 64,
                  skin: c(0.89, 0.72, 0.54),
                  shirt: c(0.34, 0.52, 0.26),
                  pants: c(0.28, 0.24, 0.18),
                  shoes: c(0.16, 0.12, 0.08))

        ellipse(ctx, cx: 64, cy: 17, w: 54, h: 16, fill: c(0.46, 0.36, 0.18), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 64, cy: 11, w: 34, h: 12, fill: c(0.56, 0.44, 0.22), stroke: ink, lw: 2.5)
        rect(ctx, x: 50, y: 52, w: 28, h: 20, fill: c(0.28, 0.42, 0.20), stroke: ink, lw: 2, corner: 2)
        rect(ctx, x: 54, y: 56, w: 8, h: 8, fill: c(0.82, 0.72, 0.34), stroke: ink, lw: 1.5, corner: 1)
        rect(ctx, x: 72, y: 57, w: 8, h: 20, fill: c(0.22, 0.18, 0.12), stroke: ink, lw: 1.5, corner: 1)
        rect(ctx, x: 72, y: 72, w: 8, h: 6, fill: c(0.93, 0.88, 0.56), stroke: ink, lw: 1, corner: 1)
    }

    private static func drawHazelNPC(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 44)

        rect(ctx, x: 48, y: 54, w: 22, h: 30, fill: c(0.86, 0.62, 0.34), stroke: ink, lw: 2, corner: 4)
        rect(ctx, x: 51, y: 58, w: 8, h: 10, fill: c(0.94, 0.78, 0.50), corner: 2)
        rect(ctx, x: 52, y: 82, w: 6, h: 16, fill: c(0.72, 0.46, 0.24), stroke: ink, lw: 1.5, corner: 2)
        rect(ctx, x: 62, y: 82, w: 6, h: 16, fill: c(0.72, 0.46, 0.24), stroke: ink, lw: 1.5, corner: 2)
        rect(ctx, x: 48, y: 98, w: 6, h: 10, fill: c(0.32, 0.22, 0.14), corner: 2)
        rect(ctx, x: 64, y: 98, w: 6, h: 10, fill: c(0.32, 0.22, 0.14), corner: 2)

        ellipse(ctx, cx: 58, cy: 38, w: 30, h: 28, fill: c(0.90, 0.68, 0.38), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 76, cy: 34, w: 22, h: 46, fill: c(0.68, 0.40, 0.18), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 80, cy: 26, w: 12, h: 16, fill: c(0.84, 0.58, 0.26), stroke: ink, lw: 2)
        ellipse(ctx, cx: 54, cy: 18, w: 12, h: 18, fill: c(0.72, 0.46, 0.22), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 66, cy: 18, w: 12, h: 18, fill: c(0.72, 0.46, 0.22), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 54, cy: 19, w: 5, h: 8, fill: c(0.96, 0.82, 0.58))
        ellipse(ctx, cx: 66, cy: 19, w: 5, h: 8, fill: c(0.96, 0.82, 0.58))
        ellipse(ctx, cx: 53, cy: 36, w: 5, h: 7, fill: c(0.10, 0.08, 0.06))
        ellipse(ctx, cx: 63, cy: 36, w: 5, h: 7, fill: c(0.10, 0.08, 0.06))
        ellipse(ctx, cx: 54, cy: 34, w: 2, h: 2, fill: c(1, 1, 1, 0.85))
        ellipse(ctx, cx: 64, cy: 34, w: 2, h: 2, fill: c(1, 1, 1, 0.85))
        rect(ctx, x: 56, y: 45, w: 6, h: 4, fill: c(0.54, 0.28, 0.16), corner: 1)
    }

    // ── Construction Worker ───────────────────────────────────────────────────
    private static func drawWorker(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 46)
        humanBody(ctx, cx: 64,
                  skin:  c(0.88, 0.68, 0.50),
                  shirt: c(0.98, 0.55, 0.05),   // bright orange hi-vis shirt
                  pants: c(0.25, 0.25, 0.28),   // dark work trousers
                  shoes: c(0.18, 0.14, 0.10))   // steel-toe boots

        // Yellow safety vest stripes across torso
        let vestStripe1 = CGRect(x: 46, y: 66, width: 36, height: 6)
        let vestStripe2 = CGRect(x: 46, y: 56, width: 36, height: 6)
        ctx.setFillColor(c(0.95, 0.90, 0.10, 0.80))
        ctx.fill(vestStripe1)
        ctx.fill(vestStripe2)

        // Hard hat (yellow, flat top)
        ellipse(ctx, cx: 64, cy: 16, w: 50, h: 12, fill: c(0.96, 0.82, 0.10), stroke: ink, lw: 2)
        rect(ctx, x: 41, y: 12, w: 46, h: 10, fill: c(0.96, 0.82, 0.10), stroke: ink, lw: 2, corner: 2)
        // Brim — front shadow
        rect(ctx, x: 36, y: 16, w: 56, h: 5, fill: c(0.75, 0.62, 0.06), corner: 2)
    }

    // ── Shopkeeper ────────────────────────────────────────────────────────────
    private static func drawShopkeeper(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 46)
        humanBody(ctx, cx: 64,
                  skin:  c(0.88, 0.70, 0.52),
                  shirt: c(0.95, 0.95, 0.95),   // white shirt
                  pants: c(0.25, 0.20, 0.55),   // dark trousers
                  shoes: c(0.15, 0.10, 0.08))

        // Green shopkeeper apron over torso
        let apron = CGRect(x: 46, y: 52, width: 36, height: 46)
        ctx.setFillColor(c(0.20, 0.50, 0.22, 0.85))
        ctx.addEllipse(in: apron.insetBy(dx: 0, dy: 0))
        ctx.setStrokeColor(c(0.12, 0.35, 0.15))
        ctx.setLineWidth(1.5)
        ctx.strokePath()
        ctx.fillPath()

        // Simple visor cap (flat brim + rounded top)
        ellipse(ctx, cx: 64, cy: 13, w: 44, h: 10, fill: c(0.18, 0.38, 0.18), stroke: ink, lw: 2)
        ellipse(ctx, cx: 64, cy: 11, w: 30, h: 12, fill: c(0.16, 0.34, 0.16), stroke: ink, lw: 2)
        // Cap button on top
        ellipse(ctx, cx: 64, cy:  6, w:  6, h:  6, fill: c(0.12, 0.28, 0.12))
        rect(ctx, x: 48, y: 58, w: 32, h: 22,
             fill: c(0.16, 0.42, 0.18), stroke: ink, lw: 2, corner: 2)
    }

    // ── Jogger ────────────────────────────────────────────────────────────────
    private static func drawJogger(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 46)
        humanBody(ctx, cx: 64,
                  skin:  c(0.90, 0.72, 0.55),
                  shirt: c(0.10, 0.72, 0.88),   // bright athletic cyan
                  pants: c(0.15, 0.15, 0.40),   // dark blue shorts
                  shoes: c(0.90, 0.35, 0.15))   // bright orange shoes

        // Visor band
        ellipse(ctx, cx: 64, cy: 17, w: 42, h: 10, fill: c(0.10,0.72,0.88), stroke: ink, lw: 2)
        // Visor brim (front only)
        rect(ctx, x: 43, y: 16, w: 42, h: 7, fill: c(0.08, 0.55, 0.70), corner: 2)

        // Sweatband on wrists (small bright bands)
        ellipse(ctx, cx: 36, cy: 82, w: 12, h: 6, fill: c(0.95, 0.90, 0.20), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 92, cy: 82, w: 12, h: 6, fill: c(0.95, 0.90, 0.20), stroke: ink, lw: 1.5)
        rect(ctx, x: 50, y: 55, w: 28, h: 8, fill: c(0.95, 0.90, 0.20), stroke: ink, lw: 1.5, corner: 1)

        // Smile
        ctx.setStrokeColor(c(0.55,0.25,0.15)); ctx.setLineWidth(2)
        let sm = CGMutablePath()
        sm.move(to: CGPoint(x: 56, y: 35))
        sm.addQuadCurve(to: CGPoint(x: 72, y: 35), control: CGPoint(x: 64, y: 41))
        ctx.addPath(sm); ctx.strokePath()
    }

    // ── Child ─────────────────────────────────────────────────────────────────
    private static func drawChild(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 42)
        // Smaller proportions — shift everything up so feet still near bottom
        let bob: CGFloat = 12
        humanBody(ctx, cx: 64,
                  skin:  c(0.96, 0.82, 0.64),
                  shirt: c(0.95, 0.40, 0.55),   // pink/red striped shirt
                  pants: c(0.28, 0.42, 0.80),   // bright blue jeans
                  shoes: c(0.90, 0.90, 0.90),   // white sneakers
                  bob: -bob)

        // Shirt stripes
        for i in 0..<3 {
            let yy = CGFloat(56 + i * 7) - bob
            rect(ctx, x: 43, y: yy, w: 42, h: 4, fill: c(1.0, 0.65, 0.70), corner: 0)
        }
        rect(ctx, x: 49, y: 67 - bob, w: 10, h: 10, fill: c(0.98, 0.90, 0.32), stroke: ink, lw: 1.5, corner: 1)

        // Pigtails
        ellipse(ctx, cx: 46, cy: 17-bob, w: 14, h: 16,
                fill: c(0.55, 0.30, 0.10), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 82, cy: 17-bob, w: 14, h: 16,
                fill: c(0.55, 0.30, 0.10), stroke: ink, lw: 2.5)

        // Hair ties (colour dots)
        ellipse(ctx, cx: 46, cy: 23-bob, w: 7, h: 7, fill: c(0.95,0.30,0.50))
        ellipse(ctx, cx: 82, cy: 23-bob, w: 7, h: 7, fill: c(0.95,0.30,0.50))

        // Big excited smile
        ctx.setStrokeColor(c(0.55,0.22,0.14)); ctx.setLineWidth(2)
        let sm = CGMutablePath()
        sm.move(to: CGPoint(x: 54, y: 33-bob))
        sm.addQuadCurve(to: CGPoint(x: 74, y: 33-bob), control: CGPoint(x: 64, y: 42-bob))
        ctx.addPath(sm); ctx.strokePath()

        // Big eyes (child feature)
        ellipse(ctx, cx: 56, cy: 26-bob, w: 8, h: 9, fill: c(0.1,0.1,0.1))
        ellipse(ctx, cx: 72, cy: 26-bob, w: 8, h: 9, fill: c(0.1,0.1,0.1))
        ellipse(ctx, cx: 57, cy: 24-bob, w: 3, h: 3, fill: c(1,1,1,0.9))
        ellipse(ctx, cx: 73, cy: 24-bob, w: 3, h: 3, fill: c(1,1,1,0.9))
    }

    // ── Birdwatcher ───────────────────────────────────────────────────────────
    private static func drawBirdwatcher(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 50)
        humanBody(ctx, cx: 64,
                  skin:  c(0.88, 0.72, 0.58),
                  shirt: c(0.62, 0.54, 0.36),   // khaki vest/shirt
                  pants: c(0.58, 0.52, 0.34),   // khaki pants
                  shoes: c(0.38, 0.28, 0.14))   // brown shoes

        // Wide-brim field hat
        ellipse(ctx, cx: 64, cy: 17, w: 60, h: 16, fill: c(0.72, 0.62, 0.38), stroke: ink, lw: 2.5)
        ellipse(ctx, cx: 64, cy: 12, w: 36, h: 14, fill: c(0.68, 0.58, 0.34), stroke: ink, lw: 2.5)
        // Hat band
        ellipse(ctx, cx: 64, cy: 17, w: 34, h: 6, fill: c(0.30, 0.22, 0.10))

        // Grey hair (sides visible under hat)
        ellipse(ctx, cx: 64, cy: 30, w: 40, h: 16, fill: c(0.80, 0.80, 0.80))

        // Binoculars hanging on chest
        ellipse(ctx, cx: 57, cy: 57, w: 12, h: 10, fill: c(0.15,0.15,0.15), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 71, cy: 57, w: 12, h: 10, fill: c(0.15,0.15,0.15), stroke: ink, lw: 1.5)
        rect(ctx, x: 50, y: 70, w: 28, h: 14, fill: c(0.58, 0.52, 0.34), stroke: ink, lw: 1.5, corner: 2)
        // Strap
        ctx.setStrokeColor(c(0.30,0.22,0.10)); ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 57, y: 50)); ctx.addLine(to: CGPoint(x: 52, y: 44))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: 71, y: 50)); ctx.addLine(to: CGPoint(x: 76, y: 44))
        ctx.strokePath()

        // Soft smile + wrinkle lines
        ctx.setStrokeColor(c(0.55,0.30,0.18)); ctx.setLineWidth(1.5)
        let sm = CGMutablePath()
        sm.move(to: CGPoint(x: 57, y: 36))
        sm.addQuadCurve(to: CGPoint(x: 71, y: 36), control: CGPoint(x: 64, y: 40))
        ctx.addPath(sm); ctx.strokePath()
    }

    // ── Dog Walker ────────────────────────────────────────────────────────────
    private static func drawDogWalker(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 48)
        humanBody(ctx, cx: 64,
                  skin:  c(0.75, 0.55, 0.40),
                  shirt: c(0.22, 0.65, 0.78),   // teal jacket
                  pants: c(0.22, 0.25, 0.65),   // dark blue jeans
                  shoes: c(0.20, 0.20, 0.22))   // dark grey shoes

        // Curly hair (cluster of circles)
        for (hx, hy) in [(64.0,9.0),(52.0,12.0),(76.0,12.0),(58.0,6.0),(70.0,6.0)] {
            ellipse(ctx, cx: hx, cy: hy, w: 14, h: 14,
                    fill: c(0.25, 0.15, 0.05), stroke: ink, lw: 1.5)
        }

        // Leash in right hand (line + small dog shape)
        ctx.setStrokeColor(c(0.55, 0.38, 0.18)); ctx.setLineWidth(2.5)
        ctx.move(to: CGPoint(x: 92, y: 83))
        ctx.addCurve(to: CGPoint(x: 112, y: 105),
                     control1: CGPoint(x: 108, y: 88),
                     control2: CGPoint(x: 118, y: 96))
        ctx.strokePath()

        // Tiny dog at end of leash
        ellipse(ctx, cx: 112, cy: 108, w: 18, h: 12, fill: c(0.75, 0.60, 0.38), stroke: ink, lw: 1.5)
        ellipse(ctx, cx: 106, cy: 103, w: 10, h: 9,  fill: c(0.75, 0.60, 0.38), stroke: ink, lw: 1.5)
        rect(ctx, x: 50, y: 53, w: 26, h: 16, fill: c(0.16, 0.50, 0.62), stroke: ink, lw: 1.5, corner: 2)

        // Friendly grin
        ctx.setStrokeColor(c(0.50,0.22,0.12)); ctx.setLineWidth(2)
        let sm = CGMutablePath()
        sm.move(to: CGPoint(x: 56, y: 35))
        sm.addQuadCurve(to: CGPoint(x: 72, y: 35), control: CGPoint(x: 64, y: 42))
        ctx.addPath(sm); ctx.strokePath()
    }

    // ── Gardener ──────────────────────────────────────────────────────────────
    private static func drawGardener(_ ctx: CGContext) {
        shadow(ctx, cx: 64, w: 52)
        humanBody(ctx, cx: 64,
                  skin:  c(0.82, 0.62, 0.42),
                  shirt: c(0.30, 0.55, 0.28),   // green overalls
                  pants: c(0.28, 0.50, 0.26),
                  shoes: c(0.38, 0.24, 0.10))   // muddy brown boots

        // Apron over overalls (lighter green)
        ellipse(ctx, cx: 64, cy: 67, w: 36, h: 32, fill: c(0.55, 0.72, 0.42), stroke: ink, lw: 2)

        // Apron straps
        ctx.setStrokeColor(c(0.55,0.72,0.42)); ctx.setLineWidth(5)
        ctx.move(to: CGPoint(x: 58, y: 51)); ctx.addLine(to: CGPoint(x: 54, y: 43))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: 70, y: 51)); ctx.addLine(to: CGPoint(x: 74, y: 43))
        ctx.strokePath()

        // Straw hat — wider and lighter than ranger
        ellipse(ctx, cx: 64, cy: 17, w: 66, h: 16, fill: c(0.88, 0.78, 0.44), stroke: ink, lw: 2)
        ellipse(ctx, cx: 64, cy: 11, w: 38, h: 14, fill: c(0.85, 0.75, 0.40), stroke: ink, lw: 2)
        // Woven texture hint
        ctx.setStrokeColor(c(0.70,0.58,0.28)); ctx.setLineWidth(1)
        for i in stride(from: 30.0, through: 98.0, by: 10) {
            ctx.move(to: CGPoint(x: i, y: 13)); ctx.addLine(to: CGPoint(x: i+5, y: 21))
            ctx.strokePath()
        }

        // Dirt smudges on hands
        ellipse(ctx, cx: 36, cy: 83, w: 13, h: 13, fill: c(0.55, 0.38, 0.18), stroke: ink, lw: 2)
        ellipse(ctx, cx: 92, cy: 83, w: 13, h: 13, fill: c(0.55, 0.38, 0.18), stroke: ink, lw: 2)
        rect(ctx, x: 47, y: 59, w: 34, h: 16, fill: c(0.48, 0.66, 0.34), stroke: ink, lw: 1.5, corner: 2)

        // Grumpy/focused expression
        ctx.setStrokeColor(c(0.45,0.20,0.10)); ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 58, y: 36)); ctx.addLine(to: CGPoint(x: 70, y: 36))
        ctx.strokePath()
        // Furrowed brow
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 54, y: 23)); ctx.addLine(to: CGPoint(x: 60, y: 25))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: 74, y: 23)); ctx.addLine(to: CGPoint(x: 68, y: 25))
        ctx.strokePath()
    }
}
