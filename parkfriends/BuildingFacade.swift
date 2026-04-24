import SpriteKit
import CoreGraphics

/// Part 3 — flat SNES-style façade rendered into a single CGContext texture.
/// Same pipeline as WorldSprites / CharacterSprites: flat colour + ink outlines.
@MainActor
enum BuildingFacade {

    // MARK: - Palette

    enum PaletteKind: String {
        case brick, concrete, wood

        struct Colors {
            let wallMain:   CGColor
            let wallAlt:    CGColor
            let wallShadow: CGColor
            let roof:       CGColor
            let roofDark:   CGColor
            let foundation: CGColor
            let door:       CGColor
            let doorInset:  CGColor
        }

        var colors: Colors {
            switch self {
            case .brick:
                return Colors(
                    wallMain:   hex("C47A52"), wallAlt:    hex("B86840"),
                    wallShadow: hex("7A4028"), roof:       hex("6E4C2A"),
                    roofDark:   hex("4A2E14"), foundation: hex("5A4228"),
                    door:       hex("5A3E1E"), doorInset:  hex("3C2810"))
            case .concrete:
                return Colors(
                    wallMain:   hex("9E9E9E"), wallAlt:    hex("8C8C8C"),
                    wallShadow: hex("5A5A5A"), roof:       hex("6A6A6A"),
                    roofDark:   hex("484848"), foundation: hex("484848"),
                    door:       hex("3A3A3A"), doorInset:  hex("282828"))
            case .wood:
                return Colors(
                    wallMain:   hex("C4955A"), wallAlt:    hex("B07840"),
                    wallShadow: hex("7A5C2E"), roof:       hex("5A3E1E"),
                    roofDark:   hex("402C14"), foundation: hex("5A4228"),
                    door:       hex("3C2810"), doorInset:  hex("281C08"))
            }
        }
    }

    // MARK: - Cache + entry point

    private static var cache: [String: SKTexture] = [:]

    /// Returns an `SKSpriteNode` with `anchorPoint = .zero` (bottom-left).
    static func makeNode(widthTiles: Int, heightTiles: Int,
                         tile: CGFloat, palette: PaletteKind, seed: UInt64) -> SKSpriteNode {
        let key = "\(widthTiles)_\(heightTiles)_\(palette.rawValue)_\(seed)"
        let tex: SKTexture
        if let cached = cache[key] {
            tex = cached
        } else {
            let t = render(widthTiles: widthTiles, heightTiles: heightTiles,
                           tile: tile, palette: palette, seed: seed)
            t.filteringMode = .nearest
            cache[key] = t
            tex = t
        }
        let node = SKSpriteNode(texture: tex)
        node.size = CGSize(width: CGFloat(widthTiles) * tile,
                           height: CGFloat(heightTiles) * tile)
        node.anchorPoint = .zero
        return node
    }

    // MARK: - Renderer

    private static let ink = CGColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 1)
    private static let gold = CGColor(red: 0.80, green: 0.65, blue: 0.22, alpha: 1)
    private static let litGlass  = CGColor(red: 0.94, green: 0.91, blue: 0.54, alpha: 1)
    private static let darkGlass = CGColor(red: 0.16, green: 0.23, blue: 0.29, alpha: 1)

    private static func render(widthTiles: Int, heightTiles: Int,
                                tile: CGFloat, palette: PaletteKind, seed: UInt64) -> SKTexture {
        // Render at 2× for crispness; caller sets node.size to game units.
        let scale = 2
        let pw = widthTiles  * Int(tile) * scale
        let ph = heightTiles * Int(tile) * scale
        let w  = CGFloat(pw);  let h = CGFloat(ph)
        let ts = tile * CGFloat(scale)   // one tile in render-pixels
        let pal = palette.colors

        guard let ctx = CGContext(
            data: nil, width: pw, height: ph, bitsPerComponent: 8,
            bytesPerRow: pw * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                        CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return SKTexture() }

        ctx.setAllowsAntialiasing(false)

        // ── Layout (y=0 at BOTTOM — standard CGContext Cartesian) ─────────────
        let foundH  = ts * 0.55
        let roofH   = ts * 2.00
        let wallY   = foundH
        let wallH   = h - roofH - foundH
        let roofY   = h - roofH
        let overhang = ts * 0.28

        var rng = seed

        // ── 1. Foundation ─────────────────────────────────────────────────────
        fill(ctx, pal.foundation, 0, 0, w, foundH)

        // Foundation separator
        fill(ctx, pal.wallShadow, 0, foundH - 3, w, 4)

        // ── 2. Wall ───────────────────────────────────────────────────────────
        fill(ctx, pal.wallMain, 0, wallY, w, wallH)

        // Horizontal mortar / siding lines every half-tile
        var lineY = wallY + ts * 0.5
        while lineY < roofY - 2 {
            fill(ctx, pal.wallAlt, 0, lineY, w, 2)
            lineY += ts * 0.5
        }

        // Right-side depth shadow
        fill(ctx, withAlpha(pal.wallShadow, 0.45), w - ts * 0.18, wallY, ts * 0.18, wallH)

        // ── 3. Roof ───────────────────────────────────────────────────────────
        fill(ctx, pal.roof, -overhang, roofY, w + overhang * 2, roofH)

        // Upper darker band (top tile row of roof)
        fill(ctx, pal.roofDark, -overhang, roofY + ts, w + overhang * 2, ts)

        // Roofline separator
        fill(ctx, pal.wallShadow, -overhang, roofY - 4, w + overhang * 2, 5)

        // Overhang undersides
        fill(ctx, rgba(0, 0, 0, 0.35), -overhang, roofY, overhang, ts * 0.28)
        fill(ctx, rgba(0, 0, 0, 0.35), w, roofY, overhang, ts * 0.28)

        // ── 4. Windows ────────────────────────────────────────────────────────
        let numCols = max(2, widthTiles / 3)
        let winW    = ts * 0.72
        let winH    = ts * 0.60
        let colStep = w / CGFloat(numCols + 1)
        let row1Y   = wallY + wallH * 0.67
        let row2Y   = wallY + wallH * 0.30

        for (rowIdx, rowY) in [row1Y, row2Y].enumerated() {
            for col in 1...numCols {
                if rowIdx == 1 && col == numCols { continue }   // asymmetric gap

                rng = rng &* 6364136223846793005 &+ 1442695040888963407
                let glassType = rng % 4
                let cx = CGFloat(col) * colStep - winW / 2

                // Outer dark frame
                fill(ctx, ink, cx - 4, rowY - 4, winW + 8, winH + 8)

                // Glass
                let glass = glassColor(glassType)
                fill(ctx, glass, cx, rowY, winW, winH)

                // Lit: bright inner highlight
                if glassType == 0 {
                    fill(ctx, rgba(1, 0.98, 0.7, 0.38), cx + 5, rowY + 5, winW - 10, winH - 10)
                }

                // Dividing cross for multi-pane look
                fill(ctx, ink, cx + winW / 2 - 1, rowY, 2, winH)
                fill(ctx, ink, cx, rowY + winH / 2 - 1, winW, 2)

                // Sill ledge below window
                fill(ctx, pal.wallShadow, cx - 6, rowY - 8, winW + 12, 5)
            }
        }

        // ── 5. Door ───────────────────────────────────────────────────────────
        let doorW = ts * 1.1
        let doorH = foundH + wallH * 0.30
        let doorX = w * 0.52 - doorW / 2

        // Door frame (wider, flush with ground)
        fill(ctx, ink, doorX - 5, 0, doorW + 10, doorH + 5)

        // Door body
        fill(ctx, pal.door, doorX, 0, doorW, doorH)

        // Panel inset
        fill(ctx, pal.doorInset,
             doorX + doorW * 0.14, doorH * 0.46,
             doorW * 0.72, doorH * 0.42)

        // Panel top highlight
        fill(ctx, withAlpha(pal.door, 0.65),
             doorX + doorW * 0.14, doorH * 0.86,
             doorW * 0.72, 3)

        // Door knob
        let kx = doorX + doorW * 0.80, ky = doorH * 0.34
        fillOval(ctx, gold, kx - 5, ky - 5, 10, 10)

        // Step / stoop
        fill(ctx, pal.foundation,
             doorX - ts * 0.22, 0,
             doorW + ts * 0.44, 6)

        // ── 6. AC unit ────────────────────────────────────────────────────────
        let acW = ts * 0.65, acH = ts * 0.44
        let acX = w * 0.72 - acW / 2
        let acY = wallY + wallH * 0.22

        fill(ctx, ink, acX - 3, acY - 5, acW + 6, acH + 5)
        fill(ctx, hex("282828"), acX, acY, acW, acH)
        fill(ctx, hex("3C3C3C"), acX + 3, acY + acH * 0.70, acW - 6, acH * 0.24)
        for vi in 0..<4 {
            let vx = acX + 5 + CGFloat(vi) * ((acW - 10) / 3)
            fill(ctx, hex("222222"), vx, acY + acH * 0.70, 2, acH * 0.24)
        }
        // Drip
        fill(ctx, rgba(0.5, 0.65, 0.8, 0.55), acX + acW * 0.42, acY - 8, 3, 8)

        // ── 7. Mailbox ────────────────────────────────────────────────────────
        rng = rng &* 2862933555777941757 &+ 3037000493
        let mbOnRight = (rng % 2 == 0)
        let mbColor: CGColor = (rng % 3 == 0) ? hex("7A5228") : hex("3A5FA0")
        let mbW = ts * 0.22, mbH = ts * 0.34
        let mbX = mbOnRight ? (doorX + doorW + ts * 0.10) : (doorX - mbW - ts * 0.10)

        fill(ctx, ink, mbX - 2, 2, mbW + 4, mbH + 2)
        fill(ctx, mbColor, mbX, 4, mbW, mbH)
        fill(ctx, ink, mbX + 3, 4 + mbH * 0.70, mbW - 6, 3)

        // ── 8. Graffiti (lower 2 tile rows only) ─────────────────────────────
        let grafCols: [CGColor] = [hex("E84040"), hex("E8C040"), hex("40A0E8")]
        let grafCap = wallY + ts * 2
        for g in 0..<3 {
            rng = rng &* 1103515245 &+ 12345
            let gx = CGFloat(rng % UInt64(max(1, UInt64(w * 0.65)))) + w * 0.08
            let gy = wallY + CGFloat(3 + g * 12)
            guard gy < grafCap else { continue }
            let gw = CGFloat(8 + Int(rng % 16))
            let gh = CGFloat(4 + Int(rng % 8))
            fill(ctx, grafCols[Int(rng % 3)], gx, gy, gw, gh)
        }

        // ── 9. Cracks ─────────────────────────────────────────────────────────
        ctx.setStrokeColor(withAlpha(pal.wallShadow, 0.65))
        ctx.setLineWidth(2.5)
        for (k, cx2) in [w * 0.09, w * 0.88].enumerated() {
            let cy2 = wallY + CGFloat(k + 1) * ts * 0.45
            ctx.beginPath()
            ctx.move(to:    CGPoint(x: cx2 - 6,  y: cy2 - 12))
            ctx.addLine(to: CGPoint(x: cx2 + 3,  y: cy2))
            ctx.addLine(to: CGPoint(x: cx2 + 9,  y: cy2 + 14))
            ctx.strokePath()
        }

        // ── 10. Border ────────────────────────────────────────────────────────
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(6)
        ctx.stroke(CGRect(x: 3, y: 3, width: w - 6, height: h - 6))

        guard let img = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: img)
    }

    // MARK: - Draw helpers

    private static func fill(_ ctx: CGContext,
                              _ color: CGColor,
                              _ x: CGFloat, _ y: CGFloat,
                              _ w: CGFloat, _ h: CGFloat) {
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: x, y: y, width: max(0, w), height: max(0, h)))
    }

    private static func fillOval(_ ctx: CGContext,
                                  _ color: CGColor,
                                  _ x: CGFloat, _ y: CGFloat,
                                  _ w: CGFloat, _ h: CGFloat) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
    }

    private static func rgba(_ r: CGFloat, _ g: CGFloat,
                              _ b: CGFloat, _ a: CGFloat) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func withAlpha(_ c: CGColor, _ a: CGFloat) -> CGColor {
        c.copy(alpha: a) ?? c
    }

    private static func glassColor(_ type: UInt64) -> CGColor {
        switch type % 4 {
        case 0:  return litGlass
        case 1:  return darkGlass
        case 2:  return CGColor(red: 0.55, green: 0.65, blue: 0.40, alpha: 1)
        default: return CGColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1)
        }
    }

    private static func hex(_ h: String) -> CGColor {
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        return CGColor(red:   CGFloat((n >> 16) & 0xFF) / 255,
                       green: CGFloat((n >>  8) & 0xFF) / 255,
                       blue:  CGFloat( n        & 0xFF) / 255,
                       alpha: 1)
    }
}
