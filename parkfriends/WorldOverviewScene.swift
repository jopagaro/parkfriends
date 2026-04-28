import SpriteKit

@MainActor
final class WorldOverviewScene: SKScene {
    private let currentZone: GameZone
    private var built = false

    init(currentZone: GameZone) {
        self.currentZone = currentZone
        super.init(size: CGSize(width: 1680, height: 1180))
        scaleMode = .aspectFit
        backgroundColor = GamePalette.outline
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        buildOverview()
        isPaused = true
    }

    private struct PreviewSpec {
        let title: String
        let subtitle: String
        let size: CGSize
        let zone: GameZone
        let panelOrigin: CGPoint
        let panelSize: CGSize
    }

    private func buildOverview() {
        let title = SKLabelNode(text: "BELLWETHER WORLD OVERVIEW")
        title.fontName = "Helvetica Neue Bold"
        title.fontSize = 28
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height - 28)
        title.verticalAlignmentMode = .top
        addChild(title)

        let subtitle = SKLabelNode(text: "M or ESC to close · Screenshot this screen for the assembled map")
        subtitle.fontName = "Helvetica Neue"
        subtitle.fontSize = 14
        subtitle.fontColor = SKColor(white: 0.85, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 62)
        subtitle.verticalAlignmentMode = .top
        addChild(subtitle)
        buildCombinedMap()
    }

    private func buildCombinedMap() {
        let mapSize = CGSize(width: 920, height: 980)
        let mapOrigin = CGPoint(x: (size.width - mapSize.width) / 2, y: 80)

        let frame = SKShapeNode(rectOf: mapSize, cornerRadius: 10)
        frame.fillColor = SKColor(red: 0.10, green: 0.12, blue: 0.10, alpha: 1)
        frame.strokeColor = SKColor(white: 1, alpha: 0.12)
        frame.lineWidth = 3
        frame.position = CGPoint(x: mapOrigin.x + mapSize.width / 2, y: mapOrigin.y + mapSize.height / 2)
        addChild(frame)

        let root = SKNode()
        root.position = mapOrigin
        addChild(root)

        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: SKColor, z: CGFloat = 0) {
            let n = SKSpriteNode(color: color, size: CGSize(width: w, height: h))
            n.anchorPoint = .zero
            n.position = CGPoint(x: x, y: y)
            n.zPosition = z
            root.addChild(n)
        }

        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ color: SKColor, width: CGFloat) {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))
            let n = SKShapeNode(path: path)
            n.strokeColor = color
            n.lineWidth = width
            root.addChild(n)
        }

        func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: SKColor, stroke: SKColor? = nil, lineWidth: CGFloat = 0) {
            let n = SKShapeNode(circleOfRadius: radius)
            n.fillColor = color
            n.strokeColor = stroke ?? .clear
            n.lineWidth = lineWidth
            n.position = CGPoint(x: x, y: y)
            root.addChild(n)
        }

        func tree(_ x: CGFloat, _ y: CGFloat, size: CGFloat = 12) {
            rect(x - 2, y - size * 0.9, 4, size * 0.7, SKColor(red: 0.33, green: 0.20, blue: 0.10, alpha: 1), z: 1)
            circle(x, y, size, SKColor(red: 0.18, green: 0.40, blue: 0.14, alpha: 1), stroke: SKColor(red: 0.10, green: 0.24, blue: 0.08, alpha: 1), lineWidth: 2)
        }

        func shrub(_ x: CGFloat, _ y: CGFloat, size: CGFloat = 7) {
            circle(x, y, size, SKColor(red: 0.24, green: 0.48, blue: 0.18, alpha: 1))
        }

        func flower(_ x: CGFloat, _ y: CGFloat) {
            circle(x, y, 2.5, SKColor(red: 0.92, green: 0.72, blue: 0.78, alpha: 1))
            circle(x + 4, y + 1, 2.0, SKColor(red: 0.96, green: 0.84, blue: 0.36, alpha: 1))
            circle(x - 3, y - 1, 1.8, SKColor(red: 0.80, green: 0.90, blue: 0.40, alpha: 1))
        }

        func bench(_ x: CGFloat, _ y: CGFloat) {
            rect(x - 8, y - 2, 16, 4, SKColor(red: 0.60, green: 0.40, blue: 0.22, alpha: 1), z: 1)
            rect(x - 6, y - 8, 2, 6, SKColor(red: 0.33, green: 0.20, blue: 0.10, alpha: 1), z: 1)
            rect(x + 4, y - 8, 2, 6, SKColor(red: 0.33, green: 0.20, blue: 0.10, alpha: 1), z: 1)
        }

        func fencePosts(y: CGFloat, x0: CGFloat, x1: CGFloat, gap: CGFloat = 18) {
            var x = x0
            while x <= x1 {
                rect(x, y, 4, 16, SKColor(red: 0.64, green: 0.52, blue: 0.34, alpha: 1), z: 1)
                x += gap
            }
        }

        func label(_ text: String, _ x: CGFloat, _ y: CGFloat, _ zone: GameZone? = nil) {
            let bg = SKShapeNode(rectOf: CGSize(width: max(90, CGFloat(text.count) * 8), height: 28), cornerRadius: 4)
            bg.fillColor = zone == currentZone ? SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1) : SKColor(red: 0.16, green: 0.18, blue: 0.10, alpha: 0.92)
            bg.strokeColor = zone == currentZone ? SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1) : SKColor(white: 0.8, alpha: 0.15)
            bg.position = CGPoint(x: x, y: y)
            root.addChild(bg)

            let lbl = SKLabelNode(text: text.uppercased())
            lbl.fontName = "Helvetica Neue Bold"
            lbl.fontSize = 16
            lbl.fontColor = zone == currentZone ? GamePalette.outline : .white
            lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: x, y: y - 1)
            root.addChild(lbl)
        }

        let grass = SKColor(red: 0.22, green: 0.45, blue: 0.18, alpha: 1)
        let parkGrass = SKColor(red: 0.28, green: 0.55, blue: 0.22, alpha: 1)
        let dirt = SKColor(red: 0.78, green: 0.63, blue: 0.34, alpha: 1)
        let road = SKColor(red: 0.34, green: 0.34, blue: 0.36, alpha: 1)
        let sidewalk = SKColor(red: 0.64, green: 0.64, blue: 0.62, alpha: 1)
        let water = SKColor(red: 0.20, green: 0.42, blue: 0.62, alpha: 1)
        let city = SKColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1)
        let construction = SKColor(red: 0.47, green: 0.33, blue: 0.18, alpha: 1)
        let building = SKColor(red: 0.55, green: 0.38, blue: 0.25, alpha: 1)
        let hedge = SKColor(red: 0.18, green: 0.34, blue: 0.14, alpha: 1)
        let accent = SKColor(red: 0.90, green: 0.78, blue: 0.34, alpha: 1)
        let parade = SKColor(red: 0.50, green: 0.18, blue: 0.40, alpha: 1)

        // Full backing
        rect(0, 0, mapSize.width, mapSize.height, grass)

        // Suburb top band
        rect(40, 760, 840, 180, parkGrass)
        rect(40, 700, 840, 44, road)
        rect(40, 744, 840, 16, sidewalk)
        rect(40, 684, 840, 16, sidewalk)
        for x in stride(from: CGFloat(80), through: 800, by: 120) {
            rect(x, 790, 64, 70, building)
        }
        rect(90, 865, 120, 70, building)
        rect(70, 770, 170, 150, hedge)
        rect(74, 774, 162, 142, parkGrass)
        rect(88, 785, 100, 85, building)
        rect(196, 805, 42, 52, building)
        rect(78, 778, 18, 108, sidewalk)
        fencePosts(y: 764, x0: 72, x1: 842)
        for x in stride(from: CGFloat(80), through: 820, by: 90) {
            rect(x, 760, 10, 40, sidewalk)
        }
        for x in stride(from: CGFloat(64), through: 856, by: 48) {
            rect(x, 719, 20, 4, accent)
        }
        for x in stride(from: CGFloat(98), through: 818, by: 120) {
            tree(x + 18, 882, size: 12)
            shrub(x + 46, 770, size: 6)
            flower(x + 30, 780)
        }
        tree(300, 905, size: 10)
        tree(710, 905, size: 10)

        // Park middle
        rect(60, 300, 800, 360, parkGrass)
        rect(60, 300, 800, 20, grass)
        rect(60, 640, 800, 20, grass)
        rect(60, 300, 20, 360, grass)
        rect(840, 300, 20, 360, grass)
        // Non-world boundary woods, not playable blank space.
        rect(0, 300, 60, 360, SKColor(red: 0.10, green: 0.27, blue: 0.10, alpha: 1))
        rect(860, 300, 60, 360, SKColor(red: 0.10, green: 0.27, blue: 0.10, alpha: 1))
        rect(0, 760, 40, 180, SKColor(red: 0.10, green: 0.27, blue: 0.10, alpha: 1))
        rect(880, 760, 40, 180, SKColor(red: 0.10, green: 0.27, blue: 0.10, alpha: 1))
        rect(448, 320, 24, 300, dirt)
        rect(250, 430, 360, 22, dirt)
        rect(250, 430, 22, 160, dirt)
        rect(468, 430, 160, 22, dirt)
        rect(650, 430, 22, 110, dirt)
        rect(180, 445, 120, 90, water)
        rect(160, 430, 22, 45, dirt)
        rect(210, 490, 48, 14, sidewalk)
        circle(560, 515, 54, sidewalk, stroke: accent, lineWidth: 5)
        circle(560, 515, 24, water)
        circle(565, 520, 6, accent)
        line(553, 510, 553, 535, accent, width: 3)
        line(560, 510, 560, 540, accent, width: 3)
        line(567, 510, 567, 535, accent, width: 3)
        rect(620, 340, 90, 70, sidewalk)
        circle(665, 370, 16, building, stroke: accent, lineWidth: 3)
        rect(140, 300, 80, 90, grass, z: 1)
        line(860, 520, 860, 360, water, width: 4)
        line(860, 360, 800, 320, water, width: 4)
        line(800, 320, 780, 260, water, width: 4)
        for x in stride(from: CGFloat(110), through: 810, by: 80) {
            circle(x, 610, 6, hedge)
        }
        for x in stride(from: CGFloat(120), through: 760, by: 120) {
            rect(x, 400, 16, 8, building)
        }
        tree(120, 330, size: 22)
        tree(182, 568, size: 11)
        tree(228, 610, size: 10)
        tree(318, 598, size: 10)
        tree(702, 604, size: 10)
        tree(760, 560, size: 11)
        tree(732, 342, size: 10)
        bench(344, 414)
        bench(630, 414)
        bench(610, 334)
        bench(500, 604)
        for p in [(165.0,470.0),(205,560),(250,360),(312,342),(388,592),(450,470),(520,594),(610,600),(710,520),(760,448)] {
            flower(CGFloat(p.0), CGFloat(p.1))
        }
        for p in [(150.0,520.0),(300,520),(350,360),(420,330),(610,350),(690,380),(740,620)] {
            shrub(CGFloat(p.0), CGFloat(p.1))
        }

        // City bottom
        rect(420, 40, 460, 240, city)
        rect(40, 120, 360, 160, construction)
        rect(40, 40, 840, 24, road)
        rect(430, 150, 430, 34, road)
        rect(610, 40, 28, 240, road)
        rect(430, 92, 430, 24, road)
        rect(498, 40, 24, 240, road)
        rect(748, 40, 24, 240, road)
        rect(430, 150, 430, 12, sidewalk)
        rect(430, 184, 430, 12, sidewalk)
        rect(430, 80, 430, 12, sidewalk)
        rect(430, 116, 430, 12, sidewalk)
        rect(594, 40, 12, 240, sidewalk)
        rect(638, 40, 12, 240, sidewalk)
        rect(486, 40, 12, 240, sidewalk)
        rect(522, 40, 12, 240, sidewalk)
        rect(736, 40, 12, 240, sidewalk)
        rect(772, 40, 12, 240, sidewalk)
        for x in stride(from: CGFloat(460), through: 800, by: 84) {
            rect(x, 190, 60, 70, building)
            rect(x, 80, 60, 55, building)
        }
        rect(550, 205, 60, 70, building)
        rect(700, 80, 80, 70, building)
        rect(620, 145, 90, 58, SKColor(red: 0.22, green: 0.30, blue: 0.52, alpha: 1))
        rect(795, 70, 80, 72, SKColor(red: 0.22, green: 0.26, blue: 0.28, alpha: 1))
        for x in stride(from: CGFloat(70), through: 350, by: 70) {
            rect(x, 140, 32, 20, SKColor(red: 0.70, green: 0.52, blue: 0.20, alpha: 1))
        }
        for x in stride(from: CGFloat(470), through: 820, by: 84) {
            tree(x + 18, 138, size: 7)
        }
        bench(520, 205)
        bench(700, 205)
        rect(0, 40, 40, 260, SKColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1))
        rect(880, 40, 40, 260, SKColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1))
        rect(0, 0, 920, 32, parade)
        for x in stride(from: CGFloat(40), through: 880, by: 90) {
            rect(x, 10, 14, 12, accent)
        }
        for x in stride(from: CGFloat(60), through: 860, by: 70) {
            flower(x, 22)
        }

        label("Green Shire Suburb", 680, 915, .citySouth)
        label("Secret Lab House", 178, 930, .citySouth)
        label("Pond", 220, 395, .parkNorth)
        label("Fountain", 560, 375, .parkCenter)
        label("Statue", 665, 320, .parkCenter)
        label("Oak Tree", 150, 320, .parkCenter)
        label("Construction Area", 180, 160, .cityNorth)
        label("City Area", 690, 160, .cityCenter)
        label("Police", 665, 214, .cityCenter)
        label("Development Corp", 812, 110, .cityCenter)
        label("Pride Parade Areas", 510, 16, .cityCenter)
    }

    private func addPanel(for spec: PreviewSpec) {
        let panel = SKShapeNode(rectOf: spec.panelSize, cornerRadius: 8)
        panel.fillColor = SKColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1)
        panel.strokeColor = spec.zone == currentZone
            ? SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1)
            : SKColor(white: 1, alpha: 0.16)
        panel.lineWidth = spec.zone == currentZone ? 5 : 3
        panel.position = CGPoint(x: spec.panelOrigin.x + spec.panelSize.width / 2,
                                 y: spec.panelOrigin.y + spec.panelSize.height / 2)
        addChild(panel)

        let title = SKLabelNode(text: spec.title.uppercased())
        title.fontName = "Helvetica Neue Bold"
        title.fontSize = 18
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .top
        title.position = CGPoint(x: spec.panelOrigin.x + 16, y: spec.panelOrigin.y + spec.panelSize.height - 14)
        addChild(title)

        let subtitle = SKLabelNode(text: spec.subtitle)
        subtitle.fontName = "Helvetica Neue"
        subtitle.fontSize = 11
        subtitle.fontColor = SKColor(white: 0.72, alpha: 1)
        subtitle.horizontalAlignmentMode = .left
        subtitle.verticalAlignmentMode = .top
        subtitle.position = CGPoint(x: spec.panelOrigin.x + 16, y: spec.panelOrigin.y + spec.panelSize.height - 38)
        addChild(subtitle)

        if spec.zone == currentZone {
            let marker = SKLabelNode(text: "CURRENT")
            marker.fontName = "Helvetica Neue Bold"
            marker.fontSize = 12
            marker.fontColor = GamePalette.outline
            marker.horizontalAlignmentMode = .center
            marker.verticalAlignmentMode = .center
            marker.position = CGPoint(x: spec.panelOrigin.x + spec.panelSize.width - 64,
                                      y: spec.panelOrigin.y + spec.panelSize.height - 24)

            let markerBg = SKShapeNode(rectOf: CGSize(width: 94, height: 24), cornerRadius: 4)
            markerBg.fillColor = SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1)
            markerBg.strokeColor = .clear
            markerBg.position = marker.position
            addChild(markerBg)
            addChild(marker)
        }

        let previewContainer = SKNode()
        let inset: CGFloat = 14
        let usableSize = CGSize(width: spec.panelSize.width - inset * 2,
                                height: spec.panelSize.height - 66)
        let scale = min(usableSize.width / spec.size.width, usableSize.height / spec.size.height)
        previewContainer.setScale(scale)
        previewContainer.position = CGPoint(x: spec.panelOrigin.x + inset,
                                            y: spec.panelOrigin.y + 16)
        previewContainer.addChild(buildMinimap(for: spec))
        addChild(previewContainer)
    }

    private func buildMinimap(for spec: PreviewSpec) -> SKNode {
        let root = SKNode()

        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: SKColor, z: CGFloat = 0) {
            let n = SKSpriteNode(color: color, size: CGSize(width: w, height: h))
            n.anchorPoint = .zero
            n.position = CGPoint(x: x, y: y)
            n.zPosition = z
            root.addChild(n)
        }

        func dot(_ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: SKColor) {
            let n = SKShapeNode(circleOfRadius: size / 2)
            n.fillColor = color
            n.strokeColor = .clear
            n.position = CGPoint(x: x, y: y)
            root.addChild(n)
        }

        let w = spec.size.width
        let h = spec.size.height

        switch spec.zone {
        case .parkCenter:
            rect(0, 0, w, h, SKColor(red: 0.82, green: 0.91, blue: 0.52, alpha: 1))
            rect(0, 0, w, GameConstants.tileSize * 2, SKColor(red: 0.76, green: 0.66, blue: 0.46, alpha: 1))
            rect(w * 0.47, 0, GameConstants.tileSize * 2, h * 0.55, SKColor(red: 0.83, green: 0.66, blue: 0.43, alpha: 1))
            rect(w * 0.32, h * 0.50, w * 0.36, GameConstants.tileSize * 2, SKColor(red: 0.83, green: 0.66, blue: 0.43, alpha: 1))
            rect(w * 0.47, h * 0.50, GameConstants.tileSize * 2, h * 0.18, SKColor(red: 0.83, green: 0.66, blue: 0.43, alpha: 1))
            rect(w * 0.42, h * 0.48, w * 0.14, h * 0.14, SKColor(red: 0.72, green: 0.74, blue: 0.74, alpha: 1))
            rect(w * 0.46, h * 0.52, w * 0.06, h * 0.06, SKColor(red: 0.36, green: 0.70, blue: 0.90, alpha: 1), z: 1)
            rect(w * 0.74, h * 0.18, w * 0.16, h * 0.16, SKColor.clear, z: 1)
            for i in 0..<4 {
                rect(w * 0.74, h * 0.18 + CGFloat(i) * h * 0.04, w * 0.16, 6, SKColor(red: 0.69, green: 0.54, blue: 0.39, alpha: 1), z: 1)
            }
            rect(0, 0, GameConstants.tileSize, h, SKColor(red: 0.36, green: 0.59, blue: 0.20, alpha: 1))
            rect(w - GameConstants.tileSize, 0, GameConstants.tileSize, h, SKColor(red: 0.36, green: 0.59, blue: 0.20, alpha: 1))
            dot(w * 0.22, h * 0.34, 18, .orange)
            dot(w * 0.66, h * 0.34, 18, .orange)

        case .parkNorth:
            rect(0, 0, w, h, SKColor(red: 0.82, green: 0.91, blue: 0.52, alpha: 1))
            rect(0, 0, GameConstants.tileSize, h, SKColor(red: 0.36, green: 0.59, blue: 0.20, alpha: 1))
            rect(w - GameConstants.tileSize, 0, GameConstants.tileSize, h, SKColor(red: 0.36, green: 0.59, blue: 0.20, alpha: 1))
            rect(w * 0.06, h * 0.34, w * 0.18, h * 0.20, SKColor(red: 0.48, green: 0.78, blue: 0.88, alpha: 1))
            rect(w * 0.18, h * 0.42, w * 0.08, h * 0.10, SKColor(red: 0.48, green: 0.78, blue: 0.88, alpha: 1))
            rect(w * 0.72, h * 0.18, w * 0.14, h * 0.28, SKColor(red: 0.71, green: 0.57, blue: 0.42, alpha: 1))
            rect(w * 0.38, 0, GameConstants.tileSize * 1.4, h * 0.22, SKColor(red: 0.83, green: 0.66, blue: 0.43, alpha: 1))
            rect(w * 0.26, h * 0.18, w * 0.22, GameConstants.tileSize * 1.4, SKColor(red: 0.83, green: 0.66, blue: 0.43, alpha: 1))
            rect(w * 0.26, h * 0.18, GameConstants.tileSize * 1.2, h * 0.10, SKColor(red: 0.83, green: 0.66, blue: 0.43, alpha: 1))
            dot(w * 0.20, h * 0.30, 16, .orange)
            dot(w * 0.56, h * 0.26, 16, .orange)

        case .citySouth:
            rect(0, 0, w, h, SKColor(red: 0.28, green: 0.31, blue: 0.36, alpha: 1))
            rect(0, 0, w, h * 0.14, SKColor(red: 0.72, green: 0.73, blue: 0.75, alpha: 1))
            rect(0, h * 0.40, w, h * 0.12, SKColor(red: 0.72, green: 0.73, blue: 0.75, alpha: 1))
            rect(0, h * 0.52, w * 0.38, h * 0.28, SKColor(red: 0.73, green: 0.86, blue: 0.56, alpha: 1))
            rect(w * 0.50, h * 0.46, w * 0.30, h * 0.18, SKColor(red: 0.72, green: 0.73, blue: 0.75, alpha: 1))
            let houseColor = SKColor(red: 0.78, green: 0.58, blue: 0.37, alpha: 1)
            rect(w * 0.06, h * 0.56, w * 0.09, h * 0.10, houseColor)
            rect(w * 0.18, h * 0.56, w * 0.09, h * 0.10, houseColor)
            rect(w * 0.30, h * 0.56, w * 0.09, h * 0.10, houseColor)
            rect(w * 0.54, h * 0.52, w * 0.12, h * 0.14, houseColor)
            rect(w * 0.70, h * 0.52, w * 0.12, h * 0.14, houseColor)

        case .cityCenter:
            rect(0, 0, w, h, SKColor(red: 0.28, green: 0.31, blue: 0.36, alpha: 1))
            rect(0, h * 0.42, w, h * 0.16, SKColor(red: 0.54, green: 0.58, blue: 0.63, alpha: 1))
            rect(w * 0.44, 0, w * 0.12, h, SKColor(red: 0.54, green: 0.58, blue: 0.63, alpha: 1))
            rect(w * 0.41, h * 0.42, w * 0.18, h * 0.16, SKColor(red: 0.82, green: 0.82, blue: 0.76, alpha: 1))
            rect(w * 0.06, h * 0.66, w * 0.16, h * 0.14, SKColor(red: 0.77, green: 0.59, blue: 0.40, alpha: 1))
            rect(w * 0.36, h * 0.66, w * 0.20, h * 0.14, SKColor(red: 0.77, green: 0.59, blue: 0.40, alpha: 1))
            rect(w * 0.70, h * 0.66, w * 0.16, h * 0.14, SKColor(red: 0.77, green: 0.59, blue: 0.40, alpha: 1))
            rect(w * 0.06, h * 0.16, w * 0.16, h * 0.14, SKColor(red: 0.77, green: 0.59, blue: 0.40, alpha: 1))
            rect(w * 0.36, h * 0.16, w * 0.20, h * 0.14, SKColor(red: 0.77, green: 0.59, blue: 0.40, alpha: 1))
            rect(w * 0.70, h * 0.16, w * 0.16, h * 0.14, SKColor(red: 0.77, green: 0.59, blue: 0.40, alpha: 1))
            rect(w * 0.30, h * 0.78, w * 0.08, h * 0.08, SKColor(red: 0.73, green: 0.86, blue: 0.56, alpha: 1))
            rect(w * 0.62, h * 0.78, w * 0.08, h * 0.08, SKColor(red: 0.73, green: 0.86, blue: 0.56, alpha: 1))

        case .cityNorth:
            rect(0, 0, w, h, SKColor(red: 0.66, green: 0.52, blue: 0.35, alpha: 1))
            rect(0, 0, w, h * 0.16, SKColor(red: 0.54, green: 0.58, blue: 0.63, alpha: 1))
            rect(0, 0, w * 0.08, h, SKColor(red: 0.73, green: 0.86, blue: 0.56, alpha: 1))
            rect(w * 0.92, 0, w * 0.08, h, SKColor(red: 0.73, green: 0.86, blue: 0.56, alpha: 1))
            let warehouse = SKColor(red: 0.77, green: 0.59, blue: 0.40, alpha: 1)
            rect(w * 0.08, h * 0.56, w * 0.16, h * 0.16, warehouse)
            rect(w * 0.42, h * 0.56, w * 0.20, h * 0.16, warehouse)
            rect(w * 0.76, h * 0.56, w * 0.16, h * 0.16, warehouse)
            rect(w * 0.22, h * 0.20, w * 0.16, h * 0.12, warehouse)
            rect(w * 0.62, h * 0.20, w * 0.16, h * 0.12, warehouse)
        }

        return root
    }
}
