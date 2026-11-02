import AppKit

struct Slide: Decodable {
    let out: String
    let image: String?
    let crop: [Double]?      // x, y (from top), w, h in source pixels
    let title: String?
    let body: String?
    let caption: String?
    let footnote: String?
    let center: Bool?
}

let W = 1920.0, H = 1080.0
let bg = NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.14, alpha: 1)
let accent = NSColor(calibratedRed: 0.36, green: 0.80, blue: 0.62, alpha: 1)
let slides = try! JSONDecoder().decode([Slide].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))

func para(_ align: NSTextAlignment, _ spacing: CGFloat = 8) -> NSMutableParagraphStyle {
    let p = NSMutableParagraphStyle(); p.alignment = align; p.lineSpacing = spacing
    p.tabStops = [NSTextTab(textAlignment: .left, location: 70), NSTextTab(textAlignment: .right, location: 900)]
    return p
}
func drawText(_ s: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .white, align: NSTextAlignment = .left, mono: Bool = false) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: para(align)])
    a.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

for s in slides {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    bg.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
    if let ip = s.image, let img = NSImage(contentsOfFile: ip), let r0 = img.representations.first {
        let isz = NSSize(width: r0.pixelsWide, height: r0.pixelsHigh)
        img.size = isz
        let c = s.crop ?? [0, 0, Double(isz.width), Double(isz.height)]
        let src = NSRect(x: c[0], y: Double(isz.height) - c[1] - c[3], width: c[2], height: c[3])
        let capH = 230.0
        let areaW = W - 160, areaH = H - capH - 60
        let scale = min(areaW / c[2], areaH / c[3])
        let dw = c[2] * scale, dh = c[3] * scale
        let dst = NSRect(x: (W - dw) / 2, y: capH + (areaH - dh) / 2 + 30, width: dw, height: dh)
        NSColor(calibratedWhite: 0, alpha: 0.35).setFill()
        NSBezierPath(roundedRect: dst.insetBy(dx: -6, dy: -6).offsetBy(dx: 0, dy: -4), xRadius: 10, yRadius: 10).fill()
        ctx.imageInterpolation = .high
        img.draw(in: dst, from: src, operation: .copy, fraction: 1)
        accent.setFill(); NSRect(x: 80, y: 55, width: 8, height: 130).fill()
        if let cap = s.caption { drawText(cap, NSRect(x: 110, y: 40, width: W - 200, height: capH - 50), size: 40) }
    } else if s.center == true {
        drawText(s.title ?? "", NSRect(x: 100, y: H/2 + 40, width: W - 200, height: 170), size: 130, weight: .bold, align: .center)
        accent.setFill(); NSRect(x: W/2 - 90, y: H/2 + 20, width: 180, height: 10).fill()
        drawText(s.body ?? "", NSRect(x: 100, y: 120, width: W - 200, height: H/2 - 160), size: 52, color: NSColor(calibratedWhite: 0.92, alpha: 1), align: .center)
    } else {
        var y = H - 170.0
        if let t = s.title {
            drawText(t, NSRect(x: 140, y: y - 20, width: W - 280, height: 140), size: 76, weight: .bold)
            accent.setFill(); NSRect(x: 140, y: y - 40, width: 140, height: 8).fill()
            y -= 120
        }
        if let b = s.body {
            drawText(b, NSRect(x: 140, y: 150, width: W - 280, height: y - 170), size: 46, color: NSColor(calibratedWhite: 0.92, alpha: 1))
        }
        if let f = s.footnote {
            drawText(f, NSRect(x: 140, y: 50, width: W - 280, height: 90), size: 28, color: NSColor(calibratedWhite: 0.65, alpha: 1))
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: s.out))
    print("wrote", s.out)
}
