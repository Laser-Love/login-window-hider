// Login Window Hider, by Alex Olmsted (alexolmsted.com). MIT License.
//
// A menu bar app that hides the windows of apps that open when you log in.
// The apps keep running; click an app's Dock icon to bring its windows back.
// The menu lists the apps in macOS's Login Items that have windows, each with a switch: on = hide it at login.

import AppKit
import ServiceManagement

// MARK: - Settings

enum Settings {
    private static let d = UserDefaults.standard
    /// The last Login Items read: bundle ID -> name. Kept so the menu can open instantly.
    static var loginApps: [String: String] {
        get { d.dictionary(forKey: "loginApps") as? [String: String] ?? [:] }
        set { d.set(newValue, forKey: "loginApps") }
    }
    /// Early development builds used the ID "local.loginhider". Carry their settings over once.
    static func migrateFromDevBuild() {
        guard !d.bool(forKey: "migratedDevSettings") else { return }
        d.set(true, forKey: "migratedDevSettings")
        guard let old = UserDefaults(suiteName: "local.loginhider") else { return }
        for key in ["neverHide", "loginApps", "startAtLogin"] {
            if let value = old.object(forKey: key), d.object(forKey: key) == nil { d.set(value, forKey: key) }
        }
    }
    /// Bundle IDs switched off (never hidden).
    static var neverHide: Set<String> {
        get { Set(d.stringArray(forKey: "neverHide") ?? []) }
        set { d.set(Array(newValue).sorted(), forKey: "neverHide") }
    }
}

// MARK: - Login time

enum Session {
    /// When the current user logged in at the console, or the boot time if that can't be found.
    static func loginDate() -> Date? {
        var latest: Date?
        setutxent()
        while let p = getutxent() {
            var e = p.pointee
            guard e.ut_type == USER_PROCESS else { continue }
            let user = withUnsafeBytes(of: &e.ut_user) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
            let line = withUnsafeBytes(of: &e.ut_line) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
            guard user == NSUserName(), line == "console" else { continue }
            let date = Date(timeIntervalSince1970: TimeInterval(e.ut_tv.tv_sec))
            if latest == nil || date > latest! { latest = date }
        }
        endutxent()
        return latest ?? bootDate()
    }

    static func bootDate() -> Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec))
    }
}

// MARK: - macOS Login Items

/// Reads the "Open at Login" list from System Settings → General → Login Items, through System Events.
/// No password needed; macOS asks once for permission to control System Events.
enum LoginItems {
    /// Apps with windows that macOS opens at login: bundle ID -> name. Nil if the list couldn't be read.
    static func read() -> [String: String]? {
        let script = NSAppleScript(source: "tell application \"System Events\" to get the path of every login item")
        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error), error == nil else { return nil }
        var paths: [String] = []
        if result.numberOfItems == 0, let one = result.stringValue { paths = [one] }
        for i in stride(from: 1, through: result.numberOfItems, by: 1) {
            if let p = result.atIndex(i)?.stringValue { paths.append(p) }
        }
        var apps: [String: String] = [:]
        for path in paths {
            guard let bundle = Bundle(path: path), let id = bundle.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier, let name = windowAppName(bundle) else { continue }
            apps[id] = name
        }
        return apps
    }

    /// The app's name if it has windows (not a menu bar or background-only app).
    static func windowAppName(_ bundle: Bundle) -> String? {
        let info = bundle.infoDictionary ?? [:]
        func isOn(_ key: String) -> Bool { (info[key] as? Bool) == true || (info[key] as? String) == "1" }
        if isOn("LSUIElement") || isOn("LSBackgroundOnly") { return nil }
        let fallback = bundle.bundleURL.deletingPathExtension().lastPathComponent
        let name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? fallback
        return name.isEmpty ? fallback : name
    }
}

// MARK: - One row in the menu: icon, name, switch

final class AppRowView: NSView {
    let bundleID: String

    /// Row layout. The icon's left edge and the switch's right edge sit the same distance from the menu's edges.
    static let width: CGFloat = 260
    static let height: CGFloat = 38
    static let edge: CGFloat = 14
    static let iconSize: CGFloat = 22

    init(bundleID: String, name: String, showsDivider: Bool) {
        self.bundleID = bundleID
        let w = AppRowView.width, h = AppRowView.height, edge = AppRowView.edge, iconSize = AppRowView.iconSize
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: h))
        autoresizingMask = [.width]

        // App icons have about 1 pt of transparent margin built in, so start 1 pt early to make the visible gaps match.
        let icon = NSImageView(frame: NSRect(x: edge - 1, y: (h - iconSize) / 2, width: iconSize, height: iconSize))
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon.image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon.image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)

        let toggle = NSSwitch()
        toggle.controlSize = .mini
        let ts = toggle.fittingSize
        toggle.frame = NSRect(x: w - edge - ts.width, y: ((h - ts.height) / 2).rounded(), width: ts.width, height: ts.height)
        toggle.autoresizingMask = [.minXMargin]

        let textX = edge + iconSize + 10
        let label = NSTextField(labelWithString: name)
        label.font = .menuFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingTail
        let lh = label.fittingSize.height
        label.frame = NSRect(x: textX, y: ((h - lh) / 2).rounded(), width: toggle.frame.minX - 10 - textX, height: lh)
        label.autoresizingMask = [.width]
        addSubview(label)

        // Hairline between rows, from the text to the switch's right edge (like System Settings).
        if showsDivider {
            let line = NSBox(frame: NSRect(x: textX, y: 0, width: w - edge - textX, height: 1))
            line.boxType = .separator
            line.autoresizingMask = [.width]
            addSubview(line)
        }

        toggle.state = Settings.neverHide.contains(bundleID) ? .off : .on
        toggle.target = self
        toggle.action = #selector(switched(_:))
        toggle.setAccessibilityLabel("Hide \(name) at login")
        addSubview(toggle)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc func switched(_ sender: NSSwitch) {
        var set = Settings.neverHide
        if sender.state == .on { set.remove(bundleID) } else { set.insert(bundleID) }
        Settings.neverHide = set
    }
}

// MARK: - The "Hide at login" heading, lined up with the left edge of the app icons

final class HeaderView: NSView {
    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: AppRowView.width, height: 22))
        autoresizingMask = [.width]
        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 0)
        label.textColor = .disabledControlTextColor   // same look as a standard disabled menu heading
        let h = label.fittingSize.height
        // Text fields inset their text by 2 pt, so start 2 pt early to line the "H" up with the icons' visible edge.
        label.frame = NSRect(x: AppRowView.edge - 2, y: ((22 - h) / 2).rounded(), width: AppRowView.width - 2 * AppRowView.edge, height: h)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// If Login Window Hider starts within this long after login, it treats it as a startup.
    let loginGrace: TimeInterval = 5 * 60
    /// How long to wait after starting before hiding anything.
    let startDelay: TimeInterval = 5
    /// Login apps are kept hidden until this long after Login Window Hider starts (about 1 minute after login).
    let watchWindow: TimeInterval = 60
    /// An app that comes forward within this long after a click or key press counts as opened by you.
    let userActionWindow: TimeInterval = 1.5

    let started = Date()
    var statusItem: NSStatusItem!
    var sweepTimer: Timer?
    /// Bundle IDs of the apps in macOS's Login Items. Nil until read (or if it can't be read).
    var loginIDs: Set<String>?
    /// The first click or key press after login. Used only if Login Items can't be read:
    /// then apps that started before it count as login apps.
    var firstInput: Date?
    /// Login apps you brought forward yourself; they're left alone from then on.
    var yours: Set<pid_t> = []

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = AppDelegate.menuBarIcon()
            button.image?.accessibilityDescription = "Login Window Hider"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        Settings.migrateFromDevBuild()

        // Start at login (on by default). Registering on every launch keeps the login item
        // pointing at this copy of the app, even after it's renamed or moved.
        if UserDefaults.standard.object(forKey: "startAtLogin") as? Bool ?? true {
            try? SMAppService.mainApp.register()
        }

        let forced = ProcessInfo.processInfo.environment["LOGINHIDER_FORCE_STARTUP"] == "1"
        let sinceLogin = Session.loginDate().map { Date().timeIntervalSince($0) } ?? .infinity
        if forced || sinceLogin < loginGrace {
            startWatching()
        }
        refreshLoginItems()
    }

    /// Reads Login Items (takes a moment) and saves them for the menu and for hiding.
    func refreshLoginItems() {
        guard let apps = LoginItems.read() else { return }
        Settings.loginApps = apps
        loginIDs = Set(apps.keys)
    }

    /// Menu bar icon: an app window with a slash through it. 18×18 pt, the standard menu bar icon size.
    /// A template image, so macOS colors it to match the menu bar (black or white).
    static func menuBarIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let window = NSBezierPath(roundedRect: NSRect(x: 2, y: 3.5, width: 14, height: 11), xRadius: 2, yRadius: 2)
            window.move(to: NSPoint(x: 2, y: 6.5))
            window.line(to: NSPoint(x: 16, y: 6.5))
            window.lineWidth = 1.5
            NSColor.black.setStroke()
            window.stroke()

            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 2.5, y: 16.5))
            slash.line(to: NSPoint(x: 15.5, y: 1.5))
            slash.lineCapStyle = .round

            // Cut a gap around the slash so it reads clearly against the window.
            NSGraphicsContext.current?.compositingOperation = .clear
            slash.lineWidth = 4
            slash.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            slash.lineWidth = 1.5
            slash.stroke()
            return true
        }
        img.isTemplate = true
        return img
    }

    // MARK: Hiding

    /// Checks twice a second for about a minute after login. Waits 5 seconds before hiding
    /// anything, then keeps each login app hidden, so apps that show their windows late get hidden too.
    func startWatching() {
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.sweep() }
    }

    func sweep() {
        noteFirstInput()
        let now = Date()
        if now.timeIntervalSince(started) > watchWindow {
            sweepTimer?.invalidate(); sweepTimer = nil
            return
        }
        guard now.timeIntervalSince(started) >= startDelay else { return }

        for app in NSWorkspace.shared.runningApplications where isOrdinaryApp(app) && isLoginApp(app) {
            guard let id = app.bundleIdentifier else { continue }
            let pid = app.processIdentifier
            if Settings.neverHide.contains(id) || yours.contains(pid) || app.isHidden { continue }
            // It's showing. If it came forward right after you clicked or typed, you opened it: leave it alone.
            if app.isActive && secondsSinceInput() < userActionWindow {
                yours.insert(pid)
                continue
            }
            app.hide()
        }
    }

    /// A login app is one in macOS's Login Items. Nothing else is ever hidden.
    func isLoginApp(_ app: NSRunningApplication) -> Bool {
        if let loginIDs { return app.bundleIdentifier.map(loginIDs.contains) ?? false }
        // Login Items couldn't be read (for example, permission to control System Events was declined): use the last saved list,
        // and if there's none, fall back to "started before your first click or key press".
        let saved = Settings.loginApps
        if !saved.isEmpty { return app.bundleIdentifier.map { saved[$0] != nil } ?? false }
        guard let launched = app.launchDate else { return firstInput == nil }
        return launched < (firstInput ?? .distantFuture)
    }

    func noteFirstInput() {
        guard firstInput == nil else { return }
        let last = Date().addingTimeInterval(-secondsSinceInput())
        // Ignore the typing that logged you in (it happened before this app started).
        if last > started.addingTimeInterval(0.5) { firstInput = last }
    }

    /// Seconds since your last click or key press. macOS provides this without any special permission.
    func secondsSinceInput() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? .infinity
    }

    func isOrdinaryApp(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy == .regular
            && app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            && !app.isTerminated
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        refreshLoginItems()   // picks up changes made in System Settings

        let header = NSMenuItem()
        header.view = HeaderView(title: "Hide at login")
        menu.addItem(header)

        let apps = Settings.loginApps.sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
        if apps.isEmpty {
            let empty = NSMenuItem(title: "No apps with windows in Login Items.", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for (i, (id, name)) in apps.enumerated() {
            let item = NSMenuItem()
            item.view = AppRowView(bundleID: id, name: name, showsDivider: i < apps.count - 1)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let start = NSMenuItem(title: "Start Login Window Hider at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        start.target = self
        start.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(start)
        let quit = NSMenuItem(title: "Quit Login Window Hider", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc func toggleStartAtLogin() {
        do {
            let turningOn = SMAppService.mainApp.status != .enabled
            if turningOn { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            UserDefaults.standard.set(turningOn, forKey: "startAtLogin")
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login setting"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
