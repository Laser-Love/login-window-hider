// Renders docs/menu.png, the README screenshot of the menu in light and dark mode.
// It's appended to the app's own code by make_screenshot.sh, so it uses the app's real row, heading and slider views.

let shotApps = [("com.automattic.beeper.desktop", "Beeper"), ("com.apple.iCal", "Calendar"), ("com.apple.mail", "Mail"),
                ("com.apple.MobileSMS", "Messages"), ("com.tinyspeck.slackmacgap", "Slack")]

/// An "on" switch as it looks in the open menu (system blue). A command-line render can't become the active app,
/// so real switches would draw gray here; each one is swapped for this drawing, at the same size and place.
final class OnSwitchView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let r = bounds.insetBy(dx: 0.5, dy: 0.5), radius = r.height / 2
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
        let d = r.height - 2
        let knob = NSRect(x: r.maxX - 1 - d, y: r.minY + 1, width: d, height: d)
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.25); sh.shadowBlurRadius = 1.5; sh.shadowOffset = NSSize(width: 0, height: -0.5); sh.set()
        (dark ? NSColor(white: 0.85, alpha: 1) : NSColor.white).setFill()
        NSBezierPath(ovalIn: knob).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
func swapSwitches(in view: NSView) {
    for sub in view.subviews {
        if let toggle = sub as? NSSwitch {
            let drawn = OnSwitchView(frame: toggle.frame)
            view.replaceSubview(toggle, with: drawn)
        } else {
            swapSwitches(in: sub)
        }
    }
}

/// The menu's contents, built from the app's own views.
func menuPanel(_ mode: NSAppearance.Name) -> NSImage {
    let w = AppRowView.width, pad: CGFloat = 6, itemH: CGFloat = 22
    let slider = WatchSliderView()
    let h = pad + 22 + AppRowView.height * CGFloat(shotApps.count) + slider.frame.height + 11 + itemH * 2 + pad
    let root = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
    var y = h - pad - 22
    let head = HeaderView(title: "Hide at login"); head.frame.origin.y = y; root.addSubview(head)
    for (id, name) in shotApps {
        y -= AppRowView.height
        let row = AppRowView(bundleID: id, name: name, showsDivider: true)
        swapSwitches(in: row)
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
    let win = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: w, height: h), styleMask: [.borderless], backing: .buffered, defer: false)
    win.appearance = NSAppearance(named: mode)
    win.isOpaque = false
    win.backgroundColor = .clear
    win.contentView = root
    root.layoutSubtreeIfNeeded()
    var img = NSImage()
    NSAppearance(named: mode)!.performAsCurrentDrawingAppearance {
        let rep = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
        root.cacheDisplay(in: root.bounds, to: rep)
        img = NSImage(size: root.bounds.size)
        img.addRepresentation(rep)
    }
    win.orderOut(nil)
    return img
}

NSApplication.shared.setActivationPolicy(.accessory)
let light = menuPanel(.aqua), dark = menuPanel(.darkAqua)
let panelW = AppRowView.width, panelH = light.size.height
let margin: CGFloat = 40, gap: CGFloat = 40
let canvas = NSSize(width: panelW * 2 + gap + margin * 2, height: panelH + margin * 2)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * 2), pixelsHigh: Int(canvas.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = canvas
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill(); NSRect(origin: .zero, size: canvas).fill()
for (i, (img, bg)) in [(light, NSColor(white: 0.84, alpha: 1)), (dark, NSColor(white: 0.27, alpha: 1))].enumerated() {
    let r = NSRect(x: margin + CGFloat(i) * (panelW + gap), y: margin, width: panelW, height: panelH)
    let shape = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.22); sh.shadowBlurRadius = 18; sh.shadowOffset = NSSize(width: 0, height: -6); sh.set()
    bg.setFill(); shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    img.draw(in: r)
    NSGraphicsContext.restoreGraphicsState()
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
