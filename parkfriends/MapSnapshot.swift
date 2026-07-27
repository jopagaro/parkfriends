import SpriteKit

// Debug utility: if /tmp/pf-render-maps.txt exists (containing an output
// directory path), render every zone's full layout to PNG via the REAL
// scene builders and exit. Used to audit map layout without playing.
@MainActor
enum MapSnapshot {

    static func runIfRequested() {
        // Sandbox-safe: trigger + output live in the app container's tmp.
        let tmp = NSTemporaryDirectory()
        let triggerPath = tmp + "pf-render-maps.txt"
        guard FileManager.default.fileExists(atPath: triggerPath) else { return }
        try? FileManager.default.removeItem(atPath: triggerPath)
        let dir = tmp + "pf-maps"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 512, height: 512))

        func snap(_ name: String, _ root: SKNode, cols: Int, rows: Int) {
            let tile = GameConstants.tileSize
            let scene = SKScene(size: CGSize(width: CGFloat(cols) * tile,
                                             height: CGFloat(rows) * tile))
            scene.backgroundColor = .black
            scene.addChild(root)
            guard let tex = view.texture(from: scene) else {
                FileHandle.standardError.write("snapshot FAILED \(name)\n".data(using: .utf8)!)
                return
            }
            let img = tex.cgImage()
            // downscale 1/3 for reviewable file sizes
            let w = img.width / 3, h = img.height / 3
            guard let ctx = CGContext(data: nil, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            ctx.interpolationQuality = .medium
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let out = ctx.makeImage(),
                  let dest = CGImageDestinationCreateWithURL(
                    URL(fileURLWithPath: "\(dir)/\(name).png") as CFURL,
                    "public.png" as CFString, 1, nil)
            else { return }
            CGImageDestinationAddImage(dest, out, nil)
            CGImageDestinationFinalize(dest)
            FileHandle.standardError.write("snapshot wrote \(name)\n".data(using: .utf8)!)
        }

        snap("zone-park", ParkWorld.buildCenter().root,
             cols: GameConstants.parkCenterCols, rows: GameConstants.parkCenterRows)
        snap("zone-suburb", ParkWorld.buildNorth().root,
             cols: GameConstants.parkNorthCols, rows: GameConstants.parkNorthRows)
        snap("zone-citysouth", CitySouthWorld.build().root,
             cols: GameConstants.citySouthCols, rows: GameConstants.citySouthRows)
        snap("zone-citycenter", CityWorld.build().root,
             cols: GameConstants.cityCenterCols, rows: GameConstants.cityCenterRows)
        snap("zone-construction", CityNorthWorld.build().root,
             cols: GameConstants.cityNorthCols, rows: GameConstants.cityNorthRows)
        snap("interior-house-a", InteriorWorld.buildHouse(seed: 0).root, cols: 16, rows: 11)
        snap("interior-house-b", InteriorWorld.buildHouse(seed: 1).root, cols: 16, rows: 11)
        snap("interior-lab", InteriorWorld.buildLab().root, cols: 26, rows: 16)
        snap("interior-cafe", InteriorWorld.buildCafe().root, cols: 18, rows: 12)
        snap("interior-store", InteriorWorld.buildStore().root, cols: 18, rows: 12)
        snap("interior-hospital", InteriorWorld.buildHospital().root, cols: 20, rows: 12)
        snap("interior-police", InteriorWorld.buildPolice().root, cols: 18, rows: 12)
        snap("interior-apartment", InteriorWorld.buildApartment().root, cols: 14, rows: 10)
        exit(0)
    }
}
