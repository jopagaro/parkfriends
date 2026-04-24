import SpriteKit

enum BattleBackground {
    case grass
    case fountain
    case forest
    case cityStreet
    case alley

    private var colors: (SKColor, SKColor, SKColor) {
        switch self {
        case .grass:
            return (
                SKColor(red: 0.37, green: 0.66, blue: 0.20, alpha: 0.95),
                SKColor(red: 0.29, green: 0.54, blue: 0.16, alpha: 0.95),
                SKColor(red: 0.45, green: 0.77, blue: 0.25, alpha: 0.30)
            )
        case .fountain:
            return (
                SKColor(red: 0.29, green: 0.56, blue: 0.77, alpha: 0.95),
                SKColor(red: 0.18, green: 0.42, blue: 0.63, alpha: 0.95),
                SKColor(red: 0.86, green: 0.94, blue: 1.0, alpha: 0.18)
            )
        case .forest:
            return (
                SKColor(red: 0.24, green: 0.45, blue: 0.13, alpha: 0.95),
                SKColor(red: 0.16, green: 0.31, blue: 0.09, alpha: 0.95),
                SKColor(red: 0.47, green: 0.78, blue: 0.27, alpha: 0.14)
            )
        case .cityStreet:
            return (
                SKColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 0.97),
                SKColor(red: 0.28, green: 0.28, blue: 0.38, alpha: 0.92),
                SKColor(red: 0.83, green: 0.69, blue: 0.19, alpha: 0.12)
            )
        case .alley:
            return (
                SKColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 0.97),
                SKColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 0.92),
                SKColor(red: 0.95, green: 0.94, blue: 0.86, alpha: 0.08)
            )
        }
    }

    func buildNode(size: CGSize) -> SKNode {
        let node = SKNode()
        let (c1, c2, accent) = colors

        let base = SKSpriteNode(color: c1, size: size)
        base.position = .zero
        node.addChild(base)

        let bandHeight: CGFloat = 26
        let bandCount = Int(ceil(size.height / bandHeight)) + 2
        let bandLayer = SKNode()
        for index in 0..<bandCount {
            let band = SKSpriteNode(
                color: index.isMultiple(of: 2) ? c1 : c2,
                size: CGSize(width: size.width * 1.15, height: bandHeight)
            )
            band.position = CGPoint(
                x: 0,
                y: -size.height / 2 + CGFloat(index) * bandHeight
            )
            band.alpha = 0.65
            bandLayer.addChild(band)
        }
        bandLayer.run(
            .repeatForever(
                .sequence([
                    .moveBy(x: 0, y: -bandHeight, duration: 1.8),
                    .moveBy(x: 0, y: bandHeight, duration: 0)
                ])
            )
        )
        node.addChild(bandLayer)

        let accentLayer = SKNode()
        for index in 0..<6 {
            let blob = SKShapeNode(
                ellipseOf: CGSize(width: 130 + CGFloat(index * 14), height: 36 + CGFloat(index * 8))
            )
            blob.fillColor = accent
            blob.strokeColor = .clear
            blob.position = CGPoint(
                x: -size.width * 0.34 + CGFloat(index) * 58,
                y: size.height * 0.24 - CGFloat(index) * 40
            )
            accentLayer.addChild(blob)
        }
        accentLayer.run(
            .repeatForever(
                .sequence([
                    .moveBy(x: 18, y: 0, duration: 3.0),
                    .moveBy(x: -18, y: 0, duration: 3.0)
                ])
            )
        )
        node.addChild(accentLayer)

        return node
    }
}
