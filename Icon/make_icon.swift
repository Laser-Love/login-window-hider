// Draws the app icon: the menu bar symbol (an app window with a slash) on a macOS-style rounded tile.
// Indigo tile with a white "glass" window. build.sh renders it at every size macOS needs.
// Usage: swiftc -o build/make_icon Icon/make_icon.swift && build/make_icon <size> <out.png>

import AppKit

struct Style {
    let top: NSColor, bottom: NSColor   // tile gradient
    let glyph: NSColor                  // window outline
    let slash: NSColor                  // slash color
    let glass: NSColor?                 // optional fill inside the window
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Indigo tile, white window with a faint glass fill, white slash.
let indigo = Style(top: rgb(129, 120, 255), bottom: rgb(76, 52, 214), glyph: .white, slash: .white, glass: rgb(255, 255, 255, 0.18))

/// Draws one icon into the current context, filling a size×size square (macOS icon grid: 1024 canvas, 824 tile).
func drawIcon(_ s: Style, size: CGFloat) {
    let ctx = NSGraphicsContext.current!.cgContext
    let k = size / 1024
    let tile = NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185 * k, yRadius: 185 * k)

    // Soft drop shadow under the tile, like Apple's icons.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 20 * k
    shadow.shadowOffset = NSSize(width: 0, height: -10 * k)
    shadow.set()
    s.bottom.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: s.top, ending: s.bottom)!.draw(in: shape, angle: -90)

    // The glyph, drawn on the same 18×18 grid as the menu bar icon (y flipped to match its drawing).
    let unit = 30 * k
    let origin = CGPoint(x: tile.midX - 9 * unit, y: tile.midY + 9 * unit)
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: origin.x + x * unit, y: origin.y - y * unit) }

    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    let win = NSRect(x: p(2, 14.5).x, y: p(2, 14.5).y, width: 14 * unit, height: 11 * unit)
    let window = NSBezierPath(roundedRect: win, xRadius: 2 * unit, yRadius: 2 * unit)
    if let glass = s.glass { glass.setFill(); window.fill() }
    window.move(to: p(2, 6.5)); window.line(to: p(16, 6.5))
    window.lineWidth = 1.5 * unit
    s.glyph.setStroke()
    window.stroke()

    let slash = NSBezierPath()
    slash.move(to: p(2.5, 16.5)); slash.line(to: p(15.5, 1.5))
    slash.lineCapStyle = .round
    NSGraphicsContext.current!.compositingOperation = .clear
    slash.lineWidth = 3 * unit   // narrower gap than the menu bar icon, so the window still reads as one shape at large sizes
    slash.stroke()
    NSGraphicsContext.current!.compositingOperation = .sourceOver
    slash.lineWidth = 1.5 * unit
    s.slash.setStroke()
    slash.stroke()
    ctx.endTransparencyLayer()
}

func png(width: Int, height: Int, _ draw: () -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let args = CommandLine.arguments
guard args.count == 3, let size = Int(args[1]) else {
    print("usage: make_icon <size> <out.png>")
    exit(1)
}
try! png(width: size, height: size) { drawIcon(indigo, size: CGFloat(size)) }.write(to: URL(fileURLWithPath: args[2]))
