import CoreGraphics

public struct PickUpGesture {
    public enum Drag: Equatable {
        case lifted(windowOrigin: CGPoint)
        case carried(windowOrigin: CGPoint)
    }

    public enum Release: Equatable {
        case pat
        case putDown
    }

    public static let liftDistance = 3.0

    private var pressedAt: CGPoint?
    private var grip: CGPoint?

    public init() {}

    public var isPressed: Bool { pressedAt != nil }

    public mutating func press(onElvis: Bool, at pointer: CGPoint) {
        guard onElvis else { return }
        pressedAt = pointer
    }

    public mutating func drag(to pointer: CGPoint, windowOrigin: CGPoint) -> Drag? {
        if grip == nil, let start = pressedAt, hypot(pointer.x - start.x, pointer.y - start.y) > Self.liftDistance {
            let grip = CGPoint(x: start.x - windowOrigin.x, y: start.y - windowOrigin.y)
            self.grip = grip
            return .lifted(windowOrigin: Self.origin(holding: grip, under: pointer))
        }
        guard let grip else { return nil }
        return .carried(windowOrigin: Self.origin(holding: grip, under: pointer))
    }

    public mutating func release() -> Release? {
        guard pressedAt != nil else { return nil }
        pressedAt = nil
        guard grip != nil else { return .pat }
        grip = nil
        return .putDown
    }

    public mutating func releaseIfButtonCameUpUnseen(buttonIsDown: Bool) -> Release? {
        buttonIsDown ? nil : release()
    }

    private static func origin(holding grip: CGPoint, under pointer: CGPoint) -> CGPoint {
        CGPoint(x: pointer.x - grip.x, y: pointer.y - grip.y)
    }
}
