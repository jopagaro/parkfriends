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

var palette: [Character: (UInt8, UInt8, UInt8, UInt8)] = [
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
    "J": (0xE8, 0xA8, 0x55, 255), // hamster golden coat
    "j": (0xC0, 0x80, 0x38, 255), // golden shadow/outline
    // world tiles
    "w": (0x4A, 0x8E, 0xC4, 255), // water
    "v": (0x2E, 0x6A, 0xA0, 255), // water deep
    "u": (0x76, 0xB4, 0xD8, 255), // water light ripple
    "1": (0xBE, 0xBE, 0xBE, 255), // sidewalk
    "0": (0xA0, 0xA0, 0xA0, 255), // sidewalk shadow
    "9": (0xD0, 0xD0, 0xD0, 255), // sidewalk light
    "R": (0x2E, 0x2E, 0x32, 255), // asphalt
    "x": (0x3A, 0x3A, 0x3E, 255), // asphalt light
    "5": (0x6A, 0x6A, 0x6A, 255), // statue mid gray
    // parametric NPC slots (set per-role before rendering)
    "a": (0xE8, 0xC0, 0x98, 255), // skin
    "d": (0xC8, 0x9A, 0x6E, 255), // skin shadow
    "e": (0x3A, 0x5F, 0xA0, 255), // shirt
    "f": (0x2A, 0x46, 0x78, 255), // shirt dark
    "i": (0x5A, 0x42, 0x28, 255), // pants
    "l": (0x42, 0x30, 0x1C, 255), // pants dark
    "n": (0xC4, 0x95, 0x5A, 255), // hat
    "o": (0xA0, 0x78, 0x40, 255), // hat dark
    "p": (0x5A, 0x3A, 0x18, 255), // hair
    "y": (0xD4, 0xB0, 0x30, 255), // accent (badge/vest/apron)
    "z": (0x3C, 0x28, 0x10, 255), // shoes
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

// MARK: - PIP (hamster, chaos) — reference body shape: sitting pear
// Narrow crown → cheeks flare mid-face → haunches spread at a flat sitting
// base. One continuous cream panel from chin to base. Golden coat approved.

/// Pear-shaped sitting hamster mass with flat base, form shadow, hip bulges.
func pipMass(_ g: inout Grid, cx: Double, topY: Double, scale: Double) {
    let crownR = 16.5 * scale
    fillEllipse(&g, cx: cx, cy: topY + 14 * scale, rx: crownR, ry: 14 * scale, "J")
    // shoulder blend so the crown→body junction has no step notch
    fillEllipse(&g, cx: cx, cy: topY + 21 * scale, rx: 19.5 * scale, ry: 14 * scale, "J")
    fillEllipse(&g, cx: cx, cy: topY + 28 * scale, rx: 22.5 * scale, ry: 16 * scale, "J")
    fillEllipse(&g, cx: cx, cy: topY + 38 * scale, rx: 24 * scale, ry: 13 * scale, "J")
    // flat sitting base
    let baseY = Int(topY + 48 * scale)
    for y in 0..<g.count where y > baseY { for x in 0..<g[0].count where g[y][x] == "J" { g[y][x] = "." } }
}

func pipBodyPart(lookLeft: Bool = false, cheekBulge: Int = 0, hurt: Bool = false) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    // ears on the crown (left higher)
    fillEllipse(&g, cx: 21, cy: 27, rx: 6.5, ry: 7.5, "J")
    fillEllipse(&g, cx: 43, cy: 29, rx: 6.5, ry: 7.5, "J")
    // sitting pear mass (top of crown at y≈30, base flat at y≈78)
    pipMass(&g, cx: 32, topY: 30, scale: 1.0)
    // continuous cream front: chin → belly → base
    fillEllipse(&g, cx: 32, cy: 52, rx: 12, ry: 8, "K")
    fillEllipse(&g, cx: 32, cy: 65, rx: 13, ry: 14, "K")
    for y in 76...77 { for x in 21...43 where g[y][x] == "J" || g[y][x] == "j" { g[y][x] = "K" } }
    outlineShape(&g, body: ["J", "j", "K"], outline: "j")
    // inner ears
    fillEllipse(&g, cx: 21, cy: 28, rx: 3, ry: 4, "P")
    fillEllipse(&g, cx: 43, cy: 30, rx: 3, ry: 4, "P")
    // crown tuft
    drawSpike(&g, baseX: 30, baseY: 31, angle: -1.75, len: 4, baseR: 1.4, body: "J", tip: "J")
    drawSpike(&g, baseX: 34, baseY: 31, angle: -1.35, len: 4.5, baseR: 1.4, body: "J", tip: "J")
    // close-set worried eyes
    let shift = lookLeft ? -2 : 0
    for (ex, ey) in [(24, 41), (34, 41)] {
        if hurt {
            for i in 0..<6 { g[ey + i][ex + i] = "E"; g[ey + i][ex + 5 - i] = "E" }
        } else {
            for dy in 0..<6 { for dx in 0..<5 { g[ey + dy][ex + dx] = "E" } }
            g[ey + 1][ex + 3 + shift] = "W"; g[ey + 1][ex + 2 + shift] = "W"
        }
    }
    // worry brows
    g[38][23] = "j"; g[37][24] = "j"; g[37][38] = "j"; g[38][39] = "j"
    // pink nose, tiny mouth, whiskers
    fillEllipse(&g, cx: 32, cy: 50, rx: 3, ry: 2.2, "O")
    g[54][30] = "j"; g[55][32] = "j"; g[54][34] = "j"
    for (wx, wy) in [(22, 51), (21, 54), (42, 51), (43, 54)] { g[wy][wx] = "j" }
    // nub arms on the cream chest
    for armX in [23.0, 41.0] {
        fillEllipse(&g, cx: armX, cy: 62, rx: 4.5, ry: 5.5, "j")
        fillEllipse(&g, cx: armX, cy: 62, rx: 3.0, ry: 4.0, "J")
    }
    // tiny feet poking from the base
    for fx in [25.0, 39.0] {
        fillEllipse(&g, cx: fx, cy: 78.5, rx: 3.4, ry: 2.2, "K")
        g[80][Int(fx)] = "j"
    }
    return g
}

func pipFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 82, rx: 24, ry: 3.6, "S")
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
    fillEllipse(&sh, cx: 32, cy: 82, rx: 24, ry: 3.6, "S")
    composite(&g, sh, dx: 0, dy: 0)
    var body = emptyGrid(w: SW, h: SH)
    fillEllipse(&body, cx: 21, cy: 27, rx: 6.5, ry: 7.5, "J")
    fillEllipse(&body, cx: 43, cy: 29, rx: 6.5, ry: 7.5, "J")
    pipMass(&body, cx: 32, topY: 30, scale: 1.0)
    outlineShape(&body, body: ["J", "j"], outline: "j")
    drawSpike(&body, baseX: 30, baseY: 31, angle: -1.75, len: 4, baseR: 1.4, body: "J", tip: "J")
    drawSpike(&body, baseX: 34, baseY: 31, angle: -1.35, len: 4.5, baseR: 1.4, body: "J", tip: "J")
    // cream rump patch + tail nub
    fillEllipse(&body, cx: 32, cy: 70, rx: 9, ry: 6, "K")
    fillEllipse(&body, cx: 32, cy: 74, rx: 2.5, ry: 2, "j")
    let dx = f == 0 ? -1 : (f == 2 ? 1 : 0)
    composite(&g, body, dx: dx, dy: 0)
    return g
}

func pipEastFrame(_ f: Int) -> Grid {
    var g = emptyGrid(w: SW, h: SH)
    var sh = emptyGrid(w: SW, h: SH)
    fillEllipse(&sh, cx: 32, cy: 82, rx: 24, ry: 3.6, "S")
    composite(&g, sh, dx: 0, dy: 0)
    var body = emptyGrid(w: SW, h: SH)
    fillEllipse(&body, cx: 28, cy: 27, rx: 6, ry: 7, "J")      // ear
    // profile pear: crown forward, haunch back, flat base
    fillEllipse(&body, cx: 36, cy: 44, rx: 17, ry: 14, "J")
    fillEllipse(&body, cx: 30, cy: 60, rx: 22, ry: 16, "J")
    fillEllipse(&body, cx: 26, cy: 68, rx: 21, ry: 12, "J")
    for y in 0..<SH where y > 78 { for x in 0..<SW where body[y][x] == "J" { body[y][x] = "." } }
    for y in 0..<SH { for x in 0..<SW where body[y][x] == "J" {
        let nx = (Double(x) + 0.5 - 31) / 23.0
        let ny = (Double(y) + 0.5 - 57) / 25.0
        let d = nx * nx + ny * ny
        if d <= 1.02, (-nx * 0.6 - ny * 0.8) * d.squareRoot() < -0.56 { body[y][x] = "j" }
    } }
    fillEllipse(&body, cx: 50, cy: 54, rx: 6.5, ry: 7, "J")     // cheek
    fillEllipse(&body, cx: 49, cy: 49, rx: 7, ry: 6, "K")       // muzzle
    fillEllipse(&body, cx: 42, cy: 66, rx: 9, ry: 10, "K")      // belly front
    outlineShape(&body, body: ["J", "j", "K"], outline: "j")
    fillEllipse(&body, cx: 28, cy: 28, rx: 2.6, ry: 3.6, "P")
    drawSpike(&body, baseX: 31, baseY: 31, angle: -1.6, len: 4, baseR: 1.3, body: "J", tip: "J")
    for dy in 0..<6 { for dx in 0..<5 { body[40 + dy][40 + dx] = "E" } }
    body[41][43] = "W"
    fillEllipse(&body, cx: 54, cy: 47, rx: 2.8, ry: 2.2, "O")
    body[51][50] = "j"; body[52][52] = "j"
    fillEllipse(&body, cx: 45, cy: 61, rx: 4.5, ry: 5.5, "j")
    fillEllipse(&body, cx: 45, cy: 61, rx: 3.0, ry: 4.0, "J")
    fillEllipse(&body, cx: 40, cy: 77, rx: 3.6, ry: 2.2, "K")   // front foot
    let dx = f == 0 ? 1 : (f == 2 ? -1 : 0)
    composite(&g, body, dx: dx, dy: f == 1 ? 1 : 0)
    return g
}

func pipBattleIdle(frame: Int) -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    let puff = frame == 1 ? 2 : 0
    var body = emptyGrid(w: BW, h: BH)
    fillEllipse(&body, cx: 42, cy: 32, rx: 12, ry: 14, "J")
    fillEllipse(&body, cx: 86, cy: 36, rx: 12, ry: 14, "J")
    pipMass(&body, cx: 64, topY: 24, scale: 2.0)
    _ = puff
    fillEllipse(&body, cx: 64, cy: 68, rx: 23, ry: 15, "K")
    fillEllipse(&body, cx: 64, cy: 94, rx: 25, ry: 26, "K")
    for y in 116...119 { for x in 42...86 where body[y][x] == "J" || body[y][x] == "j" { body[y][x] = "K" } }
    outlineShape(&body, body: ["J", "j", "K"], outline: "j")
    fillEllipse(&body, cx: 42, cy: 34, rx: 5.5, ry: 7.5, "P")
    fillEllipse(&body, cx: 86, cy: 38, rx: 5.5, ry: 7.5, "P")
    drawSpike(&body, baseX: 60, baseY: 26, angle: -1.75, len: 8, baseR: 2.6, body: "J", tip: "J")
    drawSpike(&body, baseX: 68, baseY: 26, angle: -1.35, len: 9, baseR: 2.6, body: "J", tip: "J")
    for (ex, ey) in [(48, 46), (68, 46)] {
        for dy in 0..<9 { for dx in 0..<9 { body[ey + dy][ex + dx] = "E" } }
        for dy in 1..<4 { for dx in 4..<8 { body[ey + dy][ex + dx] = "W" } }
    }
    body[41][46] = "j"; body[40][48] = "j"; body[40][76] = "j"; body[41][78] = "j"
    fillEllipse(&body, cx: 63, cy: 62, rx: 6, ry: 4.4, "O")
    body[72][58] = "j"; body[73][62] = "j"; body[72][66] = "j"
    for (wx, wy) in [(42, 64), (40, 69), (86, 64), (88, 69)] { body[wy][wx] = "j" }
    for armX in [46.0, 82.0] {
        fillEllipse(&body, cx: armX, cy: 86, rx: 8, ry: 10, "j")
        fillEllipse(&body, cx: armX, cy: 86, rx: 5.5, ry: 7.5, "J")
    }
    for fx in [50.0, 78.0] {
        fillEllipse(&body, cx: fx, cy: 118, rx: 6, ry: 4, "K")
    }
    composite(&g, body, dx: 0, dy: 0)
    return g
}

/// Chaos Toss: something gold and inexplicable is airborne.
func pipBattleAttack() -> Grid {
    var g = pipBattleIdle(frame: 0)
    var arm = emptyGrid(w: BW, h: BH)
    fillEllipse(&arm, cx: 26, cy: 54, rx: 7, ry: 13, "J")
    outlineShape(&arm, body: ["J"], outline: "j")
    composite(&g, arm, dx: 0, dy: 0)
    var star = emptyGrid(w: BW, h: BH)
    for i in 0..<8 {
        let a = Double(i) * (.pi / 4)
        let len: Double = i % 2 == 0 ? 11 : 5
        drawSpike(&star, baseX: 18, baseY: 20, angle: a, len: len,
                  baseR: 2.4, body: "Q", tip: "Q")
    }
    composite(&g, star, dx: 0, dy: 0)
    return g
}

func pipBattleHurt() -> Grid {
    var g = emptyGrid(w: BW, h: BH)
    var body = emptyGrid(w: BW, h: BH)
    fillEllipse(&body, cx: 42, cy: 34, rx: 12, ry: 14, "J")
    fillEllipse(&body, cx: 86, cy: 38, rx: 12, ry: 14, "J")
    pipMass(&body, cx: 64, topY: 26, scale: 2.0)
    fillEllipse(&body, cx: 64, cy: 70, rx: 23, ry: 15, "K")
    fillEllipse(&body, cx: 64, cy: 96, rx: 24, ry: 24, "K")
    outlineShape(&body, body: ["J", "j", "K"], outline: "j")
    for (ex, ey) in [(46, 48), (66, 48)] {
        for i in 0..<9 { body[ey + i][ex + i] = "E"; body[ey + i][ex + 8 - i] = "E" }
    }
    fillEllipse(&body, cx: 62, cy: 64, rx: 6, ry: 4.4, "O")
    for x in 54...72 { body[80][x] = "j" }
    composite(&g, body, dx: -3, dy: 5)
    return g
}

// MARK: - HUMAN NPCS (parametric rig — one body, role hats/clothes)
// Bible 3.4: ~clay figures, big head, dot eyes, NO mouths. 64x96 canvas,
// 4 directions x 2 walk frames each, built from a single rig.

struct NPCRole {
    let name: String
    let skin: (UInt8, UInt8, UInt8)
    let shirt: (UInt8, UInt8, UInt8)
    let shirtDark: (UInt8, UInt8, UInt8)
    let pants: (UInt8, UInt8, UInt8)
    let hair: (UInt8, UInt8, UInt8)
    let hat: (UInt8, UInt8, UInt8)?
    let hatDark: (UInt8, UInt8, UInt8)
    let accent: (UInt8, UInt8, UInt8)
    let hatStyle: String                // "brim", "cap", "hard", "band", "straw", "none"
    let vest: Bool
    let apron: Bool
    let scale: Double
}

let npcRoles: [NPCRole] = [
    NPCRole(name: "ranger", skin: (0xE0,0xB0,0x88), shirt: (0x3D,0x72,0x20), shirtDark: (0x2A,0x50,0x18),
            pants: (0x5A,0x42,0x28), hair: (0x4A,0x30,0x18), hat: (0xC4,0x95,0x5A), hatDark: (0xA0,0x78,0x40),
            accent: (0xD4,0xB0,0x30), hatStyle: "brim", vest: false, apron: false, scale: 1.0),
    NPCRole(name: "jogger", skin: (0xE8,0xC0,0x98), shirt: (0x3A,0x5F,0xA0), shirtDark: (0x2A,0x46,0x78),
            pants: (0x48,0x48,0x48), hair: (0x2E,0x22,0x16), hat: (0xC8,0x30,0x30), hatDark: (0x9A,0x24,0x24),
            accent: (0xF5,0xF0,0xDC), hatStyle: "band", vest: false, apron: false, scale: 1.0),
    NPCRole(name: "child", skin: (0xF0,0xCC,0xA6), shirt: (0xC8,0x30,0x30), shirtDark: (0x9A,0x24,0x24),
            pants: (0x3A,0x5F,0xA0), hair: (0x6E,0x4C,0x2A), hat: (0x3A,0x5F,0xA0), hatDark: (0x2A,0x46,0x78),
            accent: (0xE8,0xC0,0x40), hatStyle: "cap", vest: false, apron: false, scale: 0.8),
    NPCRole(name: "birdwatcher", skin: (0xD8,0xA8,0x80), shirt: (0xC4,0xA0,0x6A), shirtDark: (0xA0,0x80,0x4E),
            pants: (0x5A,0x5A,0x40), hair: (0x8A,0x8A,0x8A), hat: (0x3D,0x72,0x20), hatDark: (0x2A,0x50,0x18),
            accent: (0x1E,0x1E,0x22), hatStyle: "cap", vest: false, apron: false, scale: 1.0),
    NPCRole(name: "dogwalker", skin: (0xE8,0xC0,0x98), shirt: (0xE8,0xA8,0x55), shirtDark: (0xC0,0x80,0x38),
            pants: (0x3A,0x5F,0xA0), hair: (0x2E,0x22,0x16), hat: nil, hatDark: (0x2E,0x22,0x16),
            accent: (0xC8,0x30,0x30), hatStyle: "none", vest: false, apron: false, scale: 1.0),
    NPCRole(name: "gardener", skin: (0xD8,0xA8,0x80), shirt: (0x6E,0x8E,0x3A), shirtDark: (0x54,0x6E,0x2A),
            pants: (0x6E,0x4C,0x2A), hair: (0xB8,0xB8,0xB8), hat: (0xE0,0xC8,0xA0), hatDark: (0xC4,0xA0,0x7A),
            accent: (0x8B,0x5C,0x28), hatStyle: "straw", vest: false, apron: true, scale: 1.0),
    NPCRole(name: "worker", skin: (0xE0,0xB0,0x88), shirt: (0x6A,0x6A,0x6A), shirtDark: (0x50,0x50,0x50),
            pants: (0x48,0x48,0x60), hair: (0x2E,0x22,0x16), hat: (0xE8,0xC0,0x40), hatDark: (0xC4,0x9A,0x20),
            accent: (0xE8,0xC0,0x40), hatStyle: "hard", vest: true, apron: false, scale: 1.0),
    NPCRole(name: "shopkeeper", skin: (0xE8,0xC0,0x98), shirt: (0xF0,0xEC,0xE0), shirtDark: (0xC8,0xC0,0xB0),
            pants: (0x2E,0x2E,0x32), hair: (0x4A,0x30,0x18), hat: nil, hatDark: (0x4A,0x30,0x18),
            accent: (0xC8,0x30,0x30), hatStyle: "none", vest: false, apron: true, scale: 1.0),
]

func applyRolePalette(_ r: NPCRole) {
    palette["a"] = (r.skin.0, r.skin.1, r.skin.2, 255)
    palette["d"] = (UInt8(Int(r.skin.0) * 3 / 4), UInt8(Int(r.skin.1) * 3 / 4), UInt8(Int(r.skin.2) * 3 / 4), 255)
    palette["e"] = (r.shirt.0, r.shirt.1, r.shirt.2, 255)
    palette["f"] = (r.shirtDark.0, r.shirtDark.1, r.shirtDark.2, 255)
    palette["i"] = (r.pants.0, r.pants.1, r.pants.2, 255)
    palette["l"] = (UInt8(Int(r.pants.0) * 3 / 4), UInt8(Int(r.pants.1) * 3 / 4), UInt8(Int(r.pants.2) * 3 / 4), 255)
    palette["p"] = (r.hair.0, r.hair.1, r.hair.2, 255)
    if let h = r.hat { palette["n"] = (h.0, h.1, h.2, 255) }
    palette["o"] = (r.hatDark.0, r.hatDark.1, r.hatDark.2, 255)
    palette["y"] = (r.accent.0, r.accent.1, r.accent.2, 255)
}

/// One human frame. dir: 0=S 1=N 2=E. step: 0/1 walk alternation.
func humanFrame(_ r: NPCRole, dir: Int, step: Int) -> Grid {
    applyRolePalette(r)
    let sc = r.scale
    var g = emptyGrid(w: SW, h: SH)
    let cx = 32.0
    let headCY = 30.0 + (1.0 - sc) * 22
    let headR = 14.0 * sc
    let bodyTop = headCY + headR * 0.8
    let legTop = bodyTop + 22 * sc
    let footY = legTop + 14 * sc

    fillEllipse(&g, cx: cx, cy: footY + 5, rx: 15 * sc, ry: 3.4, "S")

    // legs
    var legs = emptyGrid(w: SW, h: SH)
    let lift = 3.0 * sc
    for (ix, off) in [(-1.0, step == 0 ? 0.0 : lift), (1.0, step == 0 ? lift : 0.0)] {
        let lx = cx + ix * 5.5 * sc
        for y in Int(legTop)..<Int(footY - off) {
            for x in Int(lx - 3.4 * sc)..<Int(lx + 3.4 * sc) { legs[y][x] = "i" }
        }
        fillEllipse(&legs, cx: lx + (dir == 2 ? ix * 1.5 : 0), cy: footY - off - 1,
                    rx: 4.2 * sc, ry: 2.6 * sc, "z")
    }
    outlineShape(&legs, body: ["i", "z"], outline: "l")
    composite(&g, legs, dx: 0, dy: 0)

    // body
    var body = emptyGrid(w: SW, h: SH)
    shadeEllipse(&body, cx: cx, cy: bodyTop + 12 * sc, rx: 12.5 * sc, ry: 14 * sc,
                 main: "e", hi: "e", lo: "f")
    if r.vest {
        for y in Int(bodyTop + 2 * sc)..<Int(bodyTop + 20 * sc) {
            for x in Int(cx - 9 * sc)..<Int(cx + 9 * sc) where body[y][x] != "." { body[y][x] = "y" }
        }
    }
    if r.apron {
        for y in Int(bodyTop + 6 * sc)..<Int(bodyTop + 24 * sc) {
            for x in Int(cx - 7 * sc)..<Int(cx + 7 * sc) where body[y][x] != "." { body[y][x] = "y" }
        }
    }
    let armDY = step == 0 ? 0.0 : 2.0 * sc
    if dir == 2 {
        fillEllipse(&body, cx: cx + 8 * sc, cy: bodyTop + 12 * sc + armDY, rx: 3.6 * sc, ry: 8 * sc, "e")
    } else {
        fillEllipse(&body, cx: cx - 14.5 * sc, cy: bodyTop + 12 * sc + armDY, rx: 3.6 * sc, ry: 8 * sc, "e")
        fillEllipse(&body, cx: cx + 14.5 * sc, cy: bodyTop + 12 * sc - armDY, rx: 3.6 * sc, ry: 8 * sc, "e")
        fillEllipse(&body, cx: cx - 14.5 * sc, cy: bodyTop + 19 * sc + armDY, rx: 2.6 * sc, ry: 2.6 * sc, "a")
        fillEllipse(&body, cx: cx + 14.5 * sc, cy: bodyTop + 19 * sc - armDY, rx: 2.6 * sc, ry: 2.6 * sc, "a")
    }
    outlineShape(&body, body: ["e", "f", "y", "a"], outline: "f")
    composite(&g, body, dx: 0, dy: 0)

    // head
    var head = emptyGrid(w: SW, h: SH)
    let hx = dir == 2 ? cx + 2 : cx
    shadeEllipse(&head, cx: hx, cy: headCY, rx: headR, ry: headR * 0.95,
                 main: "a", hi: "a", lo: "d", loThresh: -0.52)
    if dir == 2 {
        fillEllipse(&head, cx: hx + headR * 0.9, cy: headCY + 3, rx: 2.6 * sc, ry: 2.2 * sc, "a")
    }
    // hair base (visible for hatless + north)
    if r.hatStyle == "none" || dir == 1 {
        for y in 0..<SH { for x in 0..<SW where head[y][x] != "." {
            if Double(y) < headCY - headR * (dir == 1 ? -0.1 : 0.3) { head[y][x] = "p" }
        } }
    }
    switch r.hatStyle {
    case "brim":
        for x in max(0, Int(hx - headR - 5))..<min(SW, Int(hx + headR + 5)) {
            for y in Int(headCY - headR * 0.55)..<Int(headCY - headR * 0.55) + 3 { head[y][x] = "n" }
        }
        fillEllipse(&head, cx: hx, cy: headCY - headR * 0.78, rx: headR * 0.62, ry: headR * 0.5, "n")
        for x in max(0, Int(hx - headR * 0.6))..<min(SW, Int(hx + headR * 0.6)) {
            head[Int(headCY - headR * 0.6)][x] = "o"
        }
    case "cap":
        for y in 0..<SH { for x in 0..<SW where head[y][x] != "." {
            if Double(y) < headCY - headR * 0.25 { head[y][x] = "n" }
        } }
        if dir != 1 {
            let bx0 = dir == 2 ? Int(hx) : Int(hx - headR * 0.9)
            for x in bx0..<min(SW, Int(hx + headR * 1.2)) {
                for y in Int(headCY - headR * 0.3)..<Int(headCY - headR * 0.3) + 2 { head[y][x] = "o" }
            }
        }
    case "hard":
        fillEllipse(&head, cx: hx, cy: headCY - headR * 0.55, rx: headR * 0.95, ry: headR * 0.6, "n")
        for x in max(0, Int(hx - headR))..<min(SW, Int(hx + headR)) {
            head[Int(headCY - headR * 0.18)][x] = "o"
        }
    case "band":
        for y in 0..<SH { for x in 0..<SW where head[y][x] != "." {
            if Double(y) < headCY - headR * 0.3 { head[y][x] = "p" }
        } }
        for x in max(0, Int(hx - headR))..<min(SW, Int(hx + headR)) {
            let yy = Int(headCY - headR * 0.32)
            if head[yy][x] != "." { head[yy][x] = "n"; head[yy + 1][x] = "n" }
        }
    case "straw":
        for x in max(0, Int(hx - headR - 6))..<min(SW, Int(hx + headR + 6)) {
            for y in Int(headCY - headR * 0.5)..<Int(headCY - headR * 0.5) + 3 { head[y][x] = "n" }
        }
        fillEllipse(&head, cx: hx, cy: headCY - headR * 0.75, rx: headR * 0.58, ry: headR * 0.45, "n")
    default:
        if dir != 1 {
            for y in 0..<SH { for x in 0..<SW where head[y][x] != "." {
                if Double(y) < headCY - headR * 0.35 { head[y][x] = "p" }
            } }
        }
    }
    outlineShape(&head, body: ["a", "d", "p", "n", "o"], outline: "d")
    if dir == 0 {
        for (ex, ey) in [(Int(hx - 5 * sc), Int(headCY + 1)), (Int(hx + 3 * sc), Int(headCY + 1))] {
            for dy in 0..<3 { for dx in 0..<2 { head[ey + dy][ex + dx] = "E" } }
        }
    } else if dir == 2 {
        for dy in 0..<3 { for dx in 0..<2 {
            head[Int(headCY) + dy][Int(hx + headR * 0.45) + dx] = "E"
        } }
    }
    if r.name == "birdwatcher", dir == 0 {
        fillEllipse(&head, cx: cx - 3, cy: bodyTop + 4, rx: 2.4, ry: 2.0, "E")
        fillEllipse(&head, cx: cx + 3, cy: bodyTop + 4, rx: 2.4, ry: 2.0, "E")
    }
    if r.name == "ranger", dir == 0 {
        for dy in 0..<2 { for dx in 0..<2 { head[Int(bodyTop + 6) + dy][Int(cx - 7) + dx] = "y" } }
    }
    composite(&g, head, dx: 0, dy: 0)
    return g
}

// MARK: - WORLD TILES (32px base, bible Part 2 palette)
// Everything the ground painter consumes: fill tiles, 4x4 blob autotile
// sheets (same layout ScenePainter.autotile already expects), road and
// sidewalk families, hedge, and tree sprites. One palette with the cast.

let TS = 32

/// Deterministic hash for texture speckle (stable across runs).
func speck(_ x: Int, _ y: Int, _ salt: Int) -> Int {
    var h = UInt64(x &* 374761393 &+ y &* 668265263 &+ salt &* 2246822519)
    h = (h ^ (h >> 13)) &* 1274126177
    return Int(h % 1000)
}

func tileGrass(variant: Int) -> Grid {
    var g = emptyGrid(w: TS, h: TS)
    for y in 0..<TS { for x in 0..<TS {
        let r = speck(x + variant * 97, y, 11)
        g[y][x] = r < 13 ? "H" : (r < 34 ? "g" : "G")
    } }
    // occasional 2px blade clusters
    if variant % 3 == 1 {
        for (bx, by) in [(6, 8), (22, 18), (13, 26)] {
            g[by][bx] = "g"; g[by - 1][bx] = "g"; g[by - 1][bx + 1] = "H"
        }
    }
    return g
}

func tileGrassDark(variant: Int) -> Grid {
    var g = emptyGrid(w: TS, h: TS)
    for y in 0..<TS { for x in 0..<TS {
        let r = speck(x + variant * 131, y, 23)
        g[y][x] = r < 40 ? "G" : "g"
    } }
    return g
}

func tileDirt(variant: Int) -> Grid {
    var g = emptyGrid(w: TS, h: TS)
    for y in 0..<TS { for x in 0..<TS {
        let r = speck(x + variant * 61, y, 37)
        g[y][x] = r < 34 ? "t" : (r < 44 ? "h" : "T")
    } }
    // few pebbles
    for (px, py) in [(8, 6), (20, 14), (13, 24), (26, 27)] where speck(px, py, variant) % 3 == 0 {
        g[py][px] = "r"; g[py][px + 1] = "r"; g[py + 1][px] = "t"
    }
    return g
}

func tileStone(variant: Int) -> Grid {
    var g = emptyGrid(w: TS, h: TS)
    for y in 0..<TS { for x in 0..<TS {
        let r = speck(x + variant * 43, y, 53)
        g[y][x] = r < 26 ? "0" : (r < 40 ? "9" : "1")
    } }
    // slab joints every 16px
    for i in 0..<TS { g[15][i] = "0"; g[i][15] = "0" }
    if variant % 3 == 2 {   // crack
        for i in 0..<6 { g[6 + i][20 + (i / 2)] = "0" }
    }
    return g
}

func tileSidewalk(variant: Int) -> Grid { tileStone(variant: variant) }

func tileRoad(variant: Int, dash: Bool = false) -> Grid {
    var g = emptyGrid(w: TS, h: TS)
    for y in 0..<TS { for x in 0..<TS {
        let r = speck(x + variant * 29, y, 71)
        g[y][x] = r < 60 ? "x" : "R"
    } }
    if dash {
        for x in 4..<14 { for y in 14...17 { g[y][x] = "W" } }
        for x in 22..<32 { for y in 14...17 { g[y][x] = "W" } }
    }
    return g
}

func tileWater(variant: Int) -> Grid {
    var g = emptyGrid(w: TS, h: TS)
    for y in 0..<TS { for x in 0..<TS {
        let r = speck(x + variant * 89, y, 97)
        g[y][x] = r < 30 ? "v" : "w"
    } }
    for (rx, ry) in [(7, 9), (21, 22), (14, 27)] {
        if speck(rx, ry, variant) % 2 == 0 {
            for i in 0..<5 { g[ry][rx + i] = "u" }
        }
    }
    return g
}

func tileHedgeLeaf(variant: Int) -> Grid {
    var g = emptyGrid(w: TS, h: TS)
    for y in 0..<TS { for x in 0..<TS {
        let r = speck(x + variant * 17, y, 113)
        g[y][x] = r < 200 ? "g" : (r < 620 ? "G" : "H")
    } }
    return g
}

/// One cell of a blob autotile sheet. `n/s/e/w` mark OUTSIDE edges.
/// The interior texture comes from `fill`; outside edges get a rounded
/// rim in `rim` plus an optional 2px fringe band in `fringe`.
/// Grows `ch` into transparent pixels adjacent to any body pixel.
func dilate(_ g: inout Grid, with ch: Character) {
    let h = g.count, w = g[0].count
    var adds: [(Int, Int)] = []
    for y in 0..<h { for x in 0..<w where g[y][x] == "." {
        let n = [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]
        if n.contains(where: { $0.0 >= 0 && $0.0 < w && $0.1 >= 0 && $0.1 < h && g[$0.1][$0.0] != "." }) {
            adds.append((x, y))
        }
    } }
    for (x, y) in adds { g[y][x] = ch }
}

func blobCell(fill: Grid, n: Bool, s: Bool, e: Bool, w: Bool,
              rim: Character, fringe: Character?) -> Grid {
    var g = emptyGrid(w: TS, h: TS)
    let radius = 9.0
    // with a fringe, inset the core shape so the fringe + rim can grow back
    // out to the cell bounds without being clipped
    let inset: Double = fringe != nil ? 3 : 0
    func inside(_ x: Int, _ y: Int) -> Bool {
        let fx = Double(x) + 0.5, fy = Double(y) + 0.5
        if n, fy < inset { return false }
        if s, fy > Double(TS) - inset { return false }
        if w, fx < inset { return false }
        if e, fx > Double(TS) - inset { return false }
        for (cn, cs, ce, cw, cxr, cyr) in [
            (n, false, false, w, radius, radius),
            (n, false, e, false, Double(TS) - radius, radius),
            (false, s, false, w, radius, Double(TS) - radius),
            (false, s, e, false, Double(TS) - radius, Double(TS) - radius),
        ] {
            if cn || cs, ce || cw {
                let inCornerBox = (cw ? fx < cxr : fx > cxr) && ((cn) ? fy < cyr : fy > cyr)
                if inCornerBox {
                    let dx = fx - cxr, dy = fy - cyr
                    if dx * dx + dy * dy > (radius - inset) * (radius - inset) { return false }
                }
            }
        }
        return true
    }
    for y in 0..<TS { for x in 0..<TS where inside(x, y) { g[y][x] = fill[y][x] } }
    if fringe != nil {
        outlineShape(&g, body: Set(palette.keys).subtracting(["."]), outline: rim)
        if let f = fringe { dilate(&g, with: f); dilate(&g, with: f) }
        dilate(&g, with: rim)
    } else {
        outlineShape(&g, body: Set(palette.keys).subtracting(["."]), outline: rim)
    }
    return g
}

/// Full 4x4 blob sheet in the painter's expected layout:
/// row0 = horizontal capsule (L,M,R) + single blob at (3,0)
/// col3 rows1-3 = vertical capsule; cols0-2 rows1-3 = 3x3 blob.
func blobSheet(fillVariant: (Int) -> Grid, rim: Character, fringe: Character?) -> Grid {
    var sheet = emptyGrid(w: TS * 4, h: TS * 4)
    func put(_ cx: Int, _ cy: Int, n: Bool, s: Bool, e: Bool, w: Bool) {
        let cell = blobCell(fill: fillVariant(cx + cy * 4), n: n, s: s, e: e, w: w,
                            rim: rim, fringe: fringe)
        for y in 0..<TS { for x in 0..<TS where cell[y][x] != "." {
            sheet[cy * TS + y][cx * TS + x] = cell[y][x]
        } }
    }
    put(0, 0, n: true, s: true, e: false, w: true)    // H capsule L
    put(1, 0, n: true, s: true, e: false, w: false)   // H capsule M
    put(2, 0, n: true, s: true, e: true, w: false)    // H capsule R
    put(3, 0, n: true, s: true, e: true, w: true)     // single
    put(0, 1, n: true, s: false, e: false, w: true)   // blob TL
    put(1, 1, n: true, s: false, e: false, w: false)  // T
    put(2, 1, n: true, s: false, e: true, w: false)   // TR
    put(0, 2, n: false, s: false, e: false, w: true)  // L
    put(1, 2, n: false, s: false, e: false, w: false) // C
    put(2, 2, n: false, s: false, e: true, w: false)  // R
    put(0, 3, n: false, s: true, e: false, w: true)   // BL
    put(1, 3, n: false, s: true, e: false, w: false)  // B
    put(2, 3, n: false, s: true, e: true, w: false)   // BR
    put(3, 1, n: true, s: false, e: true, w: true)    // V capsule T
    put(3, 2, n: false, s: false, e: true, w: true)   // V capsule M
    put(3, 3, n: false, s: true, e: true, w: true)    // V capsule B
    return sheet
}

// MARK: - Trees (form-shaded, bible greens)

func treeSprite(w: Int, h: Int, canopyR: Double, conifer: Bool = false) -> Grid {
    var g = emptyGrid(w: w, h: h)
    let cx = Double(w) / 2
    // shadow
    fillEllipse(&g, cx: cx, cy: Double(h) - 5, rx: canopyR * 0.85, ry: 4.5, "S")
    // trunk
    let trunkW = max(6.0, canopyR * 0.28)
    var trunk = emptyGrid(w: w, h: h)
    for y in Int(Double(h) * 0.55)..<(h - 6) {
        for x in Int(cx - trunkW / 2)..<Int(cx + trunkW / 2) { trunk[y][x] = "t" }
    }
    for y in Int(Double(h) * 0.55)..<(h - 6) { trunk[y][Int(cx + trunkW / 2) - 1] = "r" }
    outlineShape(&trunk, body: ["t", "r"], outline: "r")
    composite(&g, trunk, dx: 0, dy: 0)
    // canopy
    var can = emptyGrid(w: w, h: h)
    if conifer {
        // stacked triangles
        let tiers = 3
        for tier in 0..<tiers {
            let ty = Double(tier) * canopyR * 0.62 + canopyR * 0.55
            let tr = canopyR * (0.55 + 0.28 * Double(tier))
            for y in 0..<h { for x in 0..<w {
                let fy = Double(y) - ty
                let half = tr * (fy / (canopyR * 0.9) + 0.3)
                if fy > -canopyR * 0.3, fy < canopyR * 0.68,
                   abs(Double(x) - cx) < half { can[y][x] = "G" }
            } }
        }
    } else {
        shadeEllipse(&can, cx: cx, cy: canopyR + 4, rx: canopyR, ry: canopyR * 0.92,
                     main: "G", hi: "H", lo: "g", hiThresh: 0.40, loThresh: -0.55)
        // lumpy silhouette: soft side + top lobes
        shadeEllipse(&can, cx: cx - canopyR * 0.55, cy: canopyR * 1.28, rx: canopyR * 0.5,
                     ry: canopyR * 0.42, main: "G", hi: "H", lo: "G", hiThresh: 0.5)
        shadeEllipse(&can, cx: cx + canopyR * 0.55, cy: canopyR * 1.28, rx: canopyR * 0.5,
                     ry: canopyR * 0.42, main: "G", hi: "G", lo: "g", loThresh: -0.62)
        fillEllipse(&can, cx: cx - canopyR * 0.3, cy: canopyR * 0.5, rx: canopyR * 0.4, ry: canopyR * 0.3, "G")
        fillEllipse(&can, cx: cx + canopyR * 0.35, cy: canopyR * 0.55, rx: canopyR * 0.35, ry: canopyR * 0.28, "G")
    }
    // leaf texture flecks
    for y in 0..<h { for x in 0..<w where can[y][x] != "." {
        let r = speck(x, y, 131)
        if r < 40 { can[y][x] = "g" } else if r < 60, can[y][x] == "G" { can[y][x] = "H" }
    } }
    outlineShape(&can, body: ["G", "g", "H"], outline: "g")
    composite(&g, can, dx: 0, dy: 0)
    return g
}

// MARK: - PARK PROPS (bench, lamppost, fountain, statue, bridges, rocks)

func propBench() -> Grid {   // 64x40 wooden park bench
    var g = emptyGrid(w: 64, h: 40)
    // legs
    for (lx) in [7, 53] {
        for y in 20..<36 { for x in lx..<(lx + 4) { g[y][x] = "r" } }
    }
    // backrest: two plank rows
    for (py, ph) in [(4, 5), (11, 5)] {
        for y in py..<(py + ph) { for x in 4..<60 { g[y][x] = "T" } }
        for x in 4..<60 { g[py + ph - 1][x] = "t" }
    }
    // seat planks
    for y in 18..<26 { for x in 2..<62 { g[y][x] = "T" } }
    for x in 2..<62 { g[21][x] = "t"; g[25][x] = "t" }
    // uprights connecting backrest
    for (ux) in [8, 54] { for y in 4..<20 { for x in ux..<(ux + 3) { g[y][x] = "t" } } }
    outlineShape(&g, body: ["T", "t", "r"], outline: "r")
    return g
}

func propLamppost() -> Grid {   // 32x96 iron lamp with warm glass
    var g = emptyGrid(w: 32, h: 96)
    // base
    for y in 86..<92 { for x in 8..<24 { g[y][x] = "R" } }
    for y in 82..<86 { for x in 11..<21 { g[y][x] = "R" } }
    // pole
    for y in 22..<84 { for x in 14..<18 { g[y][x] = "R" } }
    for y in 22..<84 { g[y][14] = "x" }
    // head: cap + glass box
    for y in 2..<6 { for x in 10..<22 { g[y][x] = "R" } }
    g[1][15] = "R"; g[1][16] = "R"
    for y in 6..<20 { for x in 9..<23 { g[y][x] = "Q" } }
    for y in 9..<17 { for x in 12..<20 { g[y][x] = "W" } }
    for y in 6..<20 { g[y][9] = "R"; g[y][22] = "R" }
    for x in 9..<23 { g[19][x] = "R" }
    outlineShape(&g, body: ["R", "x", "Q", "W"], outline: "R")
    return g
}

func propFountain() -> Grid {   // 128x160 two-tier stone fountain
    var g = emptyGrid(w: 128, h: 160)
    // lower basin
    var basin = emptyGrid(w: 128, h: 160)
    fillEllipse(&basin, cx: 64, cy: 118, rx: 58, ry: 34, "1")
    fillEllipse(&basin, cx: 64, cy: 114, rx: 50, ry: 27, "w")
    for y in 0..<160 { for x in 0..<128 where basin[y][x] == "w" {
        if speck(x, y, 7) < 40 { basin[y][x] = "u" }
    } }
    // rim highlight/shadow
    for y in 0..<160 { for x in 0..<128 where basin[y][x] == "1" {
        if y < 100 { basin[y][x] = "9" }
        if y > 138 { basin[y][x] = "0" }
    } }
    outlineShape(&basin, body: ["1", "9", "0", "w", "u"], outline: "0")
    composite(&g, basin, dx: 0, dy: 0)
    // pedestal
    var ped = emptyGrid(w: 128, h: 160)
    for y in 66..<108 { for x in 54..<74 { ped[y][x] = "1" } }
    for y in 66..<108 { ped[y][54] = "9"; ped[y][73] = "0" }
    outlineShape(&ped, body: ["1", "9", "0"], outline: "0")
    composite(&g, ped, dx: 0, dy: 0)
    // upper bowl with water
    var bowl = emptyGrid(w: 128, h: 160)
    fillEllipse(&bowl, cx: 64, cy: 62, rx: 32, ry: 15, "1")
    fillEllipse(&bowl, cx: 64, cy: 59, rx: 26, ry: 10, "w")
    for y in 0..<160 { for x in 0..<128 where bowl[y][x] == "1" && y < 56 { bowl[y][x] = "9" } }
    outlineShape(&bowl, body: ["1", "9", "w"], outline: "0")
    composite(&g, bowl, dx: 0, dy: 0)
    // spout + falling water threads
    for y in 34..<52 { for x in 62..<66 { g[y][x] = "1" } }
    for y in 30..<36 { for x in 60..<68 { g[y][x] = "9" } }
    for (wx, wy0, wy1) in [(38, 66, 96), (88, 66, 96), (64, 40, 52)] {
        for y in wy0..<wy1 { if y % 3 != 0 { g[y][wx] = "u"; g[y][wx + 1] = "W" } }
    }
    return g
}

func propStatue() -> Grid {   // 64x96 stone duck memorial on a plinth
    var g = emptyGrid(w: 64, h: 96)
    // plinth
    for y in 78..<92 { for x in 8..<56 { g[y][x] = "1" } }
    for y in 78..<80 { for x in 8..<56 { g[y][x] = "9" } }
    for y in 62..<78 { for x in 16..<48 { g[y][x] = "1" } }
    for y in 62..<78 { g[y][16] = "9"; g[y][47] = "0" }
    // duck: body + head + bill, all stone tones
    var duck = emptyGrid(w: 64, h: 96)
    shadeEllipse(&duck, cx: 30, cy: 46, rx: 17, ry: 12, main: "1", hi: "9", lo: "0")
    shadeEllipse(&duck, cx: 42, cy: 26, rx: 9, ry: 8.5, main: "1", hi: "9", lo: "0")
    for y in 22..<28 { for x in 50..<60 { duck[y][x] = "0" } }   // bill
    fillEllipse(&duck, cx: 16, cy: 42, rx: 5, ry: 4, "9")        // tail
    duck[24][44] = "5"; duck[24][45] = "5"                        // carved eye
    outlineShape(&duck, body: ["1", "9", "0", "5"], outline: "5")
    composite(&g, duck, dx: 0, dy: 0)
    outlineShape(&g, body: ["1", "9", "0", "5"], outline: "5")
    return g
}

func propRock(_ v: Int) -> Grid {   // 48x48 boulder with grass tufts
    var g = emptyGrid(w: 48, h: 48)
    fillEllipse(&g, cx: 24, cy: 40, rx: 18, ry: 4, "S")
    var rock = emptyGrid(w: 48, h: 48)
    shadeEllipse(&rock, cx: 22 + Double(v % 3) * 2, cy: 26, rx: 15 + Double(v % 2) * 3,
                 ry: 12, main: "1", hi: "9", lo: "0")
    shadeEllipse(&rock, cx: 30, cy: 20, rx: 9, ry: 7, main: "1", hi: "9", lo: "0")
    outlineShape(&rock, body: ["1", "9", "0"], outline: "0")
    composite(&g, rock, dx: 0, dy: 0)
    for (tx, ty) in [(8, 36), (38, 37), (20, 39)] {
        g[ty][tx] = "G"; g[ty - 1][tx] = "H"; g[ty][tx + 1] = "G"
    }
    return g
}

func propBridgeV() -> Grid {   // 96x144: north-south plank walkway
    var g = emptyGrid(w: 96, h: 144)
    // planks: horizontal boards
    var y = 0
    var i = 0
    while y < 144 {
        let bh = 10 + (i % 2)
        for yy in y..<min(144, y + bh) { for x in 8..<88 { g[yy][x] = yy == y + bh - 1 ? "t" : "T" } }
        // nail dots
        g[y + 3][12] = "r"; g[y + 3][83] = "r"
        y += bh; i += 1
    }
    // side rails
    for x in [4, 5, 6, 89, 90, 91] { for yy in 0..<144 { g[yy][x] = "r" } }
    for x in [7, 88] { for yy in 0..<144 where yy % 18 < 10 { g[yy][x] = "t" } }
    outlineShape(&g, body: ["T", "t", "r"], outline: "r")
    return g
}

func propBridgeH() -> Grid {   // 144x48: east-west pier/walkway
    var g = emptyGrid(w: 144, h: 48)
    var x = 0
    var i = 0
    while x < 144 {
        let bw = 10 + (i % 2)
        for xx in x..<min(144, x + bw) { for y in 6..<42 { g[y][xx] = xx == x + bw - 1 ? "t" : "T" } }
        g[10][x + 3] = "r"; g[37][x + 3] = "r"
        x += bw; i += 1
    }
    for y in [2, 3, 4, 43, 44, 45] { for xx in 0..<144 { g[y][xx] = "r" } }
    outlineShape(&g, body: ["T", "t", "r"], outline: "r")
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
    // ridge cap + chimney
    rect(0, 0, W, 2, roofSh)
    rect(78, 0, 12, 10, RGB(r: 0x8B, g: 0x5C, b: 0x28))
    rect(77, 0, 14, 2, RGB(r: 0x6E, g: 0x48, b: 0x1E))

    // Wall rows 28-69, plank lines every 7px + eave shade + corner trim.
    rect(1, 28, W - 2, 42, wall)
    for y in stride(from: 34, to: 69, by: 7) { rect(1, y, W - 2, 1, wallSh) }
    rect(1, 28, W - 2, 3, wallSh)
    rect(1, 28, 4, 42, RGB(r: 0xD4, g: 0xA8, b: 0x70))
    rect(W - 5, 28, 4, 42, wallSh)

    // Windows: left lit or dark by variant hash; right window 2px lower
    // (asymmetry rule). Sizes differ slightly.
    let leftLit = h % 2 == 0
    rect(14, 34, 14, 16, frame)
    rect(15, 35, 12, 14, leftLit ? glassLit : glassDrk)
    rect(78, 36, 14, 15, frame)
    rect(79, 37, 12, 13, leftLit ? glassDrk : glassLit)
    if leftLit { rect(79, 37, 12, 3, RGB(r: 0x3A, g: 0x4C, b: 0x5E)) }  // curtain hint
    // sills + shutters
    rect(12, 50, 18, 3, frame)
    rect(76, 51, 18, 3, frame)
    rect(10, 34, 3, 16, roofSh); rect(29, 34, 3, 16, roofSh)
    rect(74, 36, 3, 15, roofSh); rect(93, 36, 3, 15, roofSh)
    // window cross panes
    rect(20, 35, 1, 14, frame); rect(15, 41, 12, 1, frame)
    rect(84, 37, 1, 13, frame); rect(79, 43, 12, 1, frame)

    // Foundation rows 70-79 with darker top lip.
    rect(0, 70, W, 10, found)
    rect(0, 70, W, 1, outline)

    // Door: off-center (bible: never centered), reaches ground, with a
    // little canopy and a step.
    let doorX = h % 3 == 0 ? 40 : 46
    rect(doorX - 3, 46, 24, 4, roof)
    rect(doorX - 3, 49, 24, 1, roofSh)
    rect(doorX, 50, 18, 30, doorDk)
    rect(doorX + 1, 51, 16, 29, doorC)
    rect(doorX + 3, 54, 12, 1, doorDk)                // panel line
    put(doorX + 13, 66, knob); put(doorX + 14, 66, knob)
    rect(doorX - 2, 78, 22, 2, RGB(r: 0x8A, g: 0x8A, b: 0x8A))   // step

    // Lab dish for the secret-lab variant
    if variant == "dark_purple" {
        rect(20, 2, 3, 12, RGB(r: 0x6A, g: 0x6A, b: 0x6A))
        for i in 0..<7 {
            rect(12 + i, 6 - min(i, 3), 1, 4 + min(i, 3), RGB(r: 0x9A, g: 0x9A, b: 0x9A))
        }
        rect(10, 0, 12, 2, RGB(r: 0xB8, g: 0xB8, b: 0xB8))
    }

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

// MARK: - CITY BUILDINGS + PROPS + INTERIORS (RGB canvas)

final class RGBCanvas {
    let W: Int, H: Int
    var px: [UInt8]
    init(_ w: Int, _ h: Int) { W = w; H = h; px = [UInt8](repeating: 0, count: w * h * 4) }
    func put(_ x: Int, _ y: Int, _ c: RGB) {
        guard x >= 0, x < W, y >= 0, y < H else { return }
        let i = (y * W + x) * 4
        px[i] = c.r; px[i+1] = c.g; px[i+2] = c.b; px[i+3] = 255
    }
    func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: RGB) {
        for yy in y..<(y+h) { for xx in x..<(x+w) { put(xx, yy, c) } }
    }
    func image() -> CGImage {
        let provider = CGDataProvider(data: Data(px) as CFData)!
        return CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: W * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)!
    }
}

let brickA   = RGB(r: 0xC4, g: 0x7A, b: 0x52), brickAsh = RGB(r: 0x9A, g: 0x5C, b: 0x3A)
let concB    = RGB(r: 0x9E, g: 0x9E, b: 0x9E), concBsh  = RGB(r: 0x7A, g: 0x7A, b: 0x7A)
let outlineB = RGB(r: 0x3C, g: 0x28, b: 0x10)
let glassLit2 = RGB(r: 0xF0, g: 0xE8, b: 0x90), glassDrk2 = RGB(r: 0x2A, g: 0x3A, b: 0x4A)
let frameC   = RGB(r: 0x3A, g: 0x3A, b: 0x3A)

/// Shared storefront/base building shell. Returns canvas; caller decorates.
func buildingShell(w: Int, h: Int, wall: RGB, wallSh: RGB, brick: Bool) -> RGBCanvas {
    let c = RGBCanvas(w, h)
    c.rect(0, 0, w, h, wall)
    // parapet roofline
    c.rect(0, 0, w, 10, wallSh)
    c.rect(0, 10, w, 2, outlineB)
    if brick {
        var y = 14
        var row = 0
        while y < h - 4 {
            c.rect(0, y, w, 1, wallSh)
            let off = row % 2 == 0 ? 0 : 16
            var x = off
            while x < w { c.rect(x, y - 5, 1, 5, wallSh); x += 32 }
            y += 6; row += 1
        }
    }
    // side shading + outline
    c.rect(w - 6, 0, 6, h, wallSh)
    c.rect(0, 0, 1, h, outlineB); c.rect(w - 1, 0, 1, h, outlineB)
    c.rect(0, 0, w, 1, outlineB); c.rect(0, h - 1, w, 1, outlineB)
    return c
}

func windowGrid(_ c: RGBCanvas, x0: Int, y0: Int, cols: Int, rows: Int,
                ww: Int, wh: Int, gapX: Int, gapY: Int, seed: Int) {
    for r in 0..<rows { for col in 0..<cols {
        let x = x0 + col * (ww + gapX), y = y0 + r * (wh + gapY)
        c.rect(x - 2, y - 2, ww + 4, wh + 4, frameC)
        let lit = speck(col, r, seed) % 3 == 0
        c.rect(x, y, ww, wh, lit ? glassLit2 : glassDrk2)
        c.rect(x, y, ww, 3, RGB(r: 0xC8, g: 0xD8, b: 0xE0))
        c.rect(x + ww/2 - 1, y, 2, wh, frameC)
    } }
}

func awning(_ c: RGBCanvas, x: Int, y: Int, w: Int, color: RGB) {
    let white = RGB(r: 0xF0, g: 0xEC, b: 0xE0)
    for i in 0..<w {
        c.put(x + i, y, outlineB)
        for yy in (y + 1)..<(y + 14) {
            c.put(x + i, yy, (i / 12) % 2 == 0 ? color : white)
        }
    }
    // scalloped bottom
    var i = 0
    while i < w {
        c.rect(x + i + 2, y + 14, 8, 3, (i / 12) % 2 == 0 ? color : white)
        i += 12
    }
    c.rect(x, y + 13, w, 1, outlineB)
}

func doorway(_ c: RGBCanvas, x: Int, y: Int, w: Int, h: Int, glass: Bool) {
    c.rect(x - 2, y - 2, w + 4, h + 2, frameC)
    c.rect(x, y, w, h, glass ? glassDrk2 : RGB(r: 0x5A, g: 0x3E, b: 0x1E))
    if glass { c.rect(x + w/2 - 1, y, 2, h, frameC) }
    else { c.put(x + w - 5, y + h/2, RGB(r: 0xD4, g: 0xB0, b: 0x30)) }
}

func bldgCafe() -> RGBCanvas {
    let c = buildingShell(w: 256, h: 192, wall: brickA, wallSh: brickAsh, brick: true)
    windowGrid(c, x0: 24, y0: 26, cols: 4, rows: 1, ww: 40, wh: 30, gapX: 16, gapY: 0, seed: 3)
    awning(c, x: 12, y: 70, w: 232, color: RGB(r: 0xC8, g: 0x30, b: 0x30))
    // big shop window + door
    c.rect(22, 96, 130, 60, frameC)
    c.rect(26, 100, 122, 52, glassDrk2)
    c.rect(26, 100, 122, 8, RGB(r: 0xC8, g: 0xD8, b: 0xE0))
    doorway(c, x: 180, y: 100, w: 44, h: 88, glass: true)
    // coffee cup sign
    c.rect(104, 44, 40, 22, RGB(r: 0xF0, g: 0xEC, b: 0xE0))
    c.rect(104, 44, 40, 2, outlineB); c.rect(104, 64, 40, 2, outlineB)
    c.rect(104, 44, 2, 22, outlineB); c.rect(142, 44, 2, 22, outlineB)
    c.rect(114, 50, 14, 10, RGB(r: 0x5A, g: 0x3E, b: 0x1E))
    c.rect(128, 52, 4, 5, RGB(r: 0x5A, g: 0x3E, b: 0x1E))
    c.put(118, 47, brickAsh); c.put(122, 46, brickAsh)
    return c
}

func bldgStore() -> RGBCanvas {
    let c = buildingShell(w: 256, h: 192, wall: RGB(r: 0xC4, g: 0x95, b: 0x5A), wallSh: RGB(r: 0xA0, g: 0x78, b: 0x40), brick: false)
    awning(c, x: 12, y: 58, w: 232, color: RGB(r: 0x3D, g: 0x72, b: 0x20))
    c.rect(20, 84, 150, 70, frameC)
    c.rect(24, 88, 142, 62, glassDrk2)
    // crates in window
    c.rect(32, 118, 28, 28, RGB(r: 0xA0, g: 0x78, b: 0x40))
    c.rect(66, 126, 22, 20, RGB(r: 0x8B, g: 0x5C, b: 0x28))
    c.rect(100, 112, 30, 34, RGB(r: 0xC4, g: 0x95, b: 0x5A))
    doorway(c, x: 196, y: 92, w: 40, h: 96, glass: false)
    // sign: stacked goods square
    c.rect(108, 26, 40, 26, RGB(r: 0xD4, g: 0xB0, b: 0x30))
    c.rect(108, 26, 40, 2, outlineB); c.rect(108, 50, 40, 2, outlineB)
    return c
}

func bldgHospital() -> RGBCanvas {
    let c = buildingShell(w: 256, h: 224, wall: RGB(r: 0xE8, g: 0xE8, b: 0xE4), wallSh: concB, brick: false)
    windowGrid(c, x0: 20, y0: 26, cols: 5, rows: 2, ww: 34, wh: 28, gapX: 12, gapY: 14, seed: 11)
    doorway(c, x: 96, y: 156, w: 64, h: 66, glass: true)
    c.rect(88, 148, 80, 6, concB)   // entrance canopy
    // red cross sign
    c.rect(112, 112, 32, 32, RGB(r: 0xF0, g: 0xEC, b: 0xE0))
    c.rect(124, 116, 8, 24, RGB(r: 0xC8, g: 0x30, b: 0x30))
    c.rect(116, 124, 24, 8, RGB(r: 0xC8, g: 0x30, b: 0x30))
    return c
}

func bldgPolice() -> RGBCanvas {
    let c = buildingShell(w: 256, h: 224, wall: concB, wallSh: concBsh, brick: false)
    c.rect(0, 12, 256, 8, RGB(r: 0x1A, g: 0x3A, b: 0x6A))
    windowGrid(c, x0: 24, y0: 34, cols: 4, rows: 2, ww: 40, wh: 26, gapX: 16, gapY: 14, seed: 7)
    doorway(c, x: 100, y: 158, w: 56, h: 64, glass: true)
    c.rect(92, 150, 72, 6, RGB(r: 0x1A, g: 0x3A, b: 0x6A))
    // badge sign
    c.rect(116, 116, 24, 26, RGB(r: 0xD4, g: 0xB0, b: 0x30))
    c.rect(120, 120, 16, 18, RGB(r: 0x1A, g: 0x3A, b: 0x6A))
    // blue lamps
    for lx in [78, 170] {
        c.rect(lx, 160, 8, 8, RGB(r: 0x3A, g: 0x5F, b: 0xA0))
        c.rect(lx + 2, 168, 4, 14, frameC)
    }
    return c
}

func bldgApartment() -> RGBCanvas {
    let c = buildingShell(w: 256, h: 256, wall: RGB(r: 0x8B, g: 0x5C, b: 0x40), wallSh: RGB(r: 0x6E, g: 0x44, b: 0x2E), brick: true)
    windowGrid(c, x0: 22, y0: 26, cols: 4, rows: 3, ww: 36, wh: 30, gapX: 20, gapY: 22, seed: 21)
    // stoop + door
    doorway(c, x: 106, y: 186, w: 44, h: 60, glass: false)
    c.rect(96, 246, 64, 6, concB)
    c.rect(100, 240, 56, 6, concBsh)
    // fire escape zigzag on right
    let steel = RGB(r: 0x48, g: 0x48, b: 0x48)
    for (fy) in [40, 92, 144] {
        c.rect(196, fy, 52, 3, steel)
        c.rect(196, fy, 3, 34, steel)
        c.rect(245, fy, 3, 34, steel)
        for i in 0..<6 { c.rect(200 + i * 8, fy + 34 - i * 5, 8, 2, steel) }
    }
    return c
}

func bldgDevcorp() -> RGBCanvas {
    let dark = RGB(r: 0x2E, g: 0x2E, b: 0x38), darker = RGB(r: 0x22, g: 0x22, b: 0x2A)
    let c = buildingShell(w: 224, h: 288, wall: dark, wallSh: darker, brick: false)
    let teal = RGB(r: 0x3A, g: 0x8A, b: 0x8A)
    for r in 0..<7 { for col in 0..<5 {
        let x = 16 + col * 40, y = 22 + r * 34
        c.rect(x, y, 32, 26, speck(col, r, 31) % 4 == 0 ? teal : glassDrk2)
        c.rect(x, y, 32, 2, RGB(r: 0x4A, g: 0x6A, b: 0x7A))
    } }
    doorway(c, x: 84, y: 250, w: 56, h: 36, glass: true)
    return c
}

func propCar(variantColor: RGB, police: Bool) -> RGBCanvas {
    let c = RGBCanvas(96, 48)
    let body = police ? RGB(r: 0xE8, g: 0xE8, b: 0xE4) : variantColor
    // wheels
    for wx in [14, 66] {
        c.rect(wx, 32, 16, 12, frameC)
        c.rect(wx + 4, 36, 8, 5, RGB(r: 0x8A, g: 0x8A, b: 0x8A))
    }
    // body + cabin
    c.rect(4, 20, 88, 16, body)
    c.rect(20, 8, 52, 14, body)
    c.rect(26, 10, 18, 10, glassDrk2)
    c.rect(50, 10, 16, 10, glassDrk2)
    if police {
        c.rect(4, 24, 88, 6, RGB(r: 0x1A, g: 0x3A, b: 0x6A))
        c.rect(38, 4, 8, 5, RGB(r: 0xC8, g: 0x30, b: 0x30))
        c.rect(48, 4, 8, 5, RGB(r: 0x3A, g: 0x5F, b: 0xA0))
    }
    c.rect(84, 24, 6, 4, RGB(r: 0xF0, g: 0xE8, b: 0x90))
    c.rect(4, 24, 4, 4, RGB(r: 0xC8, g: 0x30, b: 0x30))
    return c
}

func propDumpster() -> RGBCanvas {
    let c = RGBCanvas(96, 64)
    let green = RGB(r: 0x3D, g: 0x5A, b: 0x3A), greenSh = RGB(r: 0x2A, g: 0x42, b: 0x28)
    c.rect(4, 20, 88, 38, green)
    c.rect(4, 20, 88, 8, greenSh)
    c.rect(0, 14, 96, 8, greenSh)
    for x in stride(from: 12, to: 90, by: 22) { c.rect(x, 30, 3, 22, greenSh) }
    c.rect(10, 58, 10, 6, frameC); c.rect(76, 58, 10, 6, frameC)
    return c
}

func propTrash() -> RGBCanvas {
    let c = RGBCanvas(32, 48)
    c.rect(6, 12, 20, 32, concB)
    c.rect(6, 12, 20, 4, concBsh)
    c.rect(4, 8, 24, 5, concBsh)
    for x in stride(from: 9, to: 24, by: 5) { c.rect(x, 18, 2, 22, concBsh) }
    return c
}

func propHydrant() -> RGBCanvas {
    let c = RGBCanvas(24, 36)
    let red = RGB(r: 0xC8, g: 0x30, b: 0x30), redSh = RGB(r: 0x9A, g: 0x24, b: 0x24)
    c.rect(6, 10, 12, 20, red)
    c.rect(8, 4, 8, 7, red)
    c.rect(9, 2, 6, 3, redSh)
    c.rect(2, 16, 5, 6, redSh); c.rect(17, 16, 5, 6, redSh)
    c.rect(4, 30, 16, 4, redSh)
    return c
}

func propCone() -> RGBCanvas {
    let c = RGBCanvas(24, 32)
    let orange = RGB(r: 0xE8, g: 0x7A, b: 0x2A)
    for i in 0..<20 {
        let w = 4 + i * 14 / 20
        c.rect(12 - w/2, 6 + i, w, 1, i > 8 && i < 13 ? RGB(r: 0xF0, g: 0xEC, b: 0xE0) : orange)
    }
    c.rect(2, 26, 20, 4, orange)
    return c
}

func propBarrel() -> RGBCanvas {
    let c = RGBCanvas(32, 40)
    let orange = RGB(r: 0xE8, g: 0x7A, b: 0x2A), oSh = RGB(r: 0xB8, g: 0x5E, b: 0x20)
    c.rect(4, 4, 24, 32, orange)
    c.rect(4, 4, 24, 4, oSh); c.rect(4, 18, 24, 4, RGB(r: 0xF0, g: 0xEC, b: 0xE0))
    c.rect(4, 32, 24, 4, oSh)
    c.rect(24, 4, 4, 32, oSh)
    return c
}

func propContainer() -> RGBCanvas {
    let c = RGBCanvas(160, 96)
    let red = RGB(r: 0xA8, g: 0x2E, b: 0x2E), redSh = RGB(r: 0x7E, g: 0x22, b: 0x22)
    c.rect(0, 12, 160, 78, red)
    c.rect(0, 12, 160, 10, redSh)
    for x in stride(from: 8, to: 156, by: 14) { c.rect(x, 24, 4, 62, redSh) }
    c.rect(146, 30, 10, 50, frameC)
    return c
}

func propPipes() -> RGBCanvas {
    let c = RGBCanvas(128, 48)
    let steel = RGB(r: 0x8A, g: 0x8A, b: 0x8A), steelSh = RGB(r: 0x5E, g: 0x5E, b: 0x5E)
    for (py, count) in [(28, 3), (12, 2)] {
        for i in 0..<count {
            let x = 10 + i * 38 + (py == 12 ? 19 : 0)
            c.rect(x, py, 36, 16, steel)
            c.rect(x, py, 36, 4, RGB(r: 0xB8, g: 0xB8, b: 0xB8))
            c.rect(x, py + 12, 36, 4, steelSh)
            c.rect(x + 2, py + 2, 4, 12, steelSh)
        }
    }
    return c
}

func propMound() -> RGBCanvas {
    let c = RGBCanvas(96, 64)
    for y in 0..<64 { for x in 0..<96 {
        let dx = (Double(x) - 48) / 44, dy = (Double(y) - 44) / 26
        if dx*dx + dy*dy <= 1 {
            let r = speck(x, y, 41)
            c.put(x, y, r < 300 ? RGB(r: 0xA0, g: 0x78, b: 0x40) : RGB(r: 0xC4, g: 0x95, b: 0x5A))
        }
    } }
    return c
}

func propChainlink() -> RGBCanvas {
    let c = RGBCanvas(32, 64)
    let steel = RGB(r: 0x9A, g: 0x9A, b: 0x9A)
    c.rect(0, 8, 3, 56, RGB(r: 0x6E, g: 0x6E, b: 0x6E))
    c.rect(0, 8, 32, 3, steel)
    c.rect(0, 58, 32, 2, steel)
    var d = 0
    while d < 32 + 48 {
        for i in 0..<48 {
            let x1 = d - i, y = 11 + i
            if x1 >= 0, x1 < 32, y < 58 { c.put(x1, y, steel) }
            let x2 = i - d + 31
            if x2 >= 0, x2 < 32, y < 58 { c.put(x2, y, steel) }
        }
        d += 12
    }
    return c
}

func propTrailer() -> RGBCanvas {
    let c = RGBCanvas(192, 128)
    let cream = RGB(r: 0xE0, g: 0xD8, b: 0xC0), creamSh = RGB(r: 0xB8, g: 0xB0, b: 0x98)
    c.rect(8, 20, 176, 84, cream)
    c.rect(8, 20, 176, 12, creamSh)
    c.rect(4, 14, 184, 8, RGB(r: 0x6E, g: 0x6E, b: 0x6E))
    c.rect(24, 44, 40, 30, frameC); c.rect(28, 48, 32, 22, glassDrk2)
    c.rect(120, 44, 40, 60, frameC); c.rect(124, 48, 32, 54, RGB(r: 0x5A, g: 0x3E, b: 0x1E))
    for bx in [20, 160] { c.rect(bx, 104, 14, 14, concBsh) }
    c.rect(70, 30, 60, 8, RGB(r: 0xE8, g: 0xC0, b: 0x40))
    return c
}

// ---- Interiors ----

func tileFloorWood() -> RGBCanvas {
    let c = RGBCanvas(32, 32)
    let wood = RGB(r: 0xC4, g: 0x95, b: 0x5A), woodSh = RGB(r: 0xA0, g: 0x78, b: 0x40)
    c.rect(0, 0, 32, 32, wood)
    c.rect(0, 7, 32, 1, woodSh); c.rect(0, 15, 32, 1, woodSh)
    c.rect(0, 23, 32, 1, woodSh); c.rect(0, 31, 32, 1, woodSh)
    c.rect(10, 0, 1, 8, woodSh); c.rect(24, 8, 1, 8, woodSh)
    c.rect(6, 16, 1, 8, woodSh); c.rect(20, 24, 1, 8, woodSh)
    for i in 0..<6 { c.put(4 + i * 5, 3 + (i * 7) % 26, woodSh) }
    return c
}

func tileFloorLab() -> RGBCanvas {
    let c = RGBCanvas(32, 32)
    let a = RGB(r: 0xB8, g: 0xC0, b: 0xC8), b = RGB(r: 0x9A, g: 0xA4, b: 0xB0)
    c.rect(0, 0, 16, 16, a); c.rect(16, 0, 16, 16, b)
    c.rect(0, 16, 16, 16, b); c.rect(16, 16, 16, 16, a)
    return c
}

func tileWallInt(top: Bool) -> RGBCanvas {
    let c = RGBCanvas(32, 32)
    if top {
        c.rect(0, 0, 32, 32, RGB(r: 0x8B, g: 0x5C, b: 0x40))
        c.rect(0, 28, 32, 4, RGB(r: 0x6E, g: 0x44, b: 0x2E))
    } else {
        c.rect(0, 0, 32, 32, RGB(r: 0xE8, g: 0xE0, b: 0xC8))
        c.rect(0, 0, 32, 2, RGB(r: 0xC8, g: 0xC0, b: 0xA8))
        c.rect(0, 24, 32, 8, RGB(r: 0xA0, g: 0x78, b: 0x40))
        c.rect(0, 24, 32, 2, RGB(r: 0x8B, g: 0x5C, b: 0x28))
    }
    return c
}

func furnBed() -> RGBCanvas {
    let c = RGBCanvas(64, 96)
    let wood = RGB(r: 0x8B, g: 0x5C, b: 0x28)
    c.rect(2, 2, 60, 16, wood)
    c.rect(2, 84, 60, 10, wood)
    c.rect(6, 12, 52, 76, RGB(r: 0xF0, g: 0xEC, b: 0xE0))
    c.rect(6, 12, 52, 20, RGB(r: 0xE0, g: 0xD8, b: 0xC0))
    c.rect(10, 16, 44, 12, RGB(r: 0xF0, g: 0xEC, b: 0xE0))
    c.rect(6, 34, 52, 54, RGB(r: 0x6E, g: 0x8E, b: 0x3A))
    c.rect(6, 34, 52, 6, RGB(r: 0x54, g: 0x6E, b: 0x2A))
    return c
}

func furnTable() -> RGBCanvas {
    let c = RGBCanvas(64, 48)
    let wood = RGB(r: 0xA0, g: 0x78, b: 0x40), woodSh = RGB(r: 0x8B, g: 0x5C, b: 0x28)
    c.rect(2, 6, 60, 30, wood)
    c.rect(2, 6, 60, 4, RGB(r: 0xC4, g: 0x95, b: 0x5A))
    c.rect(2, 32, 60, 4, woodSh)
    c.rect(6, 36, 6, 10, woodSh); c.rect(52, 36, 6, 10, woodSh)
    return c
}

func furnChair() -> RGBCanvas {
    let c = RGBCanvas(32, 48)
    let wood = RGB(r: 0xA0, g: 0x78, b: 0x40), woodSh = RGB(r: 0x8B, g: 0x5C, b: 0x28)
    c.rect(4, 2, 24, 18, wood)
    c.rect(4, 2, 24, 3, woodSh)
    c.rect(4, 20, 24, 12, RGB(r: 0xC4, g: 0x95, b: 0x5A))
    c.rect(4, 32, 4, 12, woodSh); c.rect(24, 32, 4, 12, woodSh)
    return c
}

func furnCabinet() -> RGBCanvas {
    let c = RGBCanvas(64, 96)
    let wood = RGB(r: 0x8B, g: 0x5C, b: 0x28), woodSh = RGB(r: 0x6E, g: 0x48, b: 0x1E)
    c.rect(2, 2, 60, 90, wood)
    c.rect(2, 2, 60, 6, woodSh)
    c.rect(6, 12, 24, 34, woodSh); c.rect(34, 12, 24, 34, woodSh)
    c.rect(6, 52, 52, 16, woodSh); c.rect(6, 72, 52, 16, woodSh)
    for (kx, ky) in [(27, 28), (37, 28), (30, 58), (30, 78)] {
        c.rect(kx, ky, 3, 3, RGB(r: 0xD4, g: 0xB0, b: 0x30))
    }
    return c
}

func furnRug() -> RGBCanvas {
    let c = RGBCanvas(96, 64)
    let red = RGB(r: 0xB8, g: 0x4A, b: 0x3A)
    for y in 0..<64 { for x in 0..<96 {
        let dx = (Double(x) - 48) / 46, dy = (Double(y) - 32) / 30
        let d = dx*dx + dy*dy
        if d <= 1 {
            c.put(x, y, d > 0.72 ? RGB(r: 0xD4, g: 0xB0, b: 0x30) : (d > 0.5 ? RGB(r: 0xE0, g: 0xD8, b: 0xC0) : red))
        }
    } }
    return c
}

func furnPlant() -> RGBCanvas {
    let c = RGBCanvas(32, 64)
    c.rect(8, 46, 16, 14, RGB(r: 0xB8, g: 0x5E, b: 0x20))
    c.rect(8, 46, 16, 3, RGB(r: 0x8B, g: 0x45, b: 0x18))
    for (lx, ly, lw, lh) in [(12, 10, 8, 26), (4, 20, 8, 20), (20, 18, 8, 22)] {
        c.rect(lx, ly, lw, lh, RGB(r: 0x3D, g: 0x72, b: 0x20))
        c.rect(lx + 2, ly + 2, 3, lh - 6, RGB(r: 0x5D, g: 0xA8, b: 0x32))
    }
    return c
}

func furnCounter() -> RGBCanvas {
    let c = RGBCanvas(96, 48)
    c.rect(0, 4, 96, 36, RGB(r: 0xA0, g: 0x78, b: 0x40))
    c.rect(0, 4, 96, 8, RGB(r: 0xC4, g: 0x95, b: 0x5A))
    c.rect(0, 36, 96, 8, RGB(r: 0x8B, g: 0x5C, b: 0x28))
    return c
}

func furnLabConsole() -> RGBCanvas {
    let c = RGBCanvas(128, 96)
    let dark = RGB(r: 0x3A, g: 0x3A, b: 0x4A), darker = RGB(r: 0x2A, g: 0x2A, b: 0x36)
    c.rect(4, 8, 120, 80, dark)
    c.rect(4, 8, 120, 10, darker)
    c.rect(4, 80, 120, 8, darker)
    for (sx, on) in [(14, true), (52, false), (90, true)] {
        c.rect(sx, 24, 26, 20, frameC)
        c.rect(sx + 2, 26, 22, 16, on ? RGB(r: 0x3A, g: 0x8A, b: 0x8A) : glassDrk2)
        if on { c.rect(sx + 4, 30, 12, 2, RGB(r: 0x8A, g: 0xC8, b: 0xC8)) }
    }
    for i in 0..<10 {
        c.rect(12 + i * 11, 58, 6, 4, speck(i, 1, 77) % 3 == 0 ? RGB(r: 0xC8, g: 0x30, b: 0x30) : RGB(r: 0xE8, g: 0xC0, b: 0x40))
    }
    return c
}

func writeCanvas(_ c: RGBCanvas, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, c.image(), nil)
    CGImageDestinationFinalize(dest)
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

// ---- Human NPCs ----
var npcPreviewRows: [[Grid]] = []
for role in npcRoles {
    var row: [Grid] = []
    for (di, dname) in [(0, "south"), (1, "north"), (2, "east")] {
        for step in 0..<2 {
            let frame = humanFrame(role, dir: di, step: step)
            writePNG(render(frame), to: "\(outDir)/npc-\(role.name)-\(dname)-f\(step + 1)-64x96.png")
            if step == 0 { row.append(frame) }
        }
    }
    // west = mirrored east
    for step in 0..<2 {
        writePNG(render(mirrored(humanFrame(role, dir: 2, step: step))),
                 to: "\(outDir)/npc-\(role.name)-west-f\(step + 1)-64x96.png")
    }
    npcPreviewRows.append(row)
}
do {
    let previewDir = (previewPath as NSString).deletingLastPathComponent
    writeSheet(rows: npcPreviewRows, scale: 3, to: "\(previewDir)/npc-preview.png")
}

// ---- World tiles ----
for v in 0..<3 {
    writePNG(render(tileGrass(variant: v)), to: "\(outDir)/tile-grass-\(v)-32.png")
    writePNG(render(tileGrassDark(variant: v)), to: "\(outDir)/tile-grassdark-\(v)-32.png")
    writePNG(render(tileSidewalk(variant: v)), to: "\(outDir)/tile-sidewalk-\(v)-32.png")
}
for v in 0..<2 {
    writePNG(render(tileRoad(variant: v)), to: "\(outDir)/tile-road-\(v)-32.png")
}
for v in 0..<3 {
    writePNG(render(tileDirt(variant: v)), to: "\(outDir)/tile-dirt-\(v)-32.png")
}
writePNG(render(tileRoad(variant: 0, dash: true)), to: "\(outDir)/tile-road-dash-32.png")

writePNG(render(blobSheet(fillVariant: { tileDirt(variant: $0) }, rim: "r", fringe: nil)),
         to: "\(outDir)/sheet-dirt-blob-128.png")
writePNG(render(blobSheet(fillVariant: { tileStone(variant: $0) }, rim: "0", fringe: "g")),
         to: "\(outDir)/sheet-stone-blob-128.png")
writePNG(render(blobSheet(fillVariant: { tileWater(variant: $0) }, rim: "v", fringe: "T")),
         to: "\(outDir)/sheet-water-blob-128.png")
writePNG(render(blobSheet(fillVariant: { tileHedgeLeaf(variant: $0) }, rim: "g", fringe: nil)),
         to: "\(outDir)/sheet-hedge-blob-128.png")

// ---- City buildings + props + interiors ----
writeCanvas(bldgCafe(), to: "\(outDir)/bldg-cafe-256x192.png")
writeCanvas(bldgStore(), to: "\(outDir)/bldg-store-256x192.png")
writeCanvas(bldgHospital(), to: "\(outDir)/bldg-hospital-256x224.png")
writeCanvas(bldgPolice(), to: "\(outDir)/bldg-police-256x224.png")
writeCanvas(bldgApartment(), to: "\(outDir)/bldg-apartment-256x256.png")
writeCanvas(bldgDevcorp(), to: "\(outDir)/bldg-devcorp-224x288.png")
writeCanvas(propCar(variantColor: RGB(r: 0xC8, g: 0x30, b: 0x30), police: false), to: "\(outDir)/prop-car-red-96x48.png")
writeCanvas(propCar(variantColor: RGB(r: 0x3A, g: 0x5F, b: 0xA0), police: false), to: "\(outDir)/prop-car-blue-96x48.png")
writeCanvas(propCar(variantColor: concB, police: true), to: "\(outDir)/prop-car-police-96x48.png")
writeCanvas(propDumpster(), to: "\(outDir)/prop-dumpster-96x64.png")
writeCanvas(propTrash(), to: "\(outDir)/prop-trashcan-32x48.png")
writeCanvas(propHydrant(), to: "\(outDir)/prop-hydrant-24x36.png")
writeCanvas(propCone(), to: "\(outDir)/prop-cone-24x32.png")
writeCanvas(propBarrel(), to: "\(outDir)/prop-barrel-32x40.png")
writeCanvas(propContainer(), to: "\(outDir)/prop-container-160x96.png")
writeCanvas(propPipes(), to: "\(outDir)/prop-pipes-128x48.png")
writeCanvas(propMound(), to: "\(outDir)/prop-mound-96x64.png")
writeCanvas(propChainlink(), to: "\(outDir)/prop-chainlink-32x64.png")
writeCanvas(propTrailer(), to: "\(outDir)/prop-trailer-192x128.png")
writeCanvas(tileFloorWood(), to: "\(outDir)/tile-floorwood-32.png")
writeCanvas(tileFloorLab(), to: "\(outDir)/tile-floorlab-32.png")
writeCanvas(tileWallInt(top: true), to: "\(outDir)/tile-wallint-top-32.png")
writeCanvas(tileWallInt(top: false), to: "\(outDir)/tile-wallint-32.png")
writeCanvas(furnBed(), to: "\(outDir)/furn-bed-64x96.png")
writeCanvas(furnTable(), to: "\(outDir)/furn-table-64x48.png")
writeCanvas(furnChair(), to: "\(outDir)/furn-chair-32x48.png")
writeCanvas(furnCabinet(), to: "\(outDir)/furn-cabinet-64x96.png")
writeCanvas(furnRug(), to: "\(outDir)/furn-rug-96x64.png")
writeCanvas(furnPlant(), to: "\(outDir)/furn-plant-32x64.png")
writeCanvas(furnCounter(), to: "\(outDir)/furn-counter-96x48.png")
writeCanvas(furnLabConsole(), to: "\(outDir)/furn-labconsole-128x96.png")

// ---- Props ----
writePNG(render(propBench()), to: "\(outDir)/prop-bench-64x40.png")
writePNG(render(propLamppost()), to: "\(outDir)/prop-lamppost-32x96.png")
writePNG(render(propFountain()), to: "\(outDir)/prop-fountain-128x160.png")
writePNG(render(propStatue()), to: "\(outDir)/prop-statue-64x96.png")
for v in 1...3 { writePNG(render(propRock(v)), to: "\(outDir)/prop-rock-\(v)-48x48.png") }
writePNG(render(propBridgeV()), to: "\(outDir)/prop-bridge-v-96x144.png")
writePNG(render(propBridgeH()), to: "\(outDir)/prop-bridge-h-144x48.png")
do {
    let previewDir = (previewPath as NSString).deletingLastPathComponent
    writeSheet(rows: [[propBench(), propLamppost(), propStatue(), propRock(1), propRock(2), propRock(3)],
                      [propFountain(), propBridgeV(), propBridgeH()]],
               scale: 3, to: "\(previewDir)/props-preview.png")
}

// ---- Trees ----
writePNG(render(treeSprite(w: 96, h: 128, canopyR: 40)), to: "\(outDir)/tree-large-96x128.png")
writePNG(render(treeSprite(w: 64, h: 92, canopyR: 27)), to: "\(outDir)/tree-medium-64x92.png")
writePNG(render(treeSprite(w: 48, h: 68, canopyR: 19)), to: "\(outDir)/tree-small-48x68.png")
writePNG(render(treeSprite(w: 64, h: 110, canopyR: 26, conifer: true)), to: "\(outDir)/tree-conifer-64x110.png")
writePNG(render(treeSprite(w: 140, h: 190, canopyR: 60)), to: "\(outDir)/tree-oak-140x190.png")

// Tile preview sheet
do {
    let previews: [Grid] = [
        tileGrass(variant: 0), tileGrass(variant: 1), tileGrassDark(variant: 0),
        tileDirt(variant: 0), tileStone(variant: 0), tileSidewalk(variant: 2),
        tileRoad(variant: 0), tileRoad(variant: 0, dash: true), tileWater(variant: 0),
        tileHedgeLeaf(variant: 0)
    ]
    let gapT = 6
    var strip = emptyGrid(w: previews.count * (TS + gapT), h: TS)
    for (i, t) in previews.enumerated() {
        for y in 0..<TS { for x in 0..<TS { strip[y][i * (TS + gapT) + x] = t[y][x] } }
    }
    let previewDir = (previewPath as NSString).deletingLastPathComponent
    writeSheet(rows: [[strip],
                      [blobSheet(fillVariant: { tileDirt(variant: $0) }, rim: "r", fringe: nil),
                       blobSheet(fillVariant: { tileStone(variant: $0) }, rim: "0", fringe: "g"),
                       blobSheet(fillVariant: { tileWater(variant: $0) }, rim: "v", fringe: "T"),
                       blobSheet(fillVariant: { tileHedgeLeaf(variant: $0) }, rim: "g", fringe: nil)],
                      [treeSprite(w: 96, h: 128, canopyR: 40),
                       treeSprite(w: 64, h: 92, canopyR: 27),
                       treeSprite(w: 48, h: 68, canopyR: 19),
                       treeSprite(w: 64, h: 110, canopyR: 26, conifer: true),
                       treeSprite(w: 140, h: 190, canopyR: 60)]],
               scale: 3, to: "\(previewDir)/world-tiles-preview.png")
}
print("wrote full sets for \(characters.map(\.name).joined(separator: ", ")) + world tiles")

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
