import AppKit
import ElvisKit

final class Carrying {
    struct Elvis {
        var x: () -> Double
        var pickUp: () -> Void
        var pat: () -> Void
        var putDown: (_ x: Double) -> Void
    }

    private let window: NSWindow
    private let view: YardView
    private let elvis: Elvis
    private let rememberSpot: (CGPoint) -> Void
    private var gesture = PickUpGesture()

    init(window: NSWindow, view: YardView, elvis: Elvis, rememberSpot: @escaping (CGPoint) -> Void) {
        self.window = window
        self.view = view
        self.elvis = elvis
        self.rememberSpot = rememberSpot
        view.onPress = { [weak self] in self?.press() }
        view.onDrag = { [weak self] in self?.drag() }
        view.onRelease = { [weak self] in self?.release() }
    }

    func tick() {
        releaseIfButtonCameUpUnseen()
        catchClicksOnlyOnElvis()
    }

    private func pointerIsOverElvis() -> Bool {
        guard let pointer = view.pointerInYard() else { return false }
        return Painter.body(of: view.frameToDraw).contains(CGPoint(x: pointer.x, y: pointer.y))
    }

    private func catchClicksOnlyOnElvis() {
        let catchClicks = gesture.isPressed || pointerIsOverElvis()
        if window.ignoresMouseEvents == catchClicks { window.ignoresMouseEvents = !catchClicks }
    }

    // The window starts catching clicks a tick after the pointer reaches him, so the press is checked again here.
    private func press() {
        gesture.press(onElvis: pointerIsOverElvis(), at: NSEvent.mouseLocation)
    }

    private func drag() {
        switch gesture.drag(to: NSEvent.mouseLocation, windowOrigin: window.frame.origin) {
        case .lifted(let origin):
            elvis.pickUp()
            window.setFrameOrigin(origin)
        case .carried(let origin):
            window.setFrameOrigin(origin)
        case nil:
            break
        }
    }

    private func release() {
        finish(gesture.release())
    }

    private func releaseIfButtonCameUpUnseen() {
        guard gesture.isPressed else { return }
        finish(gesture.releaseIfButtonCameUpUnseen(buttonIsDown: NSEvent.pressedMouseButtons & 1 != 0))
    }

    private func finish(_ release: PickUpGesture.Release?) {
        switch release {
        case .pat:
            elvis.pat()
        case .putDown:
            putDown()
        case nil:
            break
        }
    }

    private func putDown() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? window.screen ?? NSScreen.screens.first
        guard let screen else { return }
        let settled = Placement.settle(window: window.frame, dogX: elvis.x(), unit: YardView.unit, within: screen.floor)
        window.setFrameOrigin(settled.origin)
        elvis.putDown(settled.dogX)
        rememberSpot(settled.origin)
    }
}
