// Draws docs/demo.gif: an animated illustration of Login Window Hider at login.
// Run with: sh docs/demo/make_demo.sh   (it compiles this together with the app's menu row code)

import AppKit
import ImageIO
import UniformTypeIdentifiers

let W: CGFloat = 960, H: CGFloat = 600
let fps = 12.0, duration = 10.0

// MARK: Helpers

/// Rect from top-left coordinates (the bitmap's origin is bottom-left).
func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x, y: H - y - h, width: w, height: h) }
func clamp(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }
func ease(_ t: CGFloat) -> CGFloat { let x = clamp(t); return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
func prog(_ t: Double, _ a: Double, _ b: Double) -> CGFloat { clamp(CGFloat((t - a) / (b - a))) }
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
func lerpRect(_ a: NSRect, _ b: NSRect, _ t: CGFloat) -> NSRect {
    NSRect(x: lerp(a.minX, b.minX, t), y: lerp(a.minY, b.minY, t), width: lerp(a.width, b.width, t), height: lerp(a.height, b.height, t))
}
func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
func appIcon(_ id: String) -> NSImage {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return NSImage(systemSymbolName: "app", accessibilityDescription: nil)! }
    return NSWorkspace.shared.icon(forFile: url.path)
}
func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSAttributedString {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
}
/// Renders a view into an image (2x for sharpness), in the given appearance.
func snapshot(_ v: NSView, _ mode: NSAppearance.Name) -> NSImage {
    let img = NSImage(size: v.bounds.size)
    NSAppearance(named: mode)!.performAsCurrentDrawingAppearance {
        let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
        v.cacheDisplay(in: v.bounds, to: rep)
        img.addRepresentation(rep)
    }
    return img
}

// MARK: Scene pieces

struct DemoApp { let id: String; let name: String; let frame: NSRect }   // frame in top-left coords
let apps = [
    DemoApp(id: "com.apple.mail", name: "Mail", frame: R(90, 70, 430, 290)),
    DemoApp(id: "com.apple.iCal", name: "Calendar", frame: R(300, 105, 450, 300)),
    DemoApp(id: "com.apple.MobileSMS", name: "Messages", frame: R(560, 64, 330, 260)),
    DemoApp(id: "com.apple.Notes", name: "Notes", frame: R(190, 175, 370, 250)),
]
let dockIDs = ["com.apple.finder"] + apps.map(\.id)
let dockIcon: CGFloat = 50, dockGap: CGFloat = 10, dockPad: CGFloat = 10
let dockW = CGFloat(dockIDs.count) * dockIcon + CGFloat(dockIDs.count - 1) * dockGap + dockPad * 2
let dockRect = R((W - dockW) / 2, H - 8 - 70, dockW, 70)
func dockIconRect(_ i: Int) -> NSRect {
    NSRect(x: dockRect.minX + dockPad + CGFloat(i) * (dockIcon + dockGap), y: dockRect.minY + 13, width: dockIcon, height: dockIcon)
}
let icons = Dictionary(uniqueKeysWithValues: dockIDs.map { ($0, appIcon($0)) })

/// A generic app window: title bar with the three window buttons, the app's icon and name, and placeholder content.
func windowImage(_ app: DemoApp) -> NSImage {
    let size = app.frame.size
    return NSImage(size: size, flipped: false) { _ in
        let body = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 11, yRadius: 11)
        NSColor.white.setFill(); body.fill()
        body.addClip()
        hex(0xF6F6F8).setFill(); NSRect(x: 0, y: 0, width: size.width * 0.3, height: size.height - 32).fill()
        hex(0xECECEF).setFill(); NSRect(x: 0, y: size.height - 32, width: size.width, height: 32).fill()
        for (i, c) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
            hex(UInt32(c)).setFill()
            NSBezierPath(ovalIn: NSRect(x: 14 + CGFloat(i) * 20, y: size.height - 22, width: 12, height: 12)).fill()
        }
        let title = text(app.name, 13, .semibold, hex(0x3A3A3F))
        let tw = title.size().width + 22
        icons[app.id]!.draw(in: NSRect(x: (size.width - tw) / 2, y: size.height - 25, width: 18, height: 18))
        title.draw(at: NSPoint(x: (size.width - tw) / 2 + 22, y: size.height - 24))
        // Placeholder content: sidebar items and text lines.
        for i in 0..<5 {
            hex(0xDCDCE2).setFill()
            NSBezierPath(roundedRect: NSRect(x: 14, y: size.height - 62 - CGFloat(i) * 26, width: size.width * 0.3 - 28, height: 10), xRadius: 5, yRadius: 5).fill()
        }
        for i in 0..<7 {
            let w = (size.width * 0.7 - 40) * [1, 0.85, 0.95, 0.6, 0.9, 0.75, 0.5][i]
            hex(i == 0 ? 0xC9C9D1 : 0xE4E4E9).setFill()
            NSBezierPath(roundedRect: NSRect(x: size.width * 0.3 + 20, y: size.height - 62 - CGFloat(i) * 24, width: w, height: i == 0 ? 14 : 9), xRadius: 4.5, yRadius: 4.5).fill()
        }
        hex(0x000000, 0.08).setStroke(); body.lineWidth = 1; body.stroke()
        return true
    }
}
let windows = apps.map(windowImage)

/// The real Login Window Hider menu, built from the app's own row views.
func menuImage() -> NSImage {
    let rows = apps.map { ($0.id, $0.name) }
    let pad: CGFloat = 6, itemH: CGFloat = 22
    let w = AppRowView.width
    let slider = WatchSliderView()
    let h = pad + 22 + AppRowView.height * CGFloat(rows.count) + slider.frame.height + 11 + itemH * 2 + pad
    let root = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
    root.wantsLayer = true
    root.layer?.backgroundColor = hex(0xF2F1F6).cgColor
    var y = h - pad - 22
    let head = HeaderView(title: "Hide at login"); head.frame.origin.y = y; root.addSubview(head)
    for (id, name) in rows {
        y -= AppRowView.height
        let row = AppRowView(bundleID: id, name: name, showsDivider: true)
        row.frame.origin.y = y; root.addSubview(row)
    }
    y -= slider.frame.height
    slider.frame.origin.y = y; root.addSubview(slider)
    y -= 11
    let sep = NSBox(frame: NSRect(x: 12, y: y + 5, width: w - 24, height: 1)); sep.boxType = .separator; root.addSubview(sep)
    for (t, check, key) in [("Start Login Window Hider at Login", true, ""), ("Quit Login Window Hider", false, "⌘Q")] {
        y -= itemH
        let l = NSTextField(labelWithString: t); l.font = .menuFont(ofSize: 0)
        l.frame = NSRect(x: 22, y: y + 3, width: 232, height: 16); root.addSubview(l)
        if check { let c = NSTextField(labelWithString: "✓"); c.font = .menuFont(ofSize: 0); c.frame = NSRect(x: 8, y: y + 3, width: 14, height: 16); root.addSubview(c) }
        if !key.isEmpty { let k = NSTextField(labelWithString: key); k.font = .menuFont(ofSize: 0); k.textColor = .secondaryLabelColor; k.alignment = .right; k.frame = NSRect(x: w - 60, y: y + 3, width: 46, height: 16); root.addSubview(k) }
    }
    return snapshot(root, .aqua)
}
let menu = menuImage()

func drawMenuBarSymbol(in r: NSRect, color: NSColor) {
    // Same drawing as the app's menu bar icon (18×18 grid), placed in r.
    let s = r.width / 18
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: r.minX + x * s, y: r.maxY - y * s) }
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    let win = NSBezierPath(roundedRect: NSRect(x: p(2, 14.5).x, y: p(2, 14.5).y, width: 14 * s, height: 11 * s), xRadius: 2 * s, yRadius: 2 * s)
    win.move(to: p(2, 6.5)); win.line(to: p(16, 6.5)); win.lineWidth = 1.5 * s
    color.setStroke(); win.stroke()
    let slash = NSBezierPath(); slash.move(to: p(2.5, 16.5)); slash.line(to: p(15.5, 1.5)); slash.lineCapStyle = .round
    NSGraphicsContext.current!.compositingOperation = .clear; slash.lineWidth = 4 * s; slash.stroke()
    NSGraphicsContext.current!.compositingOperation = .sourceOver; slash.lineWidth = 1.5 * s; slash.stroke()
    ctx.endTransparencyLayer()
}

let menuBarH: CGFloat = 26
let symbolRect = R(W - 150, 4, 18, 18)

func drawCursor(at tip: NSPoint) {
    let path = NSBezierPath()
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 17), (4.2, 13), (7, 19.5), (9.6, 18.4), (6.9, 12.2), (12.5, 12.2)]
    for (i, (x, y)) in pts.enumerated() {
        let pt = NSPoint(x: tip.x + x, y: tip.y - y)
        if i == 0 { path.move(to: pt) } else { path.line(to: pt) }
    }
    path.close()
    path.lineJoinStyle = .round
    NSColor.white.setStroke(); path.lineWidth = 2.4; path.stroke()
    NSColor.black.setFill(); path.fill()
}

func drawCaption(_ s: String, alpha: CGFloat) {
    guard alpha > 0.01 else { return }
    let t = text(s, 18, .medium, NSColor.white.withAlphaComponent(alpha))
    let sz = t.size()
    let pill = R((W - sz.width) / 2 - 18, H - 8 - 70 - 58, sz.width + 36, 40)
    hex(0x1B1640, 0.72 * alpha).setFill()
    NSBezierPath(roundedRect: pill, xRadius: 20, yRadius: 20).fill()
    t.draw(at: NSPoint(x: pill.minX + 18, y: pill.midY - sz.height / 2))
}

// MARK: Timeline (seconds)
//  0.0  empty desktop
//  0.5  login windows pop open, one by one
//  3.2  they shrink into the Dock (still running: dots stay)
//  5.2  cursor moves to the menu bar icon and clicks
//  6.0  the menu opens with the list of login apps
//  9.4  fade back to the start for a clean loop

let captions: [(String, Double, Double)] = [
    ("At login, every app opens its window", 0.4, 3.1),
    ("Login Window Hider tucks them away, still running", 3.3, 5.6),
    ("Pick which login apps to hide", 6.0, 9.5),
]

func drawFrame(_ t: Double) {
    // Wallpaper.
    NSGradient(colors: [hex(0x7A6CF5), hex(0xB59AF0), hex(0xE7C6E8)])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    let loopFade = 1 - prog(t, 9.4, 9.9)   // everything that changed fades out at the end

    // Windows: open, then fly into their Dock icon.
    for (i, app) in apps.enumerated() {
        let open = ease(prog(t, 0.5 + Double(i) * 0.45, 0.85 + Double(i) * 0.45))
        let hide = ease(prog(t, 3.2 + Double(i) * 0.12, 3.85 + Double(i) * 0.12))
        guard open > 0, hide < 1 else { continue }
        let full = app.frame
        let grown = full.insetBy(dx: full.width * 0.04 * (1 - open), dy: full.height * 0.04 * (1 - open))
        let target = dockIconRect(i + 1)
        let r = lerpRect(grown, target, hide)
        let alpha = open * (1 - hide * hide)
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.28 * alpha); sh.shadowBlurRadius = 22; sh.shadowOffset = NSSize(width: 0, height: -8)
        sh.set()
        windows[i].draw(in: r, from: .zero, operation: .sourceOver, fraction: alpha)
        NSGraphicsContext.restoreGraphicsState()
    }

    // Menu bar.
    hex(0xF4F1FB, 0.82).setFill(); R(0, 0, W, menuBarH).fill()
    text("Finder", 13, .bold, hex(0x1D1D1F)).draw(at: NSPoint(x: 18, y: H - 20))
    var x: CGFloat = 76
    for item in ["File", "Edit", "View", "Go", "Window", "Help"] {
        let s = text(item, 13, .regular, hex(0x1D1D1F)); s.draw(at: NSPoint(x: x, y: H - 20)); x += s.size().width + 16
    }
    let menuOpen = prog(t, 5.95, 6.1) * loopFade
    if menuOpen > 0 {
        hex(0x000000, 0.12 * menuOpen).setFill()
        NSBezierPath(roundedRect: symbolRect.insetBy(dx: -6, dy: -2), xRadius: 5, yRadius: 5).fill()
    }
    drawMenuBarSymbol(in: symbolRect, color: hex(0x1D1D1F))
    // Battery and clock.
    let bat = R(W - 116, 8, 22, 11)
    hex(0x1D1D1F).setStroke(); let b = NSBezierPath(roundedRect: bat, xRadius: 3, yRadius: 3); b.lineWidth = 1; b.stroke()
    hex(0x1D1D1F).setFill(); NSBezierPath(roundedRect: bat.insetBy(dx: 2, dy: 2).offsetBy(dx: -3, dy: 0).insetBy(dx: 3, dy: 0), xRadius: 1.5, yRadius: 1.5).fill()
    text("Mon 9:41 AM", 13, .regular, hex(0x1D1D1F)).draw(at: NSPoint(x: W - 86, y: H - 20))

    // Dock, with a dot under each running app.
    hex(0xFFFFFF, 0.38).setFill()
    NSBezierPath(roundedRect: dockRect, xRadius: 20, yRadius: 20).fill()
    hex(0xFFFFFF, 0.55).setStroke()
    let dockOutline = NSBezierPath(roundedRect: dockRect, xRadius: 20, yRadius: 20); dockOutline.lineWidth = 1; dockOutline.stroke()
    for (i, id) in dockIDs.enumerated() {
        let r = dockIconRect(i)
        icons[id]!.draw(in: r)
        let running: CGFloat = i == 0 ? 1 : prog(t, 0.5 + Double(i - 1) * 0.45, 0.7 + Double(i - 1) * 0.45) * (i == 0 ? 1 : max(loopFade, 0))
        if running > 0 {
            hex(0x1D1D1F, 0.75 * running).setFill()
            NSBezierPath(ovalIn: NSRect(x: r.midX - 2, y: dockRect.minY + 4, width: 4, height: 4)).fill()
        }
    }

    // The menu.
    if menuOpen > 0 {
        // Like a real menu, it shifts left to stay on screen.
        let mr = NSRect(x: min(symbolRect.minX - 14, W - 8 - menu.size.width), y: H - menuBarH - 4 - menu.size.height, width: menu.size.width, height: menu.size.height)
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.3 * menuOpen); sh.shadowBlurRadius = 20; sh.shadowOffset = NSSize(width: 0, height: -6)
        sh.set()
        let clip = NSBezierPath(roundedRect: mr, xRadius: 10, yRadius: 10)
        hex(0xF2F1F6, menuOpen).setFill(); clip.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: mr, xRadius: 10, yRadius: 10).addClip()
        menu.draw(in: mr, from: .zero, operation: .sourceOver, fraction: menuOpen)
        NSGraphicsContext.restoreGraphicsState()
    }

    // Cursor: glides to the menu bar icon and clicks.
    let cursorIn = prog(t, 5.0, 5.2) * loopFade
    if cursorIn > 0 {
        let move = ease(prog(t, 5.2, 5.85))
        let start = NSPoint(x: W * 0.52, y: H * 0.5), end = NSPoint(x: symbolRect.midX + 2, y: symbolRect.midY - 2)
        drawCursor(at: NSPoint(x: lerp(start.x, end.x, move), y: lerp(start.y, end.y, move)))
    }

    // Captions.
    for (s, a, b) in captions {
        let alpha = min(prog(t, a, a + 0.3), 1 - prog(t, b - 0.3, b))
        drawCaption(s, alpha: alpha)
    }
}

// MARK: Render frames and write the GIF (identical frames are merged into one longer frame)

var frames: [(CGImage, Double)] = []
var lastData: Data?
let frameCount = Int(duration * fps)
for f in 0..<frameCount {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawFrame(Double(f) / fps)
    NSGraphicsContext.restoreGraphicsState()
    let data = Data(bytes: rep.bitmapData!, count: rep.bytesPerRow * rep.pixelsHigh)
    if data == lastData, !frames.isEmpty { frames[frames.count - 1].1 += 1 / fps; continue }
    lastData = data
    frames.append((rep.cgImage!, 1 / fps))
}
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (img, delay) in frames {
    CGImageDestinationAddImage(dest, img, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary)
}
CGImageDestinationFinalize(dest)
print("Wrote \(out.path): \(frames.count) frames")

// Also save a few stills for checking.
if CommandLine.arguments.count > 2 {
    for (i, t) in [1.0, 2.8, 3.6, 5.5, 7.5].enumerated() {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawFrame(t); NSGraphicsContext.restoreGraphicsState()
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2] + "/still-\(i).png"))
    }
}
