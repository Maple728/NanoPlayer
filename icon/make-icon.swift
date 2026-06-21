import AppKit

// Renders the NanoPlayer app icon at every size macOS needs and writes a
// `.iconset` folder. Run via:  swift make-icon.swift <output.iconset>
// Then:  iconutil -c icns <output.iconset> -o AppIcon.icns

func renderIcon(pixels: Int) -> Data {
    let s = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Rounded-square "squircle" container with macOS-like proportions.
    let pad = s * 0.06
    let rect = CGRect(x: pad, y: pad, width: s - 2 * pad, height: s - 2 * pad)
    let radius = rect.width * 0.2237
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    ctx.saveGState()
    squircle.addClip()

    // Vivid diagonal gradient (indigo -> magenta -> amber) — the "Vivid"/HDR feel.
    let colors = [
        NSColor(srgbRed: 0.42, green: 0.18, blue: 0.97, alpha: 1).cgColor,
        NSColor(srgbRed: 0.92, green: 0.16, blue: 0.58, alpha: 1).cgColor,
        NSColor(srgbRed: 1.00, green: 0.58, blue: 0.20, alpha: 1).cgColor,
    ]
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors as CFArray, locations: [0.0, 0.55, 1.0])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

    // Soft radial sheen near the top for depth.
    let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor(white: 1, alpha: 0.28).cgColor,
                                    NSColor(white: 1, alpha: 0.0).cgColor] as CFArray,
                           locations: [0.0, 1.0])!
    ctx.drawRadialGradient(sheen,
                           startCenter: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12),
                           startRadius: 0,
                           endCenter: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12),
                           endRadius: rect.width * 0.7, options: [])
    ctx.restoreGState()

    // White play triangle, centered, with rounded corners and a soft shadow.
    let cx = s / 2, cy = s / 2
    let r = s * 0.24
    let tri = NSBezierPath()
    tri.move(to: CGPoint(x: cx - r * 0.55, y: cy - r * 0.92))
    tri.line(to: CGPoint(x: cx - r * 0.55, y: cy + r * 0.92))
    tri.line(to: CGPoint(x: cx + r * 1.00, y: cy))
    tri.close()
    tri.lineJoinStyle = .round
    tri.lineWidth = s * 0.05

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                  blur: s * 0.03,
                  color: NSColor(white: 0, alpha: 0.25).cgColor)
    NSColor.white.setFill()
    NSColor.white.setStroke()
    tri.fill()
    tri.stroke()   // round-joined stroke softens the triangle tips
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// --- main ---
let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "NanoPlayer.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (filename, pixel size) entries required by iconutil.
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in entries {
    let data = renderIcon(pixels: px)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(name) (\(px)px)")
}
print("done: \(outDir)")
