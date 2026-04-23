import SpriteKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Renders emoji / text glyphs into SKTextures so we have nice-looking
/// placeholder sprites until real pixel art is ready.
enum SpriteFactory {
    private static var cache: [String: SKTexture] = [:]

    static func emojiTexture(_ glyph: String, size: CGFloat = 64) -> SKTexture {
        let key = "\(glyph)@\(size)"
        if let cached = cache[key] { return cached }

        let pixelSize = CGSize(width: size, height: size)
        let texture = SKTexture(image: renderEmoji(glyph, size: pixelSize))
        texture.filteringMode = .nearest
        cache[key] = texture
        return texture
    }

    // MARK: - Platform-specific rendering

#if canImport(UIKit)
    private static func renderEmoji(_ glyph: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width * 0.8),
                .paragraphStyle: paragraph
            ]
            let str = NSAttributedString(string: glyph, attributes: attrs)
            let lineSize = str.size()
            let rect = CGRect(
                x: 0,
                y: (size.height - lineSize.height) / 2,
                width: size.width,
                height: lineSize.height
            )
            str.draw(in: rect)
        }
    }

#elseif canImport(AppKit)
    private static func renderEmoji(_ glyph: String, size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size.width * 0.8),
            .paragraphStyle: paragraph
        ]
        let str = NSAttributedString(string: glyph, attributes: attrs)
        let lineSize = str.size()
        let rect = CGRect(
            x: 0,
            y: (size.height - lineSize.height) / 2,
            width: size.width,
            height: lineSize.height
        )
        str.draw(in: rect)
        image.unlockFocus()
        return image
    }
#endif
}
