// Park Friends sprite generator — renders palette-index pixel grids to PNGs.
// Design bible rules: no pure-black outlines (outline = darkest shade of the
// main color), highlight upper-left, shadow lower-right, max 3 shades per
// color, asymmetry everywhere.
//
// Usage: swift tools/spritegen/generate.swift <output-dir> [preview-path]
// Writes 16x24 overworld walk frames + an 8x preview strip for review.

import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// MARK: - Palette (design bible Part 11 + character sheets)

let palette: [Character: (UInt8, UInt8, UInt8, UInt8)] = [
    ".": (0, 0, 0, 0),            // transparent
    "G": (0x5D, 0xA8, 0x32, 255), // green main
    "g": (0x3D, 0x72, 0x20, 255), // green dark (outline/shadow)
    "H": (0x72, 0xC4, 0x40, 255), // green highlight
    "T": (0xC4, 0x95, 0x5A, 255), // shell tan
    "t": (0xA0, 0x78, 0x40, 255), // shell cell dark
    "r": (0x7A, 0x5C, 0x2E, 255), // shell rim (darkest brown)
    "h": (0xD4, 0xA8, 0x70, 255), // shell highlight
    "E": (0x1E, 0x1E, 0x22, 255), // near-black (eyes; never pure black)
    "W": (0xF5, 0xF0, 0xDC, 255), // eye catchlight
    "S": (0x2A, 0x50, 0x18, 102), // drop shadow, 40% opacity
    // Spike (hedgehog)
    "B": (0xC4, 0x85, 0x3A, 255), // warm brown main
    "b": (0x8B, 0x5C, 0x28, 255), // brown dark (outline)
    "N": (0xE0, 0xB8, 0x96, 255), // snout
    "Y": (0xE0, 0xC8, 0xA0, 255), // belly
    "D": (0x48, 0x48, 0x48, 255), // spine dark gray
    "L": (0xD0, 0xD0, 0xD0, 255), // spine tip light
    // Hazel (squirrel)
    "M": (0x8B, 0x5C, 0x28, 255), // mid brown main
    "m": (0x5A, 0x3A, 0x18, 255), // dark brown (outline)
    "C": (0xC4, 0xA0, 0x6A, 255), // tail tip / belly stripe
    "P": (0xE8, 0xA0, 0x80, 255), // inner ear pink
    "I": (0xC8, 0x88, 0x0A, 255), // amber eye
    // Pip (hamster)
    "K": (0xE0, 0xC0, 0xA0, 255), // cream
    "k": (0xC4, 0xA0, 0x7A, 255), // warm cream shadow
    "O": (0xE8, 0x60, 0x60, 255), // bright pink nose
    "Q": (0xD4, 0xB0, 0x30, 255), // gold (chaos star)
]

// MARK: - Procedural drawing helpers (for 32x48+ sprites)

func fillEllipse(_ g: inout Grid, cx: Double, cy: Double, rx: Double, ry: Double, _ ch: Character) {
    for y in 0..<g.count {
        for x in 0..<g[0].count {
            let dx = (Double(x) + 0.5 - cx) / rx
            let dy = (Double(y) + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0 { g[y][x] = ch }
        }
    }
}

/// Form-shaded ellipse: highlight arc toward the upper-left edge, core color
/// in the middle, shadow band hugging the lower-right rim. This is what makes
/// a blob read as a 3D form instead of a flat sticker.
func shadeEllipse(_ g: inout Grid, cx: Double, cy: Double, rx: Double, ry: Double,
                  main: Character, hi: Character, lo: Character,
                  hiThresh: Double = 0.34, loThresh: Double = -0.40) {
    for y in 0..<g.count {
        for x in 0..<g[0].count {
            let nx = (Double(x) + 0.5 - cx) / rx
            let ny = (Double(y) + 0.5 - cy) / ry
            let d = nx * nx + ny * ny
            guard d <= 1.0 else { continue }
            // light from upper-left, weighted toward the rim
            let score = (-nx * 0.6 - ny * 0.8) * d.squareRoot()
            g[y][x] = score > hiThresh ? hi : (score < loThresh ? lo : main)
        }
    }
}

/// Replaces body pixels that touch transparency with the outline color.
func outlineShape(_ g: inout Grid, body: Set<Character>, outline: Character) {
    let h = g.count, w = g[0].count
    var edges: [(Int, Int)] = []
    for y in 0..<h {
        for x in 0..<w where body.contains(g[y][x]) {
            let n = [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]
            if n.contains(where: { $0.0 < 0 || $0.0 >= w || $0.1 < 0 || $0.1 >= h || g[$0.1][$0.0] == "." }) {
                edges.append((x, y))
            }
        }
    }
    for (x, y) in edges { g[y][x] = outline }
}

/// Composites `src` over `dst` (non-"." pixels win), offset by (dx, dy).
func composite(_ dst: inout Grid, _ src: Grid, dx: Int, dy: Int) {
    for y in 0..<src.count {
        for x in 0..<src[0].count where src[y][x] != "." {
            let px = x + dx, py = y + dy
            if py >= 0, py < dst.count, px >= 0, px < dst[0].count { dst[py][px] = src[y][x] }
        }
    }
}

/// Tapered spike: stepped circles from a base point outward along `angle`
/// (radians), shrinking radius; last quarter drawn in `tip` color.
func drawSpike(_ g: inout Grid, baseX: Double, baseY: Double, angle: Double,
               len: Double, baseR: Double, body: Character, tip: Character) {
    let steps = max(3, Int(len))
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        let x = baseX + cos(angle) * len * t
        let y = baseY + sin(angle) * len * t
        let r = baseR * (1.0 - t * 0.8)
        fillEllipse(&g, cx: x, cy: y, rx: max(0.6, r), ry: max(0.6, r),
                    t > 0.72 ? tip : body)
    }
}

// MARK: - Grid helpers

typealias Grid = [[Character]]

func emptyGrid(w: Int, h: Int) -> Grid {
    Array(repeating: Array(repeating: Character("."), count: w), count: h)
}

/// Stamps `rows` onto `grid` at (x, y); "." pixels are skipped.
func stamp(_ grid: inout Grid, _ rows: [String], x: Int, y: Int) {
    for (dy, row) in rows.enumerated() {
        for (dx, ch) in row.enumerated() where ch != "." {
            let px = x + dx, py = y + dy
            if py >= 0, py < grid.count, px >= 0, px < grid[0].count {
                grid[py][px] = ch
            }
        }
    }
}

func render(_ grid: Grid, scale: Int = 1) -> CGImage {
    let h = grid.count, w = grid[0].count
    var data = [UInt8](repeating: 0, count: w * h * 4)
    for y in 0..<h {
        for x in 0..<w {
            let (r, g, b, a) = palette[grid[y][x]] ?? (255, 0, 255, 255)
            let i = (y * w + x) * 4
            // premultiplied alpha
            data[i]     = UInt8(Int(r) * Int(a) / 255)
            data[i + 1] = UInt8(Int(g) * Int(a) / 255)
            data[i + 2] = UInt8(Int(b) * Int(a) / 255)
            data[i + 3] = a
        }
    }
    let provider = CGDataProvider(data: Data(data) as CFData)!
    let img = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                      provider: provider, decode: nil, shouldInterpolate: false,
                      intent: .defaultIntent)!
    guard scale > 1 else { return img }
    let ctx = CGContext(data: nil, width: w * scale, height: h * scale,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .none
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w * scale, height: h * scale))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                               UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: - SHELLY (turtle, tank) — bible §4.2 at 64x96
// High-detail pixel art: head ~46% of height, shell wider than head,
// skeptical eyes (right one lower), staggered scute plates, toes,
// highlight upper-left, no black outlines.

let SW = 64, SH = 96   // shelly canvas

struct FrameSpec {
    let headDY: Int
    let shellDX: Int
    let legMode: Int   // 0 neutral, 1 left forward, 2 right forward
}

// Bible walk cycle: F1 left fwd / F2 bob + tilt left / F3 right fwd /
// F4 bob + tilt right. 120ms per frame.
let shellyFrames: [FrameSpec] = [
    FrameSpec(headDY: 0, shellDX: 0,  legMode: 1),
    FrameSpec(headDY: 2, shellDX: -2, legMode: 0),
    FrameSpec(headDY: 0, shellDX: 0,  legMode: 2),
    FrameSpec(headDY: 2, shellDX: 2,  legMode: 0),
]

func shellyHeadPart(eyesClosed: Bool = false) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    shadeEllipse(&g, cx: 32, cy: 22, rx: 20, ry: 20, main: "G", hi: "H", lo: "g")
    // cheeks slightly wider than the dome
    shadeEllipse(&g, cx: 32, cy: 28, rx: 21.6, ry: 14, main: "G", hi: "G", lo: "g")
    outlineShape(&g, body: ["G", "H"], outline: "g")
    // eyes 4x6, skeptical: right eye 2px lower; 2x2 catchlight upper-right
    for (ex, ey) in [(22, 18), (38, 20)] {
        if eyesClosed {
            for dx in 0..<4 { g[ey + 4][ex + dx] = "g" }
        } else {
            for dy in 0..<6 { for dx in 0..<4 { g[ey + dy][ex + dx] = "E" } }
            g[ey][ex + 2] = "W"; g[ey][ex + 3] = "W"
            g[ey + 1][ex + 2] = "W"; g[ey + 1][ex + 3] = "W"
        }
    }
    // flat skeptical brow over the left eye only (asymmetry)
    for x in 20...27 { g[14][x] = "g"; g[15][x] = "g" }
    // nostrils, slightly uneven
    for (nx, ny) in [(30, 32), (36, 34)] { g[ny][nx] = "g"; g[ny][nx + 1] = "g" }
    return g
}

/// Back of the head (walk-north): plain dome, no face, neck crease.
func shellyHeadBackPart() -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    shadeEllipse(&g, cx: 32, cy: 22, rx: 20, ry: 20, main: "G", hi: "H", lo: "g")
    shadeEllipse(&g, cx: 32, cy: 28, rx: 21.6, ry: 14, main: "G", hi: "G", lo: "g")
    outlineShape(&g, body: ["G", "H"], outline: "g")
    for x in 24...40 where g[38][x] == "G" { g[38][x] = "g" }   // neck crease
    return g
}

/// Profile head (walk-east): snout, single eye, brow.
func shellyHeadEastPart() -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    shadeEllipse(&g, cx: 36, cy: 22, rx: 17, ry: 18, main: "G", hi: "H", lo: "g")
    shadeEllipse(&g, cx: 50, cy: 30, rx: 8, ry: 6.5, main: "G", hi: "G", lo: "g")     // snout
    outlineShape(&g, body: ["G", "H"], outline: "g")
    for dy in 0..<6 { for dx in 0..<4 { g[17 + dy][40 + dx] = "E" } }
    g[17][42] = "W"; g[17][43] = "W"; g[18][42] = "W"; g[18][43] = "W"
    for x in 38...45 { g[13][x] = "g"; g[14][x] = "g" }        // brow
    g[29][55] = "g"; g[30][55] = "g"                            // nostril
    for x in 48...54 where g[35][x] == "G" { g[35][x] = "g" }  // mouth line
    return g
}

/// Profile shell with tail nub (walk-east).
func shellyShellEastPart() -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    fillEllipse(&g, cx: 8, cy: 62, rx: 5, ry: 3.5, "G")        // tail nub
    outlineShape(&g, body: ["G"], outline: "g")
    shadeEllipse(&g, cx: 28, cy: 58, rx: 26, ry: 19, main: "T", hi: "h", lo: "t")
    func seamH(row: Int, bend: Int) {
        for x in 0..<SW {
            let y = row + (abs(x - 28) > 17 ? bend : 0)
            if g[y][x] == "T" { g[y][x] = "t" }
        }
    }
    seamH(row: 48, bend: 2)
    seamH(row: 62, bend: -1)
    seamH(row: 72, bend: -2)
    for x in [17, 28, 39] { for y in 49...61 where g[y][x] == "T" { g[y][x] = "t" } }
    for x in [23, 34] { for y in 63...71 where g[y][x] == "T" { g[y][x] = "t" } }
    outlineShape(&g, body: ["T", "t", "h"], outline: "r")
    outlineShape(&g, body: ["T", "t", "h"], outline: "r")
    return g
}

/// Profile legs: stride via horizontal offset instead of length.
func shellyLegsEastPart(mode: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    let stride: Double = mode == 1 ? 5 : (mode == 2 ? -5 : 0)
    fillEllipse(&g, cx: 40 + stride, cy: 80, rx: 6.4, ry: 7.5, "G")   // front leg
    fillEllipse(&g, cx: 16 - stride, cy: 80, rx: 6.4, ry: 7.5, "G")   // back leg
    outlineShape(&g, body: ["G"], outline: "g")
    return g
}

func shellyShellPart() -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    shadeEllipse(&g, cx: 32, cy: 58, rx: 28, ry: 19, main: "T", hi: "h", lo: "t")

    // Scute seams: two curved horizontal seams; vertical dividers staggered
    // between rows (real tortoise plates are offset row to row).
    func seamH(row: Int, bend: Int) {
        for x in 0..<SW {
            let y = row + (abs(x - 32) > 18 ? bend : 0)
            if g[y][x] == "T" { g[y][x] = "t" }
        }
    }
    seamH(row: 48, bend: 2)
    seamH(row: 62, bend: -1)
    seamH(row: 72, bend: -2)
    for x in [20, 32, 44] {                       // upper plate row
        for y in 49...61 where g[y][x] == "T" { g[y][x] = "t" }
    }
    for x in [26, 38] {                           // lower row, staggered
        for y in 63...71 where g[y][x] == "T" { g[y][x] = "t" }
    }
    // marginal scute ticks along the bottom rim
    for x in stride(from: 12, through: 52, by: 8) {
        for y in 74...76 where g[y][x] == "T" { g[y][x] = "t" }
    }


    // rim: double outline in darkest brown
    outlineShape(&g, body: ["T", "t", "h"], outline: "r")
    outlineShape(&g, body: ["T", "t", "h"], outline: "r")
    return g
}

func shellyLegPart(mode: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    let leftLen: Double = mode == 1 ? 9.0 : 6.5
    let rightLen: Double = mode == 2 ? 9.0 : 6.5
    fillEllipse(&g, cx: 17, cy: 79, rx: 6.4, ry: leftLen, "G")
    fillEllipse(&g, cx: 47, cy: 79, rx: 6.4, ry: rightLen, "G")
    outlineShape(&g, body: ["G"], outline: "g")
    // two toe notches per foot
    let ly = 78 + Int(leftLen), ry2 = 78 + Int(rightLen)
    for tx in [15, 19] where ly < SH { g[ly][tx] = "g"; g[ly - 1][tx] = "g" }
    for tx in [45, 49] where ry2 < SH { g[ry2][tx] = "g"; g[ry2 - 1][tx] = "g" }
    return g
}

func shellyShadowPart() -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    fillEllipse(&g, cx: 32, cy: 89, rx: 24, ry: 4.4, "S")
    return g
}

func shellyFrame(_ spec: FrameSpec) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    composite(&g, shellyShadowPart(), dx: 0, dy: 0)
    composite(&g, shellyLegPart(mode: spec.legMode), dx: 0, dy: 0)
    composite(&g, shellyShellPart(), dx: spec.shellDX, dy: 0)
    composite(&g, shellyHeadPart(), dx: 0, dy: spec.headDY)
    return g
}

func shellyNorthFrame(_ spec: FrameSpec) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    composite(&g, shellyShadowPart(), dx: 0, dy: 0)
    composite(&g, shellyLegPart(mode: spec.legMode), dx: 0, dy: 0)
    composite(&g, shellyShellPart(), dx: spec.shellDX, dy: 0)
    composite(&g, shellyHeadBackPart(), dx: 0, dy: spec.headDY)
    return g
}

func shellyEastFrame(_ spec: FrameSpec) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    composite(&g, shellyShadowPart(), dx: 0, dy: 0)
    composite(&g, shellyLegsEastPart(mode: spec.legMode), dx: 0, dy: 0)
    composite(&g, shellyShellEastPart(), dx: spec.shellDX, dy: 0)
    composite(&g, shellyHeadEastPart(), dx: 0, dy: spec.headDY)
    return g
}

func mirrored(_ g: Grid) -> Grid {
    g.map { Array($0.reversed()) }
}

func shellyIdleFrame(blink: Bool) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    composite(&g, shellyShadowPart(), dx: 0, dy: 0)
    composite(&g, shellyLegPart(mode: 0), dx: 0, dy: 0)
    composite(&g, shellyShellPart(), dx: 0, dy: 0)
    composite(&g, shellyHeadPart(eyesClosed: blink), dx: 0, dy: blink ? 1 : 0)
    return g
}

// MARK: - Shelly battle poses (128x128, bible battle proportions: head ≥40%)

let BW = 128, BH = 128

func shellyBattleShell(cx: Double, cy: Double, rx: Double, ry: Double) -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    shadeEllipse(&g, cx: cx, cy: cy, rx: rx, ry: ry, main: "T", hi: "h", lo: "t")
    func seamH(row: Int, bend: Int) {
        for x in 0..<BW {
            let y = row + (abs(Double(x) - cx) > rx * 0.65 ? bend : 0)
            if y >= 0, y < BH, g[y][x] == "T" { g[y][x] = "t" }
        }
    }
    seamH(row: Int(cy - ry * 0.35), bend: 2)
    seamH(row: Int(cy + ry * 0.15), bend: -1)
    seamH(row: Int(cy + ry * 0.55), bend: -2)
    for x in [Int(cx - rx * 0.45), Int(cx), Int(cx + rx * 0.45)] {
        for y in Int(cy - ry * 0.33)...Int(cy + ry * 0.13) where g[y][x] == "T" { g[y][x] = "t" }
    }
    for x in [Int(cx - rx * 0.22), Int(cx + rx * 0.22)] {
        for y in Int(cy + ry * 0.17)...Int(cy + ry * 0.5) where g[y][x] == "T" { g[y][x] = "t" }
    }
    outlineShape(&g, body: ["T", "t", "h"], outline: "r")
    outlineShape(&g, body: ["T", "t", "h"], outline: "r")
    return g
}

func shellyBattleIdle(frame: Int) -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    let bob = frame == 1 ? 2 : 0
    // limb stubs
    var limbs = emptyGrid(w: BW, h: BH)
    fillEllipse(&limbs, cx: 22, cy: 96, rx: 9, ry: 12, "G")
    fillEllipse(&limbs, cx: 106, cy: 96, rx: 9, ry: 12, "G")
    outlineShape(&limbs, body: ["G"], outline: "g")
    composite(&g, limbs, dx: 0, dy: 0)
    composite(&g, shellyBattleShell(cx: 64, cy: 92, rx: 48, ry: 30), dx: 0, dy: 0)
    // big head (≥40% of sprite height)
    var head = emptyGrid(w: BW, h: BH)
    shadeEllipse(&head, cx: 64, cy: 40, rx: 29, ry: 27, main: "G", hi: "H", lo: "g")
    shadeEllipse(&head, cx: 64, cy: 48, rx: 31, ry: 19, main: "G", hi: "G", lo: "g")
    outlineShape(&head, body: ["G", "H"], outline: "g")
    for (ex, ey) in [(48, 34), (72, 37)] {
        for dy in 0..<9 { for dx in 0..<6 { head[ey + dy][ex + dx] = "E" } }
        for dy in 0..<3 { for dx in 0..<3 { head[ey + dy][ex + 3 + dx] = "W" } }
    }
    for x in 45...56 { head[28][x] = "g"; head[29][x] = "g"; head[30][x] = "g" }
    for (nx, ny) in [(60, 56), (68, 58)] { head[ny][nx] = "g"; head[ny][nx + 1] = "g" }
    composite(&g, head, dx: 0, dy: bob)
    return g
}

/// Iron Shell: everything tucked in — just the shell, eyes peeking from the dark.
func shellyBattleAttack() -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    composite(&g, shellyBattleShell(cx: 64, cy: 76, rx: 52, ry: 36), dx: 0, dy: 0)
    var hole = emptyGrid(w: BW, h: BH)
    fillEllipse(&hole, cx: 64, cy: 52, rx: 14, ry: 7, "E")
    outlineShape(&hole, body: ["E"], outline: "r")
    composite(&g, hole, dx: 0, dy: 0)
    // eyes glinting inside
    for (ex, ey) in [(56, 50), (68, 51)] {
        g[ey][ex] = "W"; g[ey][ex + 1] = "W"; g[ey + 1][ex] = "W"; g[ey + 1][ex + 1] = "W"
    }
    return g
}

func shellyBattleHurt() -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    var limbs = emptyGrid(w: BW, h: BH)
    fillEllipse(&limbs, cx: 20, cy: 92, rx: 9, ry: 12, "G")
    fillEllipse(&limbs, cx: 104, cy: 92, rx: 9, ry: 12, "G")
    outlineShape(&limbs, body: ["G"], outline: "g")
    composite(&g, limbs, dx: 0, dy: 0)
    composite(&g, shellyBattleShell(cx: 64, cy: 92, rx: 48, ry: 30), dx: -3, dy: 2)
    var head = emptyGrid(w: BW, h: BH)
    shadeEllipse(&head, cx: 60, cy: 42, rx: 29, ry: 27, main: "G", hi: "H", lo: "g")
    shadeEllipse(&head, cx: 60, cy: 50, rx: 31, ry: 19, main: "G", hi: "G", lo: "g")
    outlineShape(&head, body: ["G", "H"], outline: "g")
    // X eyes
    for (ex, ey) in [(46, 36), (70, 39)] {
        for i in 0..<7 {
            head[ey + i][ex + i] = "E"; head[ey + i][ex + 6 - i] = "E"
        }
    }
    // wince mouth
    for x in 52...66 { head[62][x] = "g" }
    composite(&g, head, dx: -4, dy: 4)
    return g
}

// MARK: - SPIKE (hedgehog, attacker) — bible §4.2, redesigned
// Classic hedgehog silhouette: the spine coat is a full cape covering the
// crown-to-rump mass; the face emerges from underneath at the lower front.

/// Spine cape: solid quill mass with a serrated (zigzag) silhouette and
/// internal quill-row texture — reference pixel hedgehogs draw the coat as
/// one dark mass with teeth, not sparse needles.
func spikeCape(w: Int, h: Int, cx: Double, cy: Double, r: Double,
               sweep: Double = 0, arcFrom: Double = -230, arcTo: Double = 50,
               tooth: Double = 7, quillBase: Double = 2.6,
               body: Character = "b", dither: Character = "r",
               tip: Character = "h") -> Grid {
    var g = emptyGrid(w: w, h: h)
    fillEllipse(&g, cx: cx, cy: cy, rx: r, ry: r * 1.05, body)
    // reference hedgehogs texture the quill mass with a two-tone dither
    for y in 0..<h { for x in 0..<w where g[y][x] == body {
        if (x + y) % 2 == 0 && (x * 3 + y * 7) % 5 < 3 { g[y][x] = dither }
    } }
    var i = 0
    for deg in stride(from: arcFrom, through: arcTo, by: 11.0) {
        let a = (deg + sweep) * .pi / 180
        let len = tooth + Double((i * 3) % 4)
        let bx = cx + cos(a) * r * 0.96
        let by = cy + sin(a) * r * 1.0
        drawSpike(&g, baseX: bx, baseY: by, angle: a, len: len,
                  baseR: quillBase, body: body, tip: tip)
        i += 1
    }
    return g
}

/// Upright Spike: quill fringe sits BEHIND the head/shoulders like a hooded
/// cape; the front shows face, big cream belly, nub arms, feet.

func spikeQuillHalo(w: Int, h: Int, cx: Double, cy: Double, r: Double,
                    sweep: Double = 0, scale: Double = 1.0) -> Grid {
    spikeCape(w: w, h: h, cx: cx, cy: cy, r: r, sweep: sweep,
              arcFrom: -235, arcTo: 55, tooth: 6 * scale, quillBase: 2.2 * scale)
}

func spikeBody(w: Int, h: Int, cx: Double, cy: Double, scale: Double,
               hurt: Bool = false, armUp: Bool = false) -> Grid {
    var g = emptyGrid(w: w, h: h)
    // tall upright torso
    shadeEllipse(&g, cx: cx, cy: cy + 8 * scale, rx: 17.5 * scale, ry: 22 * scale,
                 main: "B", hi: "h", lo: "b")
    // big cream belly
    fillEllipse(&g, cx: cx, cy: cy + 12 * scale, rx: 12.5 * scale, ry: 15 * scale, "N")
    fillEllipse(&g, cx: cx - 3 * scale, cy: cy + 7 * scale, rx: 5 * scale, ry: 5 * scale, "Y")
    // head overlapping torso top
    shadeEllipse(&g, cx: cx, cy: cy - 20 * scale, rx: 14 * scale, ry: 12 * scale,
                 main: "B", hi: "h", lo: "b")
    // snout patch
    fillEllipse(&g, cx: cx, cy: cy - 14 * scale, rx: 7 * scale, ry: 5 * scale, "N")
    // tiny round ears at the hood line
    fillEllipse(&g, cx: cx - 11 * scale, cy: cy - 29 * scale, rx: 3.4 * scale, ry: 3 * scale, "B")
    fillEllipse(&g, cx: cx + 11 * scale, cy: cy - 29 * scale, rx: 3.4 * scale, ry: 3 * scale, "B")
    // nub arms
    let armY = cy + Double(armUp ? -2 : 2) * scale
    fillEllipse(&g, cx: cx - 18.5 * scale, cy: armY, rx: 4.4 * scale, ry: 6 * scale, "B")
    fillEllipse(&g, cx: cx + 18.5 * scale, cy: cy + 2 * scale, rx: 4.4 * scale, ry: 6 * scale, "B")
    outlineShape(&g, body: ["B", "N", "Y", "h", "b"], outline: "b")
    // eyes + uneven determined brows
    let eyeSize = max(3, Int(4 * scale))
    let eyeOff = Int(7 * scale)
    let eyeY = Int(cy - 24 * scale)
    for (i, ex) in [Int(cx) - eyeOff - eyeSize, Int(cx) + eyeOff - 1].enumerated() {
        let ey = eyeY + i
        if hurt {
            for k in 0..<eyeSize + 2 {
                g[ey + k][ex + k] = "E"; g[ey + k][ex + eyeSize + 1 - k] = "E"
            }
        } else {
            for dy in 0..<(eyeSize + 1) { for dx in 0..<eyeSize { g[ey + dy][ex + dx] = "E" } }
            g[ey][ex + eyeSize - 1] = "W"; g[ey + 1][ex + eyeSize - 1] = "W"
        }
        for dx in 0..<Int(5 * scale) { g[ey - Int(3 * scale)][ex - 1 + dx] = "b" }
    }
    // nose
    fillEllipse(&g, cx: cx, cy: cy - 15 * scale, rx: 2.2 * scale, ry: 1.7 * scale, "E")
    // blush
    fillEllipse(&g, cx: cx - 10 * scale, cy: cy - 17 * scale, rx: 1.8 * scale, ry: 1.2 * scale, "P")
    fillEllipse(&g, cx: cx + 10 * scale, cy: cy - 17 * scale, rx: 1.8 * scale, ry: 1.2 * scale, "P")
    return g
}

func spikeFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 88, rx: 19, ry: 3.8, "S")
    composite(&g, sh, dx: 0, dy: 0)
    let dy = f == 1 ? 2 : (f == 3 ? -1 : 0)
    var feet = emptyGrid(w: SW, h: SH)
    fillEllipse(&feet, cx: 25, cy: 84 - Double(f == 3 ? 4 : 0), rx: 5, ry: 5, "B")
    fillEllipse(&feet, cx: 39, cy: 84, rx: 5, ry: 5, "B")
    outlineShape(&feet, body: ["B"], outline: "b")
    composite(&g, feet, dx: 0, dy: 0)
    // quill halo behind head + shoulders
    composite(&g, spikeQuillHalo(w: SW, h: SH, cx: 32, cy: 36, r: 20,
                                 sweep: f == 1 ? 8 : 0), dx: 0, dy: dy)
    composite(&g, spikeBody(w: SW, h: SH, cx: 32, cy: 54, scale: 1.0,
                            armUp: f == 3), dx: 0, dy: dy)
    return g
}

func spikeNorthFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 88, rx: 19, ry: 3.8, "S")
    composite(&g, sh, dx: 0, dy: 0)
    let dy = f == 1 ? 2 : (f == 3 ? -1 : 0)
    var feet = emptyGrid(w: SW, h: SH)
    fillEllipse(&feet, cx: 25, cy: 84 - Double(f == 3 ? 4 : 0), rx: 5, ry: 5, "B")
    fillEllipse(&feet, cx: 39, cy: 84, rx: 5, ry: 5, "B")
    outlineShape(&feet, body: ["B"], outline: "b")
    composite(&g, feet, dx: 0, dy: 0)
    // from behind: tall quill cloak covers head + back
    var cloak = emptyGrid(w: SW, h: SH)
    fillEllipse(&cloak, cx: 32, cy: 52, rx: 17, ry: 28, "b")
    for y in 0..<SH { for x in 0..<SW where cloak[y][x] == "b" {
        if (x + y) % 2 == 0 && (x * 3 + y * 7) % 5 < 3 { cloak[y][x] = "r" }
    } }
    var i = 0
    for deg in stride(from: -250.0, through: 70.0, by: 12.0) {
        let a = deg * .pi / 180
        let bx = 32 + cos(a) * 16
        let by = 52 + sin(a) * 27
        drawSpike(&cloak, baseX: bx, baseY: by, angle: a, len: 6 + Double((i * 3) % 4),
                  baseR: 2.2, body: "b", tip: "h")
        i += 1
    }
    composite(&g, cloak, dx: 0, dy: dy)
    return g
}

func spikeEastFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 88, rx: 19, ry: 3.8, "S")
    composite(&g, sh, dx: 0, dy: 0)
    let step: Double = f == 0 ? 5 : (f == 2 ? -5 : 0)
    let dy = f == 1 ? 1 : 0
    var feet = emptyGrid(w: SW, h: SH)
    fillEllipse(&feet, cx: 38 + step, cy: 84, rx: 5, ry: 5, "B")
    fillEllipse(&feet, cx: 24 - step, cy: 84, rx: 5, ry: 5, "B")
    outlineShape(&feet, body: ["B"], outline: "b")
    composite(&g, feet, dx: 0, dy: 0)
    // quill cloak on the back (left side), serrated outward arc
    var cloak = emptyGrid(w: SW, h: SH)
    fillEllipse(&cloak, cx: 27, cy: 48, rx: 15, ry: 24, "b")
    for y in 0..<SH { for x in 0..<SW where cloak[y][x] == "b" {
        if (x + y) % 2 == 0 && (x * 3 + y * 7) % 5 < 3 { cloak[y][x] = "r" }
    } }
    var i = 0
    for deg in stride(from: -255.0, through: -60.0, by: 12.0) {
        let a = deg * .pi / 180
        let bx = 27 + cos(a) * 14
        let by = 48 + sin(a) * 23
        drawSpike(&cloak, baseX: bx, baseY: by, angle: a, len: 6 + Double((i * 3) % 4),
                  baseR: 2.2, body: "b", tip: "h")
        i += 1
    }
    composite(&g, cloak, dx: 0, dy: dy)
    // upright body: torso + belly sliver + head with snout right
    var body = emptyGrid(w: SW, h: SH)
    shadeEllipse(&body, cx: 34, cy: 62, rx: 15.5, ry: 20, main: "B", hi: "h", lo: "b")
    fillEllipse(&body, cx: 40, cy: 66, rx: 9.5, ry: 13, "N")
    shadeEllipse(&body, cx: 36, cy: 32, rx: 13, ry: 11, main: "B", hi: "h", lo: "b")
    fillEllipse(&body, cx: 47, cy: 36, rx: 7, ry: 4.5, "N")
    fillEllipse(&body, cx: 44, cy: 58, rx: 4, ry: 6, "B")   // near arm
    outlineShape(&body, body: ["B", "N", "h", "b"], outline: "b")
    for dyE in 0..<5 { for dxE in 0..<4 { body[26 + dyE][38 + dxE] = "E" } }
    body[26][40] = "W"; body[27][40] = "W"
    for dxE in 0..<5 { body[22][36 + dxE] = "b" }
    fillEllipse(&body, cx: 51, cy: 35, rx: 2.2, ry: 1.7, "E")
    composite(&g, body, dx: 0, dy: dy)
    return g
}

func spikeBattleIdle(frame: Int) -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    let dy = frame == 1 ? 2 : 0
    var feet = emptyGrid(w: BW, h: BH)
    fillEllipse(&feet, cx: 50, cy: 116, rx: 9, ry: 8, "B")
    fillEllipse(&feet, cx: 78, cy: 116, rx: 9, ry: 8, "B")
    outlineShape(&feet, body: ["B"], outline: "b")
    composite(&g, feet, dx: 0, dy: 0)
    composite(&g, spikeQuillHalo(w: BW, h: BH, cx: 64, cy: 40, r: 36,
                                 scale: 1.7), dx: 0, dy: dy)
    composite(&g, spikeBody(w: BW, h: BH, cx: 64, cy: 62, scale: 1.8), dx: 0, dy: dy)
    return g
}

func spikeBattleHurt() -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    var feet = emptyGrid(w: BW, h: BH)
    fillEllipse(&feet, cx: 50, cy: 116, rx: 9, ry: 8, "B")
    fillEllipse(&feet, cx: 78, cy: 116, rx: 9, ry: 8, "B")
    outlineShape(&feet, body: ["B"], outline: "b")
    composite(&g, feet, dx: 0, dy: 0)
    composite(&g, spikeQuillHalo(w: BW, h: BH, cx: 64, cy: 40, r: 36,
                                 sweep: -10, scale: 1.7), dx: 4, dy: 4)
    composite(&g, spikeBody(w: BW, h: BH, cx: 64, cy: 62, scale: 1.8,
                            hurt: true), dx: 2, dy: 6)
    return g
}

/// Curl & Roll: full spiked ball, face tucked away.
func spikeBattleAttack() -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    var spines = emptyGrid(w: BW, h: BH)
    fillEllipse(&spines, cx: 64, cy: 72, rx: 34, ry: 34, "b")
    for y in 0..<BH { for x in 0..<BW where spines[y][x] == "b" {
        if (x + y) % 2 == 0 && (x * 3 + y * 7) % 5 < 3 { spines[y][x] = "r" }
    } }
    for i in 0..<16 {
        let a = Double(i) * (.pi * 2 / 16) + 0.2
        let len = 12.0 + Double((i * 7) % 8)
        let bx = 64 + cos(a) * 31, by = 72 + sin(a) * 31
        drawSpike(&spines, baseX: bx, baseY: by, angle: a, len: len,
                  baseR: 3.4, body: "b", tip: "h")
    }
    composite(&g, spines, dx: 0, dy: 0)
    var core = emptyGrid(w: BW, h: BH)
    shadeEllipse(&core, cx: 64, cy: 72, rx: 16, ry: 16, main: "B", hi: "h", lo: "b")
    outlineShape(&core, body: ["B", "h", "b"], outline: "b")
    composite(&g, core, dx: 0, dy: 0)
    return g
}

// MARK: - HAZEL (squirrel, support/speed) — bible §4.2
// Tail = 35% of visible area, arcs over the head with one kink.

/// Smooth tapered tail: subdivides waypoint segments so overlapping
/// ellipses merge into one continuous shape. `tipFrom` = fraction of the
/// path length after which the tip color takes over.
func drawTail(_ g: inout Grid, path: [(Double, Double, Double)],
              dx: Double = 0, body: Character, tip: Character,
              outline: Character, tipFrom: Double = 0.7) {
    var tail = emptyGrid(w: g.count > 0 ? g[0].count : 0, h: g.count)
    let segs = path.count - 1
    for s in 0..<segs {
        let (x0, y0, r0) = path[s], (x1, y1, r1) = path[s + 1]
        for step in 0..<4 {
            let t = Double(step) / 4.0
            let frac = (Double(s) + t) / Double(segs)
            fillEllipse(&tail,
                        cx: x0 + (x1 - x0) * t + dx,
                        cy: y0 + (y1 - y0) * t,
                        rx: r0 + (r1 - r0) * t,
                        ry: (r0 + (r1 - r0) * t) + 1,
                        frac >= tipFrom ? tip : body)
        }
    }
    fillEllipse(&tail, cx: path.last!.0 + dx, cy: path.last!.1,
                rx: path.last!.2, ry: path.last!.2 + 1, tip)
    outlineShape(&tail, body: [body, tip], outline: outline)
    composite(&g, tail, dx: 0, dy: 0)
}

func hazelTailPart(mode: Int = 0) -> Grid {   // 0 up, 1 swept back, 2 sway
    var g = emptyGrid(w: SW, h: SH)
    let dx: Double = mode == 1 ? 4 : (mode == 2 ? -2 : 0)
    // arc waypoints with a kink two-thirds up
    drawTail(&g, path: [
        (46, 70, 7), (52, 58, 8), (54, 44, 9), (52, 32, 9),   // rise
        (44, 20, 8), (34, 13, 7)                              // kink → over head
    ], dx: dx, body: "M", tip: "C", outline: "m")
    return g
}

func hazelBodyPart(kick: Bool = false, headDY: Int = 0) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    // legs
    fillEllipse(&g, cx: 22, cy: 80 - (kick ? 4 : 0), rx: 4.5, ry: 5, "M")
    fillEllipse(&g, cx: 36, cy: 80, rx: 4.5, ry: 5, "M")
    // slim body
    shadeEllipse(&g, cx: 28, cy: 62, rx: 13, ry: 17, main: "M", hi: "M", lo: "m")
    fillEllipse(&g, cx: 28, cy: 66, rx: 7, ry: 10, "C")   // belly stripe
    outlineShape(&g, body: ["M", "C"], outline: "m")
    // head with cheek puffs (1px wider each side than it "should" be)
    var head = emptyGrid(w: SW, h: SH)
    // ears first (behind head dome)
    fillEllipse(&head, cx: 18, cy: 15, rx: 5, ry: 7, "M")
    fillEllipse(&head, cx: 38, cy: 14, rx: 5, ry: 7, "M")
    fillEllipse(&head, cx: 18, cy: 16, rx: 2.2, ry: 3.5, "P")
    fillEllipse(&head, cx: 38, cy: 15, rx: 2.2, ry: 3.5, "P")
    shadeEllipse(&head, cx: 28, cy: 30, rx: 15, ry: 14, main: "M", hi: "t", lo: "m")
    shadeEllipse(&head, cx: 28, cy: 34, rx: 16.5, ry: 10, main: "M", hi: "M", lo: "m")   // cheeks
    outlineShape(&head, body: ["M", "P", "t"], outline: "m")
    // amber eyes with dark iris + catchlight
    for (ex, ey) in [(20, 26), (32, 26)] {
        for dy in 0..<5 { for dx in 0..<5 { head[ey + dy][ex + dx] = "I" } }
        for dy in 1..<4 { for dx in 1..<4 { head[ey + dy][ex + dx] = "E" } }
        head[ey + 1][ex + 3] = "W"
    }
    fillEllipse(&head, cx: 28, cy: 36, rx: 1.8, ry: 1.4, "m")   // nose
    composite(&g, head, dx: 0, dy: headDY)
    return g
}

func hazelFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 29, cy: 87, rx: 18, ry: 3.6, "S")
    composite(&g, sh, dx: 0, dy: 0)
    switch f {
    case 1:  composite(&g, hazelTailPart(mode: 1), dx: 0, dy: 0)
             composite(&g, hazelBodyPart(headDY: 1), dx: 0, dy: 0)
    case 2:  composite(&g, hazelTailPart(), dx: 0, dy: 0)
             composite(&g, hazelBodyPart(kick: true), dx: 0, dy: 0)
    case 3:  composite(&g, hazelTailPart(mode: 2), dx: 0, dy: 0)
             composite(&g, hazelBodyPart(), dx: 0, dy: 0)
    default: composite(&g, hazelTailPart(), dx: 0, dy: 0)
             composite(&g, hazelBodyPart(), dx: 0, dy: 0)
    }
    return g
}

func hazelNorthFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 29, cy: 87, rx: 18, ry: 3.6, "S")
    composite(&g, sh, dx: 0, dy: 0)
    // body + back of head
    var body = emptyGrid(w: SW, h: SH)
    fillEllipse(&body, cx: 22, cy: 80 - (f == 2 ? 4 : 0), rx: 4.5, ry: 5, "M")
    fillEllipse(&body, cx: 36, cy: 80, rx: 4.5, ry: 5, "M")
    shadeEllipse(&body, cx: 28, cy: 62, rx: 13, ry: 17, main: "M", hi: "M", lo: "m")
    fillEllipse(&body, cx: 18, cy: 15, rx: 5, ry: 7, "M")
    fillEllipse(&body, cx: 38, cy: 14, rx: 5, ry: 7, "M")
    shadeEllipse(&body, cx: 28, cy: 30, rx: 15, ry: 14, main: "M", hi: "t", lo: "m")
    outlineShape(&body, body: ["M", "t"], outline: "m")
    composite(&g, body, dx: 0, dy: 0)
    // tail in FRONT when seen from behind
    composite(&g, hazelTailPart(mode: f == 1 ? 1 : (f == 3 ? 2 : 0)), dx: -18, dy: 0)
    return g
}

func hazelEastFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 87, rx: 18, ry: 3.6, "S")
    composite(&g, sh, dx: 0, dy: 0)
    composite(&g, hazelTailPart(mode: f == 1 ? 1 : 0), dx: -14, dy: 0)
    var body = emptyGrid(w: SW, h: SH)
    let stride: Double = f == 0 ? 4 : (f == 2 ? -4 : 0)
    fillEllipse(&body, cx: 36 + stride, cy: 80, rx: 4.5, ry: 5.5, "M")
    fillEllipse(&body, cx: 24 - stride, cy: 80, rx: 4.5, ry: 5.5, "M")
    shadeEllipse(&body, cx: 30, cy: 62, rx: 13, ry: 17, main: "M", hi: "M", lo: "m")
    // profile head: ear, dome, muzzle
    fillEllipse(&body, cx: 30, cy: 14, rx: 5, ry: 7, "M")
    shadeEllipse(&body, cx: 34, cy: 30, rx: 14, ry: 13, main: "M", hi: "t", lo: "m")
    fillEllipse(&body, cx: 46, cy: 35, rx: 6, ry: 4.5, "M")   // muzzle
    outlineShape(&body, body: ["M", "t"], outline: "m")
    fillEllipse(&body, cx: 30, cy: 15, rx: 2, ry: 3.2, "P")
    for dy in 0..<5 { for dx in 0..<5 { body[26 + dy][38 + dx] = "I" } }
    for dy in 1..<4 { for dx in 1..<4 { body[26 + dy][38 + dx] = "E" } }
    body[27][41] = "W"
    fillEllipse(&body, cx: 52, cy: 34, rx: 1.6, ry: 1.4, "m")
    composite(&g, body, dx: 0, dy: f == 1 ? 1 : 0)
    return g
}

func hazelBattleIdle(frame: Int) -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    let sway = frame == 1 ? 3 : 0
    // giant tail behind, arcing over the head
    drawTail(&g, path: [
        (92, 108, 13), (102, 84, 15), (104, 58, 16), (98, 36, 15),
        (82, 20, 13), (62, 12, 11)
    ], dx: Double(sway), body: "M", tip: "C", outline: "m", tipFrom: 0.75)
    var body = emptyGrid(w: BW, h: BH)
    fillEllipse(&body, cx: 40, cy: 112, rx: 8, ry: 9, "M")
    fillEllipse(&body, cx: 62, cy: 112, rx: 8, ry: 9, "M")
    shadeEllipse(&body, cx: 50, cy: 84, rx: 22, ry: 28, main: "M", hi: "M", lo: "m")
    fillEllipse(&body, cx: 50, cy: 92, rx: 12, ry: 16, "C")
    fillEllipse(&body, cx: 32, cy: 26, rx: 9, ry: 13, "M")
    fillEllipse(&body, cx: 66, cy: 24, rx: 9, ry: 13, "M")
    fillEllipse(&body, cx: 32, cy: 28, rx: 4, ry: 6.5, "P")
    fillEllipse(&body, cx: 66, cy: 26, rx: 4, ry: 6.5, "P")
    shadeEllipse(&body, cx: 49, cy: 48, rx: 26, ry: 24, main: "M", hi: "t", lo: "m")
    shadeEllipse(&body, cx: 49, cy: 55, rx: 28.5, ry: 17, main: "M", hi: "M", lo: "m")
    outlineShape(&body, body: ["M", "C", "P", "t"], outline: "m")
    for (ex, ey) in [(34, 42), (56, 42)] {
        for dy in 0..<9 { for dx in 0..<9 { body[ey + dy][ex + dx] = "I" } }
        for dy in 2..<7 { for dx in 2..<7 { body[ey + dy][ex + dx] = "E" } }
        for dy in 2..<4 { for dx in 5..<7 { body[ey + dy][ex + dx] = "W" } }
    }
    fillEllipse(&body, cx: 49, cy: 60, rx: 3, ry: 2.4, "m")
    composite(&g, body, dx: 0, dy: 0)
    return g
}

/// Acorn Toss: arm up, acorn mid-air.
func hazelBattleAttack() -> Grid {
    var g = hazelBattleIdle(frame: 0)
    // raised arm
    var arm = emptyGrid(w: BW, h: BH)
    fillEllipse(&arm, cx: 24, cy: 58, rx: 6, ry: 12, "M")
    outlineShape(&arm, body: ["M"], outline: "m")
    composite(&g, arm, dx: 0, dy: 0)
    // acorn: brown nut + darker cap, flying upper-left
    var acorn = emptyGrid(w: BW, h: BH)
    fillEllipse(&acorn, cx: 14, cy: 28, rx: 6, ry: 7, "B")
    fillEllipse(&acorn, cx: 14, cy: 23, rx: 6.5, ry: 3, "b")
    outlineShape(&acorn, body: ["B", "b"], outline: "m")
    composite(&g, acorn, dx: 0, dy: 0)
    return g
}

func hazelBattleHurt() -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    var tail = emptyGrid(w: BW, h: BH)
    drawTail(&tail, path: [
        (94, 110, 13), (104, 88, 15), (106, 64, 15), (100, 44, 14),
        (86, 30, 12), (68, 24, 10)
    ], body: "M", tip: "C", outline: "m", tipFrom: 0.75)
    composite(&g, tail, dx: 2, dy: 4)
    var body = emptyGrid(w: BW, h: BH)
    fillEllipse(&body, cx: 40, cy: 112, rx: 8, ry: 9, "M")
    fillEllipse(&body, cx: 62, cy: 112, rx: 8, ry: 9, "M")
    shadeEllipse(&body, cx: 50, cy: 84, rx: 22, ry: 28, main: "M", hi: "M", lo: "m")
    fillEllipse(&body, cx: 50, cy: 92, rx: 12, ry: 16, "C")
    fillEllipse(&body, cx: 30, cy: 28, rx: 9, ry: 13, "M")
    fillEllipse(&body, cx: 64, cy: 26, rx: 9, ry: 13, "M")
    shadeEllipse(&body, cx: 47, cy: 50, rx: 26, ry: 24, main: "M", hi: "t", lo: "m")
    outlineShape(&body, body: ["M", "C", "t"], outline: "m")
    for (ex, ey) in [(34, 44), (56, 44)] {
        for i in 0..<9 { body[ey + i][ex + i] = "E"; body[ey + i][ex + 8 - i] = "E" }
    }
    for x in 42...56 { body[66][x] = "m" }
    composite(&g, body, dx: -4, dy: 4)
    return g
}

// MARK: - PIP (hamster, chaos) — bible §4.2
// Nearly circular. Cheek pouches always full (60% of body width),
// bright pink nose, close-set worried eyes, left ear higher.

func pipBodyPart(lookLeft: Bool = false, cheekBulge: Int = 0) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    // ears behind (left ear 2px higher — perpetual confusion)
    fillEllipse(&g, cx: 20, cy: 24, rx: 5.5, ry: 6.5, "K")
    fillEllipse(&g, cx: 44, cy: 26, rx: 5.5, ry: 6.5, "K")
    // near-circular body, form-shaded
    shadeEllipse(&g, cx: 32, cy: 54, rx: 23, ry: 25, main: "K", hi: "K", lo: "k")
    // cheek pouches on the lower face — asymmetric, left one fuller
    // (he is always mid-snack)
    fillEllipse(&g, cx: 12 - Double(cheekBulge), cy: 54, rx: 8, ry: 8.5, "K")
    fillEllipse(&g, cx: 52 + Double(cheekBulge), cy: 55, rx: 6.5, ry: 7, "K")
    // chest tuft
    fillEllipse(&g, cx: 30, cy: 66, rx: 7, ry: 6, "Y")
    outlineShape(&g, body: ["K", "k", "Y"], outline: "k")
    // inner ears after outline
    fillEllipse(&g, cx: 20, cy: 25, rx: 2.5, ry: 3.5, "P")
    fillEllipse(&g, cx: 44, cy: 27, rx: 2.5, ry: 3.5, "P")
    // close-set worried eyes
    let shift = lookLeft ? -2 : 0
    for (ex, ey) in [(25, 44), (33, 44)] {
        for dy in 0..<5 { for dx in 0..<5 { g[ey + dy][ex + dx] = "E" } }
        g[ey + 1][ex + 3 + shift] = "W"; g[ey + 1][ex + 2 + shift] = "W"
    }
    // worry brows (tilted outward)
    g[41][24] = "k"; g[40][25] = "k"; g[40][37] = "k"; g[41][38] = "k"
    // bright pink nose — his defining feature
    fillEllipse(&g, cx: 31.5, cy: 52, rx: 3, ry: 2.2, "O")
    // tiny nub arms held up against the chest (ringed so they read on-body)
    for armX in [23.0, 41.0] {
        fillEllipse(&g, cx: armX, cy: 63, rx: 4.5, ry: 5.5, "k")
        fillEllipse(&g, cx: armX, cy: 63, rx: 3.0, ry: 4.0, "K")
    }
    // feet: tiny, barely visible
    g[78][26] = "k"; g[78][27] = "k"; g[78][37] = "k"; g[78][38] = "k"
    return g
}

func pipFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 84, rx: 22, ry: 4, "S")
    composite(&g, sh, dx: 0, dy: 0)
    switch f {
    case 0:  composite(&g, pipBodyPart(cheekBulge: 1), dx: -1, dy: 0)   // waddle left
    case 2:  composite(&g, pipBodyPart(cheekBulge: 1), dx: 1, dy: 0)    // waddle right
    case 3:  composite(&g, pipBodyPart(lookLeft: true), dx: 0, dy: 0)   // suspicious stop
    default: composite(&g, pipBodyPart(), dx: 0, dy: 0)
    }
    return g
}

func pipNorthFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 84, rx: 22, ry: 4, "S")
    composite(&g, sh, dx: 0, dy: 0)
    var body = emptyGrid(w: SW, h: SH)
    fillEllipse(&body, cx: 20, cy: 24, rx: 5.5, ry: 6.5, "K")
    fillEllipse(&body, cx: 44, cy: 26, rx: 5.5, ry: 6.5, "K")
    shadeEllipse(&body, cx: 32, cy: 54, rx: 23, ry: 25, main: "K", hi: "K", lo: "k")
    fillEllipse(&body, cx: 11, cy: 56, rx: 6.5, ry: 7.5, "K")
    fillEllipse(&body, cx: 53, cy: 56, rx: 6.5, ry: 7.5, "K")
    outlineShape(&body, body: ["K", "k"], outline: "k")
    // tail dot
    fillEllipse(&body, cx: 32, cy: 74, rx: 2.5, ry: 2, "k")
    let dx = f == 0 ? -1 : (f == 2 ? 1 : 0)
    composite(&g, body, dx: dx, dy: 0)
    return g
}

func pipEastFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 84, rx: 22, ry: 4, "S")
    composite(&g, sh, dx: 0, dy: 0)
    var body = emptyGrid(w: SW, h: SH)
    fillEllipse(&body, cx: 26, cy: 24, rx: 5.5, ry: 6.5, "K")     // ear
    shadeEllipse(&body, cx: 32, cy: 54, rx: 23, ry: 25, main: "K", hi: "K", lo: "k")
    fillEllipse(&body, cx: 50, cy: 56, rx: 7, ry: 8, "K")          // cheek right
    outlineShape(&body, body: ["K", "k"], outline: "k")
    fillEllipse(&body, cx: 26, cy: 25, rx: 2.5, ry: 3.5, "P")
    for dy in 0..<5 { for dx in 0..<5 { body[44 + dy][40 + dx] = "E" } }
    body[45][43] = "W"
    fillEllipse(&body, cx: 54, cy: 50, rx: 2.8, ry: 2.2, "O")
    fillEllipse(&body, cx: 44, cy: 62, rx: 4.5, ry: 5.5, "k")
    fillEllipse(&body, cx: 44, cy: 62, rx: 3.0, ry: 4.0, "K")
    let dx = f == 0 ? 1 : (f == 2 ? -1 : 0)
    composite(&g, body, dx: dx, dy: f == 1 ? 1 : 0)
    return g
}

func pipBattleIdle(frame: Int) -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    let puff = frame == 1 ? 2 : 0
    var body = emptyGrid(w: BW, h: BH)
    fillEllipse(&body, cx: 40, cy: 40, rx: 10, ry: 12, "K")
    fillEllipse(&body, cx: 86, cy: 44, rx: 10, ry: 12, "K")
    shadeEllipse(&body, cx: 64, cy: 78, rx: 42, ry: 46, main: "K", hi: "K", lo: "k")
    fillEllipse(&body, cx: 17 - Double(puff), cy: 82, rx: 14, ry: 16, "K")
    fillEllipse(&body, cx: 111 + Double(puff), cy: 84, rx: 11, ry: 13, "K")
    fillEllipse(&body, cx: 60, cy: 100, rx: 13, ry: 11, "Y")
    outlineShape(&body, body: ["K", "k", "Y"], outline: "k")
    fillEllipse(&body, cx: 40, cy: 42, rx: 4.5, ry: 6.5, "P")
    fillEllipse(&body, cx: 86, cy: 46, rx: 4.5, ry: 6.5, "P")
    for (ex, ey) in [(50, 60), (66, 60)] {
        for dy in 0..<9 { for dx in 0..<9 { body[ey + dy][ex + dx] = "E" } }
        for dy in 1..<4 { for dx in 4..<8 { body[ey + dy][ex + dx] = "W" } }
    }
    body[55][48] = "k"; body[54][50] = "k"; body[54][74] = "k"; body[55][76] = "k"
    fillEllipse(&body, cx: 62, cy: 76, rx: 6, ry: 4.4, "O")
    for armX in [44.0, 84.0] {
        fillEllipse(&body, cx: armX, cy: 96, rx: 8, ry: 10, "k")
        fillEllipse(&body, cx: armX, cy: 96, rx: 5.5, ry: 7.5, "K")
    }
    composite(&g, body, dx: 0, dy: 0)
    return g
}

/// Chaos Toss: something gold and inexplicable is airborne.
func pipBattleAttack() -> Grid {
    var g = pipBattleIdle(frame: 0)
    var arm = emptyGrid(w: BW, h: BH)
    fillEllipse(&arm, cx: 24, cy: 62, rx: 7, ry: 13, "K")
    outlineShape(&arm, body: ["K"], outline: "k")
    composite(&g, arm, dx: 0, dy: 0)
    // gold chaos star (4-point burst)
    var star = emptyGrid(w: BW, h: BH)
    for i in 0..<8 {
        let a = Double(i) * (.pi / 4)
        let len: Double = i % 2 == 0 ? 11 : 5
        drawSpike(&star, baseX: 18, baseY: 22, angle: a, len: len,
                  baseR: 2.4, body: "Q", tip: "Q")
    }
    composite(&g, star, dx: 0, dy: 0)
    return g
}

func pipBattleHurt() -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    var body = emptyGrid(w: BW, h: BH)
    fillEllipse(&body, cx: 40, cy: 42, rx: 10, ry: 12, "K")
    fillEllipse(&body, cx: 86, cy: 46, rx: 10, ry: 12, "K")
    shadeEllipse(&body, cx: 64, cy: 80, rx: 42, ry: 44, main: "K", hi: "K", lo: "k")
    fillEllipse(&body, cx: 16, cy: 86, rx: 12, ry: 14, "K")
    fillEllipse(&body, cx: 108, cy: 86, rx: 12, ry: 14, "K")
    outlineShape(&body, body: ["K", "k"], outline: "k")
    for (ex, ey) in [(48, 60), (68, 60)] {
        for i in 0..<9 { body[ey + i][ex + i] = "E"; body[ey + i][ex + 8 - i] = "E" }
    }
    fillEllipse(&body, cx: 62, cy: 78, rx: 6, ry: 4.4, "O")
    for x in 54...72 { body[92][x] = "k" }
    composite(&g, body, dx: -3, dy: 5)
    return g
}

// MARK: - HOUSES (bible Part 3 anatomy, MAP_SPEC §3.14 roof variants)
// 112x80 px = 7x5 tiles. Roof (2 tile rows) → wall w/ asymmetric windows →
// foundation strip → door reaching ground. Selective outline in dark brown.

struct RGB { let r: UInt8, g: UInt8, b: UInt8 }

let roofColors: [String: (RGB, RGB)] = [   // (main, shadow)
    "dark_purple": (RGB(r: 0x5A, g: 0x46, b: 0x6E), RGB(r: 0x42, g: 0x32, b: 0x52)),
    "blue":        (RGB(r: 0x3A, g: 0x5F, b: 0xA0), RGB(r: 0x2A, g: 0x46, b: 0x78)),
    "brown":       (RGB(r: 0x6E, g: 0x4C, b: 0x2A), RGB(r: 0x54, g: 0x38, b: 0x1E)),
    "green":       (RGB(r: 0x3D, g: 0x72, b: 0x20), RGB(r: 0x2A, g: 0x50, b: 0x18)),
    "red_brown":   (RGB(r: 0x8B, g: 0x4A, b: 0x2A), RGB(r: 0x6A, g: 0x36, b: 0x1E)),
    "dark_red":    (RGB(r: 0x7A, g: 0x28, b: 0x28), RGB(r: 0x5A, g: 0x1C, b: 0x1C)),
    "charcoal":    (RGB(r: 0x3A, g: 0x3A, b: 0x3E), RGB(r: 0x2A, g: 0x2A, b: 0x2E)),
    "tan":         (RGB(r: 0xC4, g: 0x95, b: 0x5A), RGB(r: 0xA0, g: 0x78, b: 0x40)),
]

// Deterministic per-variant hash (Swift's hashValue is run-seeded).
func fnv(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf29ce484222325
    for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
    return h
}

func houseImage(variant: String) -> CGImage {
    let W = 112, H = 80
    var px = [UInt8](repeating: 0, count: W * H * 4)
    func put(_ x: Int, _ y: Int, _ c: RGB) {
        guard x >= 0, x < W, y >= 0, y < H else { return }
        let i = (y * W + x) * 4
        px[i] = c.r; px[i + 1] = c.g; px[i + 2] = c.b; px[i + 3] = 255
    }
    func rect(_ x0: Int, _ y0: Int, _ w: Int, _ h: Int, _ c: RGB) {
        for y in y0..<(y0 + h) { for x in x0..<(x0 + w) { put(x, y, c) } }
    }

    let wall     = RGB(r: 0xC4, g: 0x95, b: 0x5A)   // palette C wood siding
    let wallSh   = RGB(r: 0xA0, g: 0x78, b: 0x40)
    let outline  = RGB(r: 0x3C, g: 0x28, b: 0x10)   // dark brown, never black
    let frame    = RGB(r: 0x3C, g: 0x2E, b: 0x1A)
    let glassLit = RGB(r: 0xF0, g: 0xE8, b: 0x90)
    let glassDrk = RGB(r: 0x2A, g: 0x3A, b: 0x4A)
    let found    = RGB(r: 0x5A, g: 0x42, b: 0x28)
    let doorC    = RGB(r: 0x5A, g: 0x3E, b: 0x1E)
    let doorDk   = RGB(r: 0x3C, g: 0x28, b: 0x10)
    let knob     = RGB(r: 0xD4, g: 0xB0, b: 0x30)
    let acGray   = RGB(r: 0x48, g: 0x48, b: 0x48)
    let acLite   = RGB(r: 0x5A, g: 0x5A, b: 0x5A)
    let (roof, roofSh) = roofColors[variant] ?? roofColors["brown"]!
    let h = fnv(variant)

    // Roof rows 0-27, full width, shingle courses every 5px.
    rect(0, 0, W, 28, roof)
    for y in stride(from: 5, to: 28, by: 5) { rect(0, y, W, 1, roofSh) }
    // shingle tabs (staggered)
    for y in stride(from: 2, to: 26, by: 5) {
        let off = (y / 5) % 2 == 0 ? 0 : 6
        for x in stride(from: off, to: W, by: 12) { put(x, y, roofSh); put(x, y + 1, roofSh) }
    }
    rect(0, 27, W, 1, roofSh)                         // eave shadow

    // Wall rows 28-69, plank lines every 7px.
    rect(1, 28, W - 2, 42, wall)
    for y in stride(from: 34, to: 69, by: 7) { rect(1, y, W - 2, 1, wallSh) }

    // Windows: left lit or dark by variant hash; right window 2px lower
    // (asymmetry rule). Sizes differ slightly.
    let leftLit = h % 2 == 0
    rect(14, 34, 14, 16, frame)
    rect(15, 35, 12, 14, leftLit ? glassLit : glassDrk)
    rect(78, 36, 14, 15, frame)
    rect(79, 37, 12, 13, leftLit ? glassDrk : glassLit)
    if leftLit { rect(79, 37, 12, 3, RGB(r: 0x3A, g: 0x4C, b: 0x5E)) }  // curtain hint

    // Foundation rows 70-79 with darker top lip.
    rect(0, 70, W, 10, found)
    rect(0, 70, W, 1, outline)

    // Door: off-center (bible: never centered), reaches ground.
    let doorX = h % 3 == 0 ? 40 : 46
    rect(doorX, 50, 18, 30, doorDk)
    rect(doorX + 1, 51, 16, 29, doorC)
    rect(doorX + 3, 54, 12, 1, doorDk)                // panel line
    put(doorX + 13, 66, knob); put(doorX + 14, 66, knob)

    // AC unit: off-center right, never top floor. Shadow line below.
    rect(90, 58, 10, 7, acGray)
    rect(91, 59, 8, 2, acLite)
    rect(90, 65, 10, 1, RGB(r: 0x2E, g: 0x2E, b: 0x2E))

    // Cracks: 1px diagonals near a corner (max 3 per face).
    for i in 0..<3 { put(6 + i, 66 - i, wallSh) }
    if h % 2 == 1 { for i in 0..<3 { put(W - 8 - i, 40 + i, wallSh) } }

    // Silhouette outline.
    rect(0, 0, W, 1, outline); rect(0, 0, 1, H, outline)
    rect(W - 1, 0, 1, H, outline); rect(0, H - 1, W, 1, outline)

    let provider = CGDataProvider(data: Data(px) as CFData)!
    return CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32,
                   bytesPerRow: W * 4, space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false,
                   intent: .defaultIntent)!
}

// MARK: - Main

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "generated-sprites"
let previewPath = args.count > 2 ? args[2] : outDir + "/shelly-preview.png"

struct CharacterSet {
    let name: String
    let south: [Grid]
    let north: [Grid]
    let east: [Grid]
    let idle: [Grid]
    let battle: [(String, Grid)]
}

func writeSheet(rows: [[Grid]], scale: Int, to path: String) {
    let gap = 12
    let sheetW = rows.map { r in r.reduce(0) { $0 + $1[0].count + gap } }.max()! + gap
    let sheetH = rows.reduce(gap) { $0 + $1.map(\.count).max()! + gap }
    var sheet = emptyGrid(w: sheetW, h: sheetH)
    var oy = gap
    for row in rows {
        var ox = gap
        let rowH = row.map(\.count).max()!
        for g in row {
            for y in 0..<g.count { for x in 0..<g[0].count where g[y][x] != "." {
                sheet[oy + rowH - g.count + y][ox + x] = g[y][x]
            } }
            ox += g[0].count + gap
        }
        oy += rowH + gap
    }
    writePNG(render(sheet, scale: scale), to: path)
}

func emit(_ c: CharacterSet) {
    let west = c.east.map(mirrored)
    for (dir, frames) in [("south", c.south), ("north", c.north),
                          ("east", c.east), ("west", west)] {
        for (i, g) in frames.enumerated() {
            writePNG(render(g), to: "\(outDir)/\(c.name)-walk-\(dir)-f\(i + 1)-\(SW)x\(SH).png")
        }
    }
    for (i, g) in c.idle.enumerated() {
        writePNG(render(g), to: "\(outDir)/\(c.name)-idle-south-f\(i + 1)-\(SW)x\(SH).png")
    }
    for (name, g) in c.battle {
        writePNG(render(g), to: "\(outDir)/\(c.name)-battle-\(name)-\(BW)x\(BH).png")
    }
    let previewDir = (previewPath as NSString).deletingLastPathComponent
    writeSheet(rows: [c.south + c.idle, c.north, c.east, west, c.battle.map(\.1)],
               scale: 4, to: "\(previewDir)/\(c.name)-full-set.png")
}

let characters: [CharacterSet] = [
    CharacterSet(
        name: "shelly",
        south: shellyFrames.map(shellyFrame),
        north: shellyFrames.map(shellyNorthFrame),
        east: shellyFrames.map(shellyEastFrame),
        idle: [shellyIdleFrame(blink: false), shellyIdleFrame(blink: true)],
        battle: [("idle-f1", shellyBattleIdle(frame: 0)),
                 ("idle-f2", shellyBattleIdle(frame: 1)),
                 ("attack", shellyBattleAttack()),
                 ("hurt", shellyBattleHurt())]),
    CharacterSet(
        name: "spike",
        south: (0..<4).map(spikeFrame),
        north: (0..<4).map(spikeNorthFrame),
        east: (0..<4).map(spikeEastFrame),
        idle: [spikeFrame(0), spikeFrame(2)],
        battle: [("idle-f1", spikeBattleIdle(frame: 0)),
                 ("idle-f2", spikeBattleIdle(frame: 1)),
                 ("attack", spikeBattleAttack()),
                 ("hurt", spikeBattleHurt())]),
    CharacterSet(
        name: "hazel",
        south: (0..<4).map(hazelFrame),
        north: (0..<4).map(hazelNorthFrame),
        east: (0..<4).map(hazelEastFrame),
        idle: [hazelFrame(0), hazelFrame(3)],
        battle: [("idle-f1", hazelBattleIdle(frame: 0)),
                 ("idle-f2", hazelBattleIdle(frame: 1)),
                 ("attack", hazelBattleAttack()),
                 ("hurt", hazelBattleHurt())]),
    CharacterSet(
        name: "pip",
        south: (0..<4).map(pipFrame),
        north: (0..<4).map(pipNorthFrame),
        east: (0..<4).map(pipEastFrame),
        idle: [pipFrame(1), pipFrame(3)],
        battle: [("idle-f1", pipBattleIdle(frame: 0)),
                 ("idle-f2", pipBattleIdle(frame: 1)),
                 ("attack", pipBattleAttack()),
                 ("hurt", pipBattleHurt())]),
]
for c in characters { emit(c) }
print("wrote full sets for \(characters.map(\.name).joined(separator: ", "))")

// Houses: one PNG per MAP_SPEC §3.14 roof variant.
for variant in roofColors.keys.sorted() {
    writePNG(houseImage(variant: variant), to: "\(outDir)/house-\(variant)-112x80.png")
}

// House preview: all variants in a row, 4x.
do {
    let W = 112, H = 80, gap = 8
    let names = roofColors.keys.sorted()
    let ctx = CGContext(data: nil, width: (W + gap) * names.count, height: H,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    for (i, v) in names.enumerated() {
        ctx.draw(houseImage(variant: v), in: CGRect(x: i * (W + gap), y: 0, width: W, height: H))
    }
    let img = ctx.makeImage()!
    let big = CGContext(data: nil, width: img.width * 4, height: img.height * 4,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    big.interpolationQuality = .none
    big.draw(img, in: CGRect(x: 0, y: 0, width: img.width * 4, height: img.height * 4))
    writePNG(big.makeImage()!, to: "\(outDir)/houses-preview.png")
}
print("wrote \(shellyFrames.count) shelly frames + \(roofColors.count) houses → \(outDir)")
