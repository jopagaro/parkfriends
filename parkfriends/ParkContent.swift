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

    /// EarthBound HDMA-style animated background: per-scanline sine
    /// distortion over a wobbly procedural plaid, with slow palette cycling.
    /// `intense` (bosses) cranks amplitude, speed and the accent sweep —
    /// distortion telegraphs threat (handoff §2.5).
    func buildNode(size: CGSize, intense: Bool = false) -> SKNode {
        let (c1, c2, accent) = colors
        let sprite = SKSpriteNode(texture: BattleBackground.whiteTexture, size: size)
        sprite.color = c1
        sprite.shader = BattleBackground.distortionShader
        func rgb(_ c: SKColor) -> vector_float3 {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            return vector_float3(Float(r), Float(g), Float(b))
        }
        sprite.setValue(SKAttributeValue(vectorFloat3: rgb(c1)), forAttribute: "a_c1")
        sprite.setValue(SKAttributeValue(vectorFloat3: rgb(c2)), forAttribute: "a_c2")
        sprite.setValue(SKAttributeValue(vectorFloat3: rgb(accent)), forAttribute: "a_c3")
        sprite.setValue(SKAttributeValue(float: intense ? 1.0 : 0.0), forAttribute: "a_boss")
        return sprite
    }

    /// Plain white texture so the shader gets well-defined v_tex_coord.
    private static let whiteTexture: SKTexture = {
        let side = 4
        let ctx = CGContext(data: nil, width: side, height: side,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return SKTexture(cgImage: ctx.makeImage()!)
    }()

    /// One compiled shader shared by every battle; per-battle values ride
    /// on attributes so recompilation never happens mid-session.
    private static let distortionShader: SKShader = {
        let src = """
        void main() {
            float boss = a_boss;
            float t = u_time * (0.55 + 0.75 * boss);
            vec2 uv = v_tex_coord;
            // per-scanline horizontal waves: one broad, one interlaced
            float amp  = 0.012 + 0.03 * boss;
            float iamp = 0.006 + 0.018 * boss;
            float wave  = amp * sin(uv.y * (9.0 + 5.0 * boss) + t * 2.3);
            float phase = mod(floor(uv.y * 224.0), 2.0) * 2.0 - 1.0;
            float ilace = iamp * phase * sin(uv.y * 23.0 - t * 2.9);
            float x = uv.x + wave + ilace + t * 0.02;
            float y = uv.y + (0.01 + 0.02 * boss) * sin(t * 0.8) + t * 0.012;
            // wobbly plaid
            float a = sin((x * 3.0 + 0.14 * sin(y * 9.0 + t * 0.7)) * 6.2831);
            float b = sin((y * 2.2 + 0.16 * sin(x * 7.0 - t * 0.5)) * 6.2831);
            float m = a * b;
            float band = smoothstep(-0.25, 0.25, m);
            // slow palette cycle + accent sweep on the pattern ridges
            float cyc = 0.5 + 0.5 * sin(t * (0.6 + 0.9 * boss) + (a + b) * 1.6);
            vec3 col = mix(a_c1, a_c2, band);
            col = mix(col, a_c3, (0.35 + 0.4 * boss) * cyc * smoothstep(0.55, 1.0, abs(m)));
            gl_FragColor = vec4(col, 1.0) * v_color_mix.a;
        }
        """
        let shader = SKShader(source: src)
        shader.attributes = [
            SKAttribute(name: "a_c1", type: .vectorFloat3),
            SKAttribute(name: "a_c2", type: .vectorFloat3),
            SKAttribute(name: "a_c3", type: .vectorFloat3),
            SKAttribute(name: "a_boss", type: .float)
        ]
        return shader
    }()
}
