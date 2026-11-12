import CoreGraphics

/// Where the yard window may rest after Elvis is carried somewhere and put down.
public enum Placement {
    /// Fits the window inside `screen` and returns the yard x that keeps Elvis under the same point on screen,
    /// as far as the yard's own edges allow.
    public static func settle(window: CGRect, dogX: Double, unit: Double, within screen: CGRect) -> (origin: CGPoint, dogX: Double) {
        let dogOnScreen = window.minX + dogX * unit
        let origin = CGPoint(
            x: min(max(window.minX, screen.minX), max(screen.minX, screen.maxX - window.width)),
            y: min(max(window.minY, screen.minY), max(screen.minY, screen.maxY - window.height)))
        let kept = (dogOnScreen - origin.x) / unit
        return (origin, min(Yard.rightEdge, max(Yard.leftEdge, kept)))
    }
}
