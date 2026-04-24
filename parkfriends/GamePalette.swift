import SpriteKit

extension SKColor {
    /// `#RRGGBB` or `#RRGGBBAA`
    convenience init?(hex: String, alpha: CGFloat = 1) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var n: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&n) else { return nil }
        let r, g, b, a: CGFloat
        if s.count == 8 {
            r = CGFloat((n >> 24) & 0xFF) / 255
            g = CGFloat((n >> 16) & 0xFF) / 255
            b = CGFloat((n >> 8) & 0xFF) / 255
            a = alpha * CGFloat(n & 0xFF) / 255
        } else {
            r = CGFloat((n >> 16) & 0xFF) / 255
            g = CGFloat((n >> 8) & 0xFF) / 255
            b = CGFloat(n & 0xFF) / 255
            a = alpha
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

/// Master colors from the design bible (Parts 2 & 11).
enum GamePalette {

    static let outline = SKColor(hex: "1E1E22")!

    // Grass family (§2.1)
    static let grassG1 = SKColor(hex: "5DA832")!
    static let grassG2 = SKColor(hex: "62B035")!
    static let grassG3 = SKColor(hex: "4A8A28")!
    static let grassG3Deep = SKColor(hex: "3D7220")!
    static let grassG4Worn = SKColor(hex: "72C440")!
    static let grassEdgeNorth = SKColor(hex: "6EC845")!
    static let grassEdgeSouth = SKColor(hex: "4A8A28")!
    /// G7 / G8 grass↔dirt path framing (dominant grass + earth accent)
    static let grassPathWest = SKColor(hex: "6A9030")!
    static let grassPathEast = SKColor(hex: "5F9828")!

    // Dirt / path (§2.2)
    static let dirtD1 = SKColor(hex: "C4955A")!
    static let dirtD2 = SKColor(hex: "BF8F52")!
    static let dirtD3 = SKColor(hex: "A07840")!
    static let dirtShadow = SKColor(hex: "7A5C2E")!
    static let dirtPathCrack = SKColor(hex: "B8884A")!
    static let dirtGrassEdge = SKColor(hex: "8B6914")!
    static let dirtFootprints = SKColor(hex: "B08A52")!

    // Sidewalk / road (§2.3)
    static let sidewalk1 = SKColor(hex: "BEBEBE")!
    static let sidewalk2 = SKColor(hex: "B8B8B8")!
    static let sidewalkShadow = SKColor(hex: "A0A0A0")!
    static let sidewalkShadowAlt = SKColor(hex: "9A9A9A")!
    static let sidewalkCrack = SKColor(hex: "B4B4B4")!
    static let sidewalkCurb = SKColor(hex: "D0D0D0")!
    static let curbShadow = SKColor(hex: "B0B0B0")!
    static let roadR1 = SKColor(hex: "2E2E32")!
    static let roadR2 = SKColor(hex: "323236")!
    static let roadR1Deep = SKColor(hex: "252528")!
    static let roadR2Deep = SKColor(hex: "282830")!
    static let roadLine = SKColor(hex: "F5F0DC")!
    static let roadWithLine = SKColor(hex: "35353A")!
    static let crosswalkStripe = SKColor(hex: "F5F0DC")!
    static let curbLip = SKColor(hex: "3D3D42")!

    // Water (§2.4)
    static let waterDeep = SKColor(hex: "4A8EC4")!
    static let waterDeepShadow = SKColor(hex: "2E6AA0")!
    static let waterMid = SKColor(hex: "5298CC")!
    static let waterHighlight = SKColor(hex: "76B4D8")!
    static let waterGrassNorthBlend = SKColor(hex: "4E8AB8")!
    static let waterDirtEdgeBlend = SKColor(hex: "4A78A0")!
    static let waterSouthShadow = SKColor(hex: "3D7AB8")!

    // Building brick (Palette A §3.2)
    static let brickWall = SKColor(hex: "C47A52")!
    static let brickShadow = SKColor(hex: "A85F3A")!
    static let brickFaceShadow = SKColor(hex: "7A4028")!
    static let foundation = SKColor(hex: "5A4228")!
    static let roofBrown = SKColor(hex: "6E4C2A")!
    static let windowFrame = SKColor(hex: "3C2E1A")!
    static let windowLit = SKColor(hex: "F0E890")!
    static let windowDark = SKColor(hex: "2A3A4A")!
    static let windowCracked = SKColor(hex: "484848")!
    static let doorWood = SKColor(hex: "5A3E1E")!
    static let doorWoodShadow = SKColor(hex: "3C2810")!
    static let concreteWall = SKColor(hex: "9E9E9E")!
    static let concreteShadow = SKColor(hex: "848484")!
    static let concreteRoof = SKColor(hex: "6A6A6A")!
    static let woodSiding = SKColor(hex: "C4955A")!
    static let woodSidingShadow = SKColor(hex: "A07840")!
    static let acUnit = SKColor(hex: "484848")!
    static let acUnitHi = SKColor(hex: "5A5A5A")!
    static let mailboxBlue = SKColor(hex: "3A5FA0")!
    static let mailboxRust = SKColor(hex: "7A5228")!
    static let graffitiRed = SKColor(hex: "E84040")!
    static let graffitiYellow = SKColor(hex: "E8C040")!
    static let graffitiBlue = SKColor(hex: "40A0E8")!

    // City additions
    static let asphalt1 = SKColor(hex: "2E2E32")!
    static let asphalt2 = SKColor(hex: "323236")!
    static let suitGray = SKColor(hex: "484860")!
    static let urbanBlue = SKColor(hex: "3A5FA0")!

    // Party sprite (Part 4)
    static let shellyGreen = SKColor(hex: "5DA832")!
    static let shellyGreenShadow = SKColor(hex: "3D7220")!
    static let shellyGreenHi = SKColor(hex: "72C440")!
    static let shellyShell = SKColor(hex: "C4955A")!
    static let shellyShellCell = SKColor(hex: "A07840")!
    static let shellyShellRim = SKColor(hex: "7A5C2E")!
    static let shellyShellHi = SKColor(hex: "D4A870")!

    static let spikeBrown = SKColor(hex: "C4853A")!
    static let spikeBrownShadow = SKColor(hex: "8B5C28")!
    static let spikeBrownHi = SKColor(hex: "D4A870")!
    static let spikeSnout = SKColor(hex: "E0B896")!
    static let spikeSpine = SKColor(hex: "484848")!
    static let spikeSpineTip = SKColor(hex: "D0D0D0")!

    static let hazelBrown = SKColor(hex: "8B5C28")!
    static let hazelBrownShadow = SKColor(hex: "5A3A18")!
    static let hazelBrownHi = SKColor(hex: "A07840")!
    static let hazelEar = SKColor(hex: "E8A080")!
    static let hazelTailTip = SKColor(hex: "C4A06A")!
    static let hazelEye = SKColor(hex: "C8880A")!

    static let pipCream = SKColor(hex: "E0C0A0")!
    static let pipCreamShadow = SKColor(hex: "C4A07A")!
    static let pipNose = SKColor(hex: "E86060")!
    static let pipEar = SKColor(hex: "E8A080")!
}
