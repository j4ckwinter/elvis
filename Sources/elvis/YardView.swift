import AppKit
import ElvisKit

final class YardView: NSView {
    static let unit = 2.0
    var frameToDraw = Frame()
    private var lastPatch = CGRect.null

    var onPress: () -> Void = {}
    var onDrag: () -> Void = {}
    var onRelease: () -> Void = {}

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onPress() }
    override func mouseDragged(with event: NSEvent) { onDrag() }
    override func mouseUp(with event: NSEvent) { onRelease() }

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
