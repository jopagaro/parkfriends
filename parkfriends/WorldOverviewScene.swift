import SpriteKit

/// World overview: the five real zones, rendered by the ACTUAL scene
/// builders and stacked in true vertical geography (Part 1.1). The map can
/// never drift from the game because it IS the game, miniaturized.
@MainActor
final class WorldOverviewScene: SKScene {
    private let currentZone: GameZone
    private let lockedZones: Set<GameZone>
    private let playerFraction: CGPoint
    private var built = false

    /// Zone renders are expensive (full world build); cache per app run.
    private static var zoneTextures: [GameZone: SKTexture] = [:]

    static let sceneSize = CGSize(width: 1240, height: 1180)

    init(currentZone: GameZone,
         lockedZones: Set<GameZone> = [],
         playerFraction: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.currentZone = currentZone
        self.lockedZones = lockedZones
        self.playerFraction = playerFraction
        super.init(size: Self.sceneSize)
        scaleMode = .aspectFit
        backgroundColor = GamePalette.outline
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        buildOverview(view: view)
        isPaused = true
    }

    // MARK: - Zone renders

    private func builder(_ z: GameZone) -> (SKNode, Int, Int) {
        switch z {
        case .parkNorth:
            return (ParkWorld.buildNorth().root,
                    GameConstants.parkNorthCols, GameConstants.parkNorthRows)
        case .parkCenter:
            return (ParkWorld.buildCenter().root,
                    GameConstants.parkCenterCols, GameConstants.parkCenterRows)
        case .citySouth:
            return (CitySouthWorld.build().root,
                    GameConstants.citySouthCols, GameConstants.citySouthRows)
        case .cityCenter:
            return (CityWorld.build().root,
                    GameConstants.cityCenterCols, GameConstants.cityCenterRows)
        case .cityNorth:
            return (CityNorthWorld.build().root,
                    GameConstants.cityNorthCols, GameConstants.cityNorthRows)
        }
    }

    private func zoneTexture(for zone: GameZone, view: SKView) -> SKTexture? {
        if let cached = Self.zoneTextures[zone] { return cached }
        let (root, cols, rows) = builder(zone)
        // Render at half scale — texture(from:) multiplies by the screen
        // scale, and a full zone at 3x would blow Metal's 8192px cap.
        let half: CGFloat = 0.5
        let tile = GameConstants.tileSize
        let snapScene = SKScene(size: CGSize(width: CGFloat(cols) * tile * half,
                                             height: CGFloat(rows) * tile * half))
        snapScene.backgroundColor = .black
        let holder = SKNode()
        holder.setScale(half)
        holder.addChild(root)
        snapScene.addChild(holder)
        guard let raw = view.texture(from: snapScene) else { return nil }
        // Downsample to ~16px per tile: plenty for the map's density and it
        // keeps the five cached textures at a few MB each, not 60.
        let img = raw.cgImage()
        let targetW = cols * 16
        let f = CGFloat(targetW) / CGFloat(img.width)
        let w = targetW, h = Int(CGFloat(img.height) * f)
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let out = ctx.makeImage() else { return nil }
        let tex = SKTexture(cgImage: out)
        tex.filteringMode = .linear
        Self.zoneTextures[zone] = tex
        return tex
    }

    // MARK: - Layout

    private func buildOverview(view: SKView) {
        let title = SKLabelNode(text: "BELLWETHER WORLD")
        title.fontName = "Helvetica Neue Bold"
        title.fontSize = 30
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height - 26)
        title.verticalAlignmentMode = .top
        addChild(title)

        let subtitle = SKLabelNode(text: "North is up · M or ESC to close")
        subtitle.fontName = "Helvetica Neue"
        subtitle.fontSize = 14
        subtitle.fontColor = SKColor(white: 0.78, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 64)
        subtitle.verticalAlignmentMode = .top
        addChild(subtitle)

        // True vertical stack, north at the top.
        let order: [GameZone] = [.parkNorth, .parkCenter, .citySouth, .cityCenter, .cityNorth]
        let gap: CGFloat = 12
        let topMargin: CGFloat = 96, bottomMargin: CGFloat = 28
        let totalRows = order.reduce(0) { $0 + builderRows($1) }
        let usableH = size.height - topMargin - bottomMargin - gap * CGFloat(order.count - 1)
        let k = usableH / CGFloat(totalRows)          // pt per tile on the map
        let stackCX = size.width * 0.58               // room for chips on the left

        var y = size.height - topMargin               // top edge of next panel
        var panelFrames: [GameZone: CGRect] = [:]

        for zone in order {
            let (cols, rows) = builderDims(zone)
            let w = CGFloat(cols) * k, h = CGFloat(rows) * k
            let frame = CGRect(x: stackCX - w / 2, y: y - h, width: w, height: h)
            panelFrames[zone] = frame

            if let tex = zoneTexture(for: zone, view: view) {
                let sprite = SKSpriteNode(texture: tex, size: frame.size)
                sprite.position = CGPoint(x: frame.midX, y: frame.midY)
                addChild(sprite)
            } else {
                let fallback = SKSpriteNode(color: SKColor(white: 0.12, alpha: 1), size: frame.size)
                fallback.position = CGPoint(x: frame.midX, y: frame.midY)
                addChild(fallback)
            }

            let locked = lockedZones.contains(zone)
            if locked {
                let cover = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6), size: frame.size)
                cover.position = CGPoint(x: frame.midX, y: frame.midY)
                cover.zPosition = 2
                addChild(cover)
            }

            let border = SKShapeNode(rect: frame)
            border.fillColor = .clear
            border.strokeColor = zone == currentZone
                ? SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1)
                : SKColor(white: 1, alpha: 0.22)
            border.lineWidth = zone == currentZone ? 4 : 2
            border.zPosition = 3
            addChild(border)

            addChip(for: zone, frame: frame, locked: locked)
            y -= h + gap
        }

        // N-S path connectors between adjacent zones.
        for i in 0..<(order.count - 1) {
            guard let a = panelFrames[order[i]], let b = panelFrames[order[i + 1]] else { continue }
            let conn = SKSpriteNode(color: SKColor(red: 0.78, green: 0.63, blue: 0.34, alpha: 1),
                                    size: CGSize(width: 18, height: a.minY - b.maxY))
            conn.position = CGPoint(x: stackCX, y: (a.minY + b.maxY) / 2)
            conn.zPosition = -1
            addChild(conn)
        }

        // Player marker on the current zone.
        if let frame = panelFrames[currentZone] {
            let px = frame.minX + frame.width * min(1, max(0, playerFraction.x))
            let py = frame.minY + frame.height * min(1, max(0, playerFraction.y))
            let ring = SKShapeNode(circleOfRadius: 9)
            ring.fillColor = SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1)
            ring.strokeColor = GamePalette.outline
            ring.lineWidth = 3
            ring.position = CGPoint(x: px, y: py)
            ring.zPosition = 5
            addChild(ring)
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = GamePalette.outline
            dot.strokeColor = .clear
            dot.position = ring.position
            dot.zPosition = 6
            addChild(dot)
        }
    }

    private func builderDims(_ z: GameZone) -> (Int, Int) {
        switch z {
        case .parkNorth:  return (GameConstants.parkNorthCols,  GameConstants.parkNorthRows)
        case .parkCenter: return (GameConstants.parkCenterCols, GameConstants.parkCenterRows)
        case .citySouth:  return (GameConstants.citySouthCols,  GameConstants.citySouthRows)
        case .cityCenter: return (GameConstants.cityCenterCols, GameConstants.cityCenterRows)
        case .cityNorth:  return (GameConstants.cityNorthCols,  GameConstants.cityNorthRows)
        }
    }

    private func builderRows(_ z: GameZone) -> Int { builderDims(z).1 }

    private func addChip(for zone: GameZone, frame: CGRect, locked: Bool) {
        let text = locked ? "???" : zone.displayTitle.uppercased()
        let isCurrent = zone == currentZone

        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica Neue Bold"
        label.fontSize = 17
        label.fontColor = isCurrent ? GamePalette.outline : .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .right

        let chipW = label.frame.width + 28
        let chipX = frame.minX - 26
        let chipY = frame.midY
        let bg = SKShapeNode(rectOf: CGSize(width: chipW, height: 32), cornerRadius: 5)
        bg.fillColor = isCurrent
            ? SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1)
            : SKColor(red: 0.10, green: 0.12, blue: 0.10, alpha: 0.92)
        bg.strokeColor = isCurrent ? .clear : SKColor(white: 1, alpha: 0.2)
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: chipX - chipW / 2, y: chipY)
        bg.zPosition = 4
        addChild(bg)

        label.position = CGPoint(x: chipX - 14, y: chipY - 1)
        label.zPosition = 5
        addChild(label)

        // connector from chip to the zone edge
        let line = SKSpriteNode(color: SKColor(white: 1, alpha: 0.35),
                                size: CGSize(width: 24, height: 2))
        line.position = CGPoint(x: frame.minX - 13, y: chipY)
        line.zPosition = 4
        addChild(line)

        if isCurrent && !locked {
            let here = SKLabelNode(text: "YOU ARE HERE")
            here.fontName = "Helvetica Neue Bold"
            here.fontSize = 11
            here.fontColor = SKColor(red: 0.96, green: 0.89, blue: 0.55, alpha: 1)
            here.horizontalAlignmentMode = .right
            here.verticalAlignmentMode = .center
            here.position = CGPoint(x: chipX - 14, y: chipY - 26)
            here.zPosition = 5
            addChild(here)
        }
    }
}
