import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Pixelate pass: quantizes every sprite to the game's single virtual-pixel
// ruler (1 virtual px = 3pt on screen = 16 virtual px per 48pt tile) so the
// whole world reads at ONE pixel density, like a real SNES game.
//
// Each k×k block becomes one colour by rarity-weighted vote (rare colours —
// eyes, outlines, catchlights — beat large fills on ties), transparency wins
// when a block is mostly clear. Canvas sizes are unchanged, so display code
// and filenames stay valid, and re-running is idempotent (blocks align).
//
// Usage: swift pixelate.swift <dir-of-pngs>

struct RGBA: Hashable { let r: UInt8, g: UInt8, b: UInt8, a: UInt8 }

/// Virtual-pixel factor per asset class; nil = leave untouched.
func factor(for name: String) -> Double? {
    // Battle portraits keep their painterly register (bible: enemies are a
    // deliberately different style) — and previews aren't game assets.
    if name.contains("-battle-") || name.contains("preview") { return nil }
    if name.hasPrefix("npc-") { return 6 }           // 128x192 shown 64x96pt → 3pt vpx
    for p in ["shelly-", "hazel-", "spike-", "pip-"] where name.hasPrefix(p) {
        return 5                                      // 64x96 shown ~0.6x → ~3pt vpx
    }
    if name.hasPrefix("sheet-") { return 3 }          // 48px cells shown 48pt → 3pt vpx
    if name.hasPrefix("bldg-") { return 3 }           // canvases shown 1:1 → 3pt vpx
    if name.hasPrefix("tree-") { return 2 }           // shown ~2x canvas → ~3.4-4.5pt vpx
    if name.hasPrefix("prop-statue-") { return 2 }    // shown 1.5x canvas → 3pt vpx
    if name.hasPrefix("critter-duck-") { return 2 }   // 36px shown 48pt → 2.7pt vpx
    for p in ["critter-", "tile-", "prop-", "furn-", "house-", "enemy-"]
        where name.hasPrefix(p) {
        return 3                                      // shown ~1:1 → 3pt vpx
    }
    return nil
}

func pixelate(path: String, k: Double) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return false }
    let w = img.width, h = img.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return false }
    ctx.interpolationQuality = .none
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let buf = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return false }

    func px(_ x: Int, _ y: Int) -> RGBA {
        let i = (y * w + x) * 4
        return RGBA(r: buf[i], g: buf[i + 1], b: buf[i + 2], a: buf[i + 3])
    }

    // Global frequency for rarity weighting.
    var freq: [RGBA: Int] = [:]
    for y in 0..<h { for x in 0..<w {
        let c = px(x, y)
        if c.a > 16 { freq[c, default: 0] += 1 }
    } }

    let bw = Int((Double(w) / k).rounded(.up)), bh = Int((Double(h) / k).rounded(.up))
    for by in 0..<bh {
        let y0 = Int(Double(by) * k), y1 = min(h, max(y0 + 1, Int((Double(by + 1) * k).rounded())))
        for bx in 0..<bw {
            let x0 = Int(Double(bx) * k), x1 = min(w, max(x0 + 1, Int((Double(bx + 1) * k).rounded())))
            var counts: [RGBA: Int] = [:]
            var total = 0, opaque = 0
            for y in y0..<y1 { for x in x0..<x1 {
                total += 1
                let c = px(x, y)
                if c.a > 16 { opaque += 1; counts[c, default: 0] += 1 }
            } }
            var fill = RGBA(r: 0, g: 0, b: 0, a: 0)
            if total > 0, opaque * 2 >= total {
                var bestScore = -1.0
                for (c, n) in counts {
                    let score = Double(n) / Double(freq[c] ?? 1).squareRoot()
                    if score > bestScore { bestScore = score; fill = c }
                }
            }
            for y in y0..<y1 { for x in x0..<x1 {
                let i = (y * w + x) * 4
                buf[i] = fill.r; buf[i + 1] = fill.g; buf[i + 2] = fill.b; buf[i + 3] = fill.a
            } }
        }
    }

    guard let out = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(dest, out, nil)
    return CGImageDestinationFinalize(dest)
}

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
var done = 0, skipped = 0, failed = 0
for f in files.sorted() where f.hasSuffix(".png") {
    guard let k = factor(for: f) else { skipped += 1; continue }
    if pixelate(path: dir + "/" + f, k: k) { done += 1 } else { failed += 1; print("FAILED \(f)") }
}
print("pixelated \(done), skipped \(skipped), failed \(failed)")
