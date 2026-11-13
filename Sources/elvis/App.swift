import AppKit
import ElvisKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var brain = Brain(seed: UInt64(Date().timeIntervalSince1970 * 1000))
    private var stage = Stage(seed: UInt64(Date().timeIntervalSince1970))
    private var keepsakes = Keepsakes.load()
    private var window: NSPanel?
    private let view = YardView()
    private let speaker = Speaker()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastSave = ProcessInfo.processInfo.systemUptime
    private var ticksPerSecond = 30.0
    private var carrying: Carrying?
    private var statusMenu: StatusMenu?
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
            statusMenu = makeStatusMenu()
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
        view.wantsLayer = true
        view.layer?.contentsFormat = .RGBA8Uint
        self.window = window
        carrying = makeCarrying(in: window)
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
                let settled = Placement.settle(window: wanted, dogX: brain.world.x, unit: YardView.unit, within: screen.floor)
                window.setFrame(NSRect(origin: settled.origin, size: size), display: true)
                return
            }
        }
        let ground = home.floor
        let x = keepsakes.leftCorner ? ground.minX + 8 : ground.maxX - size.width - 8
        window.setFrame(NSRect(origin: NSPoint(x: x, y: ground.minY), size: size), display: true)
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

        brain.cursor(at: view.pointerInYard())
        brain.tick(dt)
        for cue in brain.drainCues() {
            if cue == .whine { stage.showWhine(at: brain.moment) }
            if keepsakes.sounds { speaker.play(cue) }
        }
        carrying?.tick()
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
        runAtFullRate()
    }

    private func runAtFullRate() {
        if ticksPerSecond < 30 { schedule(rate: 30) }
    }

    private func remember() {
        keepsakes.mud = brain.world.mud
        keepsakes.save()
    }

    private func makeCarrying(in window: NSWindow) -> Carrying {
        Carrying(
            window: window, view: view,
            elvis: Carrying.Elvis(
                x: { [unowned self] in self.brain.world.x },
                pickUp: { [weak self] in self?.pickUp() },
                pat: { [weak self] in self?.pat() },
                putDown: { [weak self] x in self?.brain.putDown(at: x) }),
            rememberSpot: { [weak self] origin in self?.remember(spot: origin) })
    }

    private func pickUp() {
        brain.pickUp()
        runAtFullRate()
    }

    private func pat() {
        brain.pat()
        runAtFullRate()
    }

    private func remember(spot origin: CGPoint) {
        keepsakes.spot = Keepsakes.Spot(x: origin.x, y: origin.y)
        keepsakes.save()
    }

    private func makeStatusMenu() -> StatusMenu {
        StatusMenu(
            version: Version.current,
            status: { [unowned self] in
                StatusMenu.Status(
                    caption: self.brain.caption, company: self.brain.company, soundsAreOn: self.keepsakes.sounds, isInHisCorner: self.keepsakes.spot == nil)
            },
            choices: StatusMenu.Choices(
                throwBall: { [weak self] in self?.receive(WorkEvent(.throwBall)) },
                toggleSounds: { [weak self] in self?.toggleSounds() },
                switchCorner: { [weak self] in self?.switchCorner() },
                quit: { NSApp.terminate(nil) }))
    }

    private func toggleSounds() {
        keepsakes.sounds.toggle()
        keepsakes.save()
    }

    private func switchCorner() {
        if keepsakes.spot == nil { keepsakes.leftCorner.toggle() }
        keepsakes.spot = nil
        keepsakes.save()
        placeWindow()
    }
}

enum ElvisApp {
    static func run(detached: Bool) -> Never {
        guard RunningElvis.claim(as: Version.current) else {
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
