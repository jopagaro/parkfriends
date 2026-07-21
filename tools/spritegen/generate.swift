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
    "S": (0x2A, 0x50, 0x18, 102), // drop shadow, 40% opacity
]

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

// MARK: - SHELLY (turtle, tank) — bible §4.2
// 16x24 canvas. Head rows 0-6 (46% presence), shell rows 7-12 (wider than
// head), legs 13-16, shadow 17-18. Skeptical eyes: right eye sits 1px lower.

let shellyHead: [String] = [
    ".....gggggg.....",
    "....gHHGGGGg....",
    "...gHHGGGGGGg...",
    "...gHGEGGGGGg...",
    "...gGGEGGGEGg...",
    "....gGGGGGEg....",
    ".....gGGGGg.....",
]

// Shell: rim outline, tan fill, hand-drawn (uneven) hex cells, highlight
// cluster upper-left.
let shellyShell: [String] = [
    "...rrTTTTTTrr...",
    "..rThhTTTttTTr..",
    ".rThhTTTTttTTTr.",
    ".rTttTTTTTTTtTr.",
    ".rTttTTTTTTttTr.",
    "..rrTTTttTTTrr..",
]

let shellyLegsNeutral: [String] = [
    "...gGg....gGg...",
    "...gGg....gGg...",
    "....gg....gg....",
]

let shellyLegsLeft: [String] = [   // left leg forward (longer), right tucked
    "...gGg....gGg...",
    "...gGg....ggg...",
    "...ggg..........",
]

let shellyLegsRight: [String] = [
    "...gGg....gGg...",
    "...ggg....gGg...",
    "..........ggg...",
]

let shellyShadow: [String] = [
    "...SSSSSSSSSS...",
    "....SSSSSSSS....",
]

struct FrameSpec {
    let headDY: Int
    let shellDX: Int
    let legs: [String]
}

// Bible walk cycle: F1 left fwd / F2 bob + tilt left / F3 right fwd /
// F4 bob + tilt right. 120ms per frame.
let shellyFrames: [FrameSpec] = [
    FrameSpec(headDY: 0, shellDX: 0,  legs: shellyLegsLeft),
    FrameSpec(headDY: 1, shellDX: -1, legs: shellyLegsNeutral),
    FrameSpec(headDY: 0, shellDX: 0,  legs: shellyLegsRight),
    FrameSpec(headDY: 1, shellDX: 1,  legs: shellyLegsNeutral),
]

func shellyFrame(_ spec: FrameSpec) -> Grid {
    var g = emptyGrid(w: 16, h: 24)
    stamp(&g, shellyShadow, x: 0, y: 17)
    stamp(&g, spec.legs, x: 0, y: 13)
    stamp(&g, shellyShell, x: spec.shellDX, y: 7)
    stamp(&g, shellyHead, x: 0, y: spec.headDY)
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

var previewGrids: [Grid] = []
for (i, spec) in shellyFrames.enumerated() {
    let grid = shellyFrame(spec)
    previewGrids.append(grid)
    writePNG(render(grid), to: "\(outDir)/shelly-walk-south-f\(i + 1)-16x24.png")
}

// Preview strip: 4 frames side by side with 4px gaps, 10x scale.
let gap = 4
let stripW = 16 * 4 + gap * 3
var strip = emptyGrid(w: stripW, h: 24)
for (i, g) in previewGrids.enumerated() {
    let ox = i * (16 + gap)
    for y in 0..<24 { for x in 0..<16 where g[y][x] != "." { strip[y][ox + x] = g[y][x] } }
}
writePNG(render(strip, scale: 10), to: previewPath)

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
