import AppKit

extension NSScreen {
    var floor: NSRect {
        let visible = visibleFrame
        let bottom = max(frame.minY, visible.minY - 4)
        return NSRect(x: visible.minX, y: bottom, width: visible.width, height: visible.maxY - bottom)
    }
}
