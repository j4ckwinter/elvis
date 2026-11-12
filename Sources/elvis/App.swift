import AppKit
import ElvisKit

/// What survives a restart: the day's mud and the two menu choices.
struct Keepsakes: Codable {
    var sounds = true
    var leftCorner = false
    var mud = 0.0
    var day = ""

    static var path: String { EventSocket.directory + "/state.json" }

    static func load() -> Keepsakes {
        guard let data = FileManager.default.contents(atPath: path),
              let saved = try? JSONDecoder().decode(Keepsakes.self, from: data)
        else { return Keepsakes() }
        return saved
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: URL(fileURLWithPath: Keepsakes.path), options: .atomic)
    }

    static var today: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

final class YardView: NSView {
    static let unit = 2.0
    var frameToDraw = Frame()
    private var lastPatch = CGRect.null

    override var isOpaque: Bool { false }

    /// Repaints only the patch the new frame and the previous one touch.
    func show(_ frame: Frame) {
        frameToDraw = frame
        let area = Painter.bounds(of: frame)
        let patch = CGRect(
            x: area.minX * YardView.unit, y: (area.minY + Painter.groundMargin) * YardView.unit,
            width: area.width * YardView.unit, height: area.height * YardView.unit
        ).insetBy(dx: -2, dy: -2)
        setNeedsDisplay(patch.union(lastPatch).intersection(bounds))
        lastPatch = patch
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        Painter.draw(frameToDraw, in: ctx, unit: YardView.unit)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var brain = Brain(seed: UInt64(Date().timeIntervalSince1970 * 1000))
    private var stage = Stage(seed: UInt64(Date().timeIntervalSince1970))
    private var keepsakes = Keepsakes.load()
    private var window: NSPanel!
    private let view = YardView()
    private let whine = Whine()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastSave = ProcessInfo.processInfo.systemUptime
    private var ticksPerSecond = 30.0
    private var statusItem: NSStatusItem!
    private let captionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let soundsItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds), keyEquivalent: "")
    private let film = ProcessInfo.processInfo.environment["ELVIS_FILM"].map(Sheets.Film.init(directory:))
    private var lastFilmed = 0.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        if keepsakes.day == Keepsakes.today {
            brain.restore(mud: keepsakes.mud)
        } else {
            keepsakes.day = Keepsakes.today
            keepsakes.mud = 0
        }

        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.colorSpace = .sRGB
        window.contentView = view
        view.wantsLayer = true
        view.layer?.contentsFormat = .RGBA8Uint
        placeWindow()
        window.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            self, selector: #selector(placeWindow), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        buildMenu()
        do {
            try EventSocket.listen { [weak self] event in self?.receive(event) }
        } catch {
            FileHandle.standardError.write(Data("elvis: could not open \(EventSocket.path): \(error)\n".utf8))
            exit(1)
        }
        schedule(rate: 30)
    }

    func applicationWillTerminate(_ notification: Notification) {
        remember()
        film?.flush()
        unlink(EventSocket.path)
    }

    @objc private func placeWindow() {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: Yard.width * YardView.unit, height: (Yard.height + Painter.groundMargin) * YardView.unit)
        let x = keepsakes.leftCorner ? visible.minX + 8 : visible.maxX - size.width - 8
        let y = max(screen.frame.minY, visible.minY - 4)
        window.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    private func cursorInYard() -> (x: Double, y: Double)? {
        let mouse = NSEvent.mouseLocation
        let frame = window.frame
        let x = (mouse.x - frame.minX) / YardView.unit
        let y = (mouse.y - frame.minY) / YardView.unit - Painter.groundMargin
        guard x > -50, x < Yard.width + 50, y > -12, y < Yard.height + 60 else { return nil }
        return (x, y)
    }

    private func schedule(rate: Double) {
        ticksPerSecond = rate
        timer?.invalidate()
        let timer = Timer(timeInterval: 1 / rate, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.2 / rate
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.25, max(0, now - lastTick))
        lastTick = now

        brain.cursor(at: cursorInYard())
        brain.tick(dt)
        for cue in brain.drainCues() where cue == .whine {
            stage.showWhine(at: brain.moment)
            if keepsakes.sounds { whine.play() }
        }
        view.show(stage.advance(brain.moment, dt: dt))
        if let film, now - lastFilmed >= 0.75 {
            lastFilmed = now
            film.add(view.frameToDraw)
        }

        let still = brain.action.isAsleep || [.doze, .rest, .lieByDoor].contains(brain.action)
        let resting = still && stage.isSettled && brain.world.ball?.state != .flying
        let wanted = resting ? 10.0 : 30.0
        if wanted != ticksPerSecond { schedule(rate: wanted) }

        if now - lastSave > 60 {
            lastSave = now
            if keepsakes.day != Keepsakes.today {
                keepsakes.day = Keepsakes.today
                brain.startNewDay()
            }
            remember()
        }
    }

    private func receive(_ event: WorkEvent) {
        if event.kind == .quit {
            NSApp.terminate(nil)
            return
        }
        brain.handle(event)
        if ticksPerSecond < 30 { schedule(rate: 30) }
    }

    private func remember() {
        keepsakes.mud = brain.world.mud
        keepsakes.save()
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Elvis") {
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "🐾"
        }
        let menu = NSMenu()
        menu.delegate = self
        captionItem.isEnabled = false
        menu.addItem(captionItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Throw the Ball", action: #selector(throwBall), keyEquivalent: "").target = self
        soundsItem.target = self
        menu.addItem(soundsItem)
        menu.addItem(withTitle: "Move to the Other Corner", action: #selector(switchCorner), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Elvis", action: #selector(quit), keyEquivalent: "").target = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        captionItem.title = "Elvis: \(brain.caption)"
        soundsItem.state = keepsakes.sounds ? .on : .off
    }

    @objc private func throwBall() { receive(WorkEvent(.throwBall)) }

    @objc private func toggleSounds() {
        keepsakes.sounds.toggle()
        keepsakes.save()
    }

    @objc private func switchCorner() {
        keepsakes.leftCorner.toggle()
        keepsakes.save()
        placeWindow()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

enum ElvisApp {
    static func run(detached: Bool) -> Never {
        guard EventSocket.claimSoleInstance() else {
            print("Elvis is already here.")
            exit(0)
        }
        if detached {
            setsid()
            signal(SIGHUP, SIG_IGN)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
        exit(0)
    }
}
