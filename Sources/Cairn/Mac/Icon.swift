#if os(macOS)
import AppKit
import Foundation

/// The app icon, drawn by the app itself: an ink-wash peak on sand-white
/// paper, a cairn of ink stones in front, the top stone chalk-bag red.
enum Icon {
    private static let sizes: [(name: String, px: Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    static func writeIconset(to path: String) {
        let dir = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, px) in sizes {
            guard let png = render(px: px) else { continue }
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }
        FileHandle.standardOutput.write(Data("wrote \(sizes.count) sizes to \(path)\n".utf8))
    }

    /// iOS wants a square, opaque, full-bleed 1024 px icon; it rounds the corners itself.
    static func writeIOSIcon(to path: String) {
        guard let png = render(px: 1024, fullBleed: true) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardOutput.write(Data("wrote iOS icon to \(path)\n".utf8))
    }

    static func render(px: Int, fullBleed: Bool = false) -> Data? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext
        let s = CGFloat(px)
        let inset = fullBleed ? 0 : s * 0.09
        let body = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let radius = fullBleed ? 0 : body.width * 0.225

        func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
            CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
        }

        // Drop shadow + paper
        ctx.saveGState()
        if !fullBleed { ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: rgb(0x2B3540, 0.28)) }
        let tile = CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.addPath(tile); ctx.setFillColor(rgb(0xF4EFE6)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(tile); ctx.clip()
        let paper = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [rgb(0xFCFAF6), rgb(0xEDE4D3)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(paper, start: CGPoint(x: body.midX, y: body.maxY), end: CGPoint(x: body.midX, y: body.minY), options: [])

        // Peak (y up in CG): a wash with brush streaks down from the ridge.
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: body.minX + body.width * x, y: body.minY + body.height * y) }
        let ridge = [P(-0.02, 0.36), P(0.16, 0.48), P(0.30, 0.58), P(0.42, 0.72), P(0.52, 0.86), P(0.60, 0.74),
                     P(0.70, 0.66), P(0.78, 0.70), P(0.90, 0.56), P(1.02, 0.46)]
        let mass = CGMutablePath()
        mass.move(to: P(-0.02, 0.2)); for p in ridge { mass.addLine(to: p) }; mass.addLine(to: P(1.02, 0.2)); mass.closeSubpath()
        ctx.saveGState()
        ctx.addPath(mass); ctx.clip()
        let wash = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [rgb(0x2B3540, 0.55), rgb(0x2B3540, 0.0)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(wash, start: P(0.5, 0.86), end: P(0.5, 0.32), options: [])
        var rng = SeededRandom(seed: 11)
        ctx.setLineCap(.round)
        for _ in 0..<(px >= 256 ? 90 : 30) {
            let ux = CGFloat(rng.next(0.05, 0.95))
            var top: CGFloat = 0.3
            for (a, b) in zip(ridge, ridge.dropFirst()) where P(ux, 0).x >= a.x && P(ux, 0).x <= b.x {
                top = a.y + (b.y - a.y) * (P(ux, 0).x - a.x) / (b.x - a.x)
            }
            let len = body.height * CGFloat(rng.next(0.06, 0.28))
            ctx.setStrokeColor(rgb(0x2B3540, CGFloat(rng.next(0.08, 0.4))))
            ctx.setLineWidth(max(0.5, s * CGFloat(rng.next(0.002, 0.009))))
            ctx.move(to: CGPoint(x: P(ux, 0).x, y: top))
            ctx.addLine(to: CGPoint(x: P(ux, 0).x + len * CGFloat(rng.next(-0.15, 0.15)), y: top - len))
            ctx.strokePath()
        }
        ctx.restoreGState()
        let ridgePath = CGMutablePath(); ridgePath.addLines(between: ridge)
        ctx.addPath(ridgePath); ctx.setStrokeColor(rgb(0x2B3540, 0.8)); ctx.setLineWidth(max(1, s * 0.006)); ctx.strokePath()

        // Snow in front
        let snow = CGMutablePath()
        snow.move(to: P(-0.02, 0.0)); snow.addLine(to: P(-0.02, 0.26)); snow.addCurve(to: P(1.02, 0.30), control1: P(0.3, 0.36), control2: P(0.7, 0.22))
        snow.addLine(to: P(1.02, 0.0)); snow.closeSubpath()
        ctx.addPath(snow); ctx.setFillColor(rgb(0xF7F3EC)); ctx.fillPath()

        // The cairn
        let stones: [(CGFloat, CGFloat, CGFloat, CGFloat, UInt32)] = [
            (0.50, 0.19, 0.40, 0.11, 0x1F1C19), (0.48, 0.295, 0.31, 0.095, 0x1F1C19),
            (0.52, 0.385, 0.23, 0.08, 0x1F1C19), (0.50, 0.462, 0.15, 0.07, 0xD3392B),
        ]
        for st in stones {
            let r = CGRect(x: body.minX + body.width * (st.0 - st.2 / 2), y: body.minY + body.height * (st.1 - st.3 / 2),
                           width: body.width * st.2, height: body.height * st.3)
            ctx.addEllipse(in: r); ctx.setFillColor(rgb(st.4)); ctx.fillPath()
        }
        ctx.restoreGState()

        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}

#endif
