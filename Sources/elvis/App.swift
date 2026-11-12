import AppKit
import ElvisKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var brain = Brain(seed: UInt64(Date().timeIntervalSince1970 * 1000))
    private var stage = Stage(seed: UInt64(Date().timeIntervalSince1970))
    private var keepsakes = Keepsakes.load()
    private var window: NSPanel?
    private let view = YardView()
    private let whine = Whine()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastSave = ProcessInfo.processInfo.systemUptime
    private var ticksPerSecond = 30.0
    private var pressedAt: NSPoint?
    private var grip: NSPoint?
    private var statusItem: NSStatusItem!
    private let captionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let soundsItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds), keyEquivalent: "")
    private let cornerItem = NSMenuItem(title: "", action: #selector(switchCorner), keyEquivalent: "")
    private let film = ProcessInfo.processInfo.environment["ELVIS_FILM"].map(Sheets.Film.init(directory:))
    private var lastFilmed = 0.0
    private let isHeadless = ProcessInfo.processInfo.environment["ELVIS_HEADLESS"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        if keepsakes.day == Keepsakes.today {
            brain.restore(mud: keepsakes.mud)
        } else {
            keepsakes.day = Keepsakes.today
            keepsakes.mud = 0
        }

        if !isHeadless {
            openYard()
            buildMenu()
        }
        do {
            try EventSocket.listen { [weak self] event in self?.receive(event) }
        } catch {
            FileHandle.standardError.write(Data("elvis: could not open \(EventSocket.path): \(error)\n".utf8))
            exit(1)
        }
        schedule(rate: 30)
    }

    private func openYard() {
        let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.colorSpace = .sRGB
        window.contentView = view
        view.onPress = { [weak self] in self?.press() }
        view.onDrag = { [weak self] in self?.drag() }
        view.onRelease = { [weak self] in self?.release() }
        view.wantsLayer = true
        view.layer?.contentsFormat = .RGBA8Uint
        self.window = window
        placeWindow()
        window.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            self, selector: #selector(placeWindow), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        remember()
        film?.flush()
        unlink(EventSocket.path)
    }

    @objc private func placeWindow() {
        guard let window, let home = NSScreen.screens.first else { return }
        let size = NSSize(width: Yard.width * YardView.unit, height: (Yard.height + Painter.groundMargin) * YardView.unit)
        if let spot = keepsakes.spot {
            let wanted = NSRect(origin: NSPoint(x: spot.x, y: spot.y), size: size)
            if let screen = NSScreen.screens.first(where: { $0.frame.intersects(wanted) }) {
                let settled = Placement.settle(window: wanted, dogX: brain.world.x, unit: YardView.unit, within: floor(of: screen))
                window.setFrame(NSRect(origin: settled.origin, size: size), display: true)
                return
            }
        }
        let ground = floor(of: home)
        let x = keepsakes.leftCorner ? ground.minX + 8 : ground.maxX - size.width - 8
        window.setFrame(NSRect(origin: NSPoint(x: x, y: ground.minY), size: size), display: true)
    }

    private func floor(of screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let bottom = max(screen.frame.minY, visible.minY - 4)
        return NSRect(x: visible.minX, y: bottom, width: visible.width, height: visible.maxY - bottom)
    }

    private func pointerIsOverElvis() -> Bool {
        guard let pointer = cursorInYard() else { return false }
        return Painter.body(of: view.frameToDraw).contains(CGPoint(x: pointer.x, y: pointer.y))
    }

    // The window starts catching clicks a tick after the pointer reaches him, so the press is checked again here.
    private func press() {
        guard pointerIsOverElvis() else { return }
        pressedAt = NSEvent.mouseLocation
    }

    private func drag() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        if grip == nil, let start = pressedAt, hypot(mouse.x - start.x, mouse.y - start.y) > 3 {
            grip = NSPoint(x: start.x - window.frame.minX, y: start.y - window.frame.minY)
            brain.pickUp()
            if ticksPerSecond < 30 { schedule(rate: 30) }
        }
        guard let grip else { return }
        window.setFrameOrigin(NSPoint(x: mouse.x - grip.x, y: mouse.y - grip.y))
    }

    private func release() {
        guard pressedAt != nil else { return }
        pressedAt = nil
        if grip == nil {
            brain.pat()
            if ticksPerSecond < 30 { schedule(rate: 30) }
        } else {
            putDown()
        }
    }

    private func putDown() {
        grip = nil
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? window.screen ?? NSScreen.screens.first
        guard let screen else { return }
        let settled = Placement.settle(window: window.frame, dogX: brain.world.x, unit: YardView.unit, within: floor(of: screen))
        window.setFrameOrigin(settled.origin)
        brain.putDown(at: settled.dogX)
        keepsakes.spot = Keepsakes.Spot(x: settled.origin.x, y: settled.origin.y)
        keepsakes.save()
    }

    private func cursorInYard() -> (x: Double, y: Double)? {
        guard let frame = window?.frame else { return nil }
        let mouse = NSEvent.mouseLocation
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
        let buttonCameUpUnseen = pressedAt != nil && NSEvent.pressedMouseButtons & 1 == 0
        if buttonCameUpUnseen { release() }
        let catchClicks = pressedAt != nil || pointerIsOverElvis()
        if let window, window.ignoresMouseEvents == catchClicks { window.ignoresMouseEvents = !catchClicks }
        let corner = window?.frame.origin ?? .zero
        let yardOrigin = CGPoint(x: corner.x / YardView.unit, y: corner.y / YardView.unit)
        view.show(stage.advance(brain.moment, dt: dt, yardOrigin: yardOrigin))
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
        cornerItem.target = self
        menu.addItem(cornerItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Elvis", action: #selector(quit), keyEquivalent: "").target = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        captionItem.title = "Elvis: \(brain.caption)"
        soundsItem.state = keepsakes.sounds ? .on : .off
        cornerItem.title = keepsakes.spot == nil ? "Move to the Other Corner" : "Back to His Corner"
    }

    @objc private func throwBall() { receive(WorkEvent(.throwBall)) }

    @objc private func toggleSounds() {
        keepsakes.sounds.toggle()
        keepsakes.save()
    }

    @objc private func switchCorner() {
        if keepsakes.spot == nil { keepsakes.leftCorner.toggle() }
        keepsakes.spot = nil
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
