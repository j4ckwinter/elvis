import CoreGraphics
import Testing
@testable import ElvisKit

@Suite struct PickUpGestureTests {
    private let onHim = CGPoint(x: 100, y: 50)
    private let windowOrigin = CGPoint(x: 40, y: 20)

    private func pressedOnHim() -> PickUpGesture {
        var gesture = PickUpGesture()
        gesture.press(onElvis: true, at: onHim)
        return gesture
    }

    private func lifted() -> PickUpGesture {
        var gesture = pressedOnHim()
        _ = gesture.drag(to: CGPoint(x: 104, y: 50), windowOrigin: windowOrigin)
        return gesture
    }

    @Test func aClickWithoutMovementIsAPat() {
        var gesture = pressedOnHim()
        #expect(gesture.isPressed)
        #expect(gesture.release() == .pat)
        #expect(!gesture.isPressed)
    }

    @Test func movementUnderTheThresholdIsStillAPat() {
        var gesture = pressedOnHim()
        #expect(gesture.drag(to: CGPoint(x: 102, y: 52), windowOrigin: windowOrigin) == nil)
        #expect(gesture.drag(to: CGPoint(x: 100, y: 47), windowOrigin: windowOrigin) == nil)
        #expect(gesture.release() == .pat)
    }

    @Test func movementPastTheThresholdLiftsHimOnceAndThenCarriesHim() {
        var gesture = pressedOnHim()
        #expect(gesture.drag(to: CGPoint(x: 104, y: 50), windowOrigin: windowOrigin) == .lifted(windowOrigin: CGPoint(x: 44, y: 20)))
        #expect(gesture.drag(to: CGPoint(x: 130, y: 90), windowOrigin: CGPoint(x: 44, y: 20)) == .carried(windowOrigin: CGPoint(x: 70, y: 60)))
        #expect(gesture.drag(to: CGPoint(x: 101, y: 50), windowOrigin: CGPoint(x: 70, y: 60)) == .carried(windowOrigin: CGPoint(x: 41, y: 20)))
    }

    @Test(arguments: [CGPoint(x: 104, y: 50), CGPoint(x: 900, y: -300), CGPoint(x: -1500, y: 420)])
    func carryingKeepsHimTheSameDistanceFromThePointer(pointer: CGPoint) {
        var gesture = lifted()
        guard case .carried(let origin) = gesture.drag(to: pointer, windowOrigin: .zero) else {
            Issue.record("a lifted Elvis was not carried")
            return
        }
        #expect(pointer.x - origin.x == onHim.x - windowOrigin.x)
        #expect(pointer.y - origin.y == onHim.y - windowOrigin.y)
    }

    @Test func lettingGoAfterALiftPutsHimDown() {
        var gesture = lifted()
        #expect(gesture.release() == .putDown)
        #expect(!gesture.isPressed)
    }

    @Test func aClickAfterPuttingHimDownIsAPatAgain() {
        var gesture = lifted()
        _ = gesture.release()
        gesture.press(onElvis: true, at: onHim)
        #expect(gesture.drag(to: onHim, windowOrigin: windowOrigin) == nil)
        #expect(gesture.release() == .pat)
    }

    @Test func aPressThatMissedHimDoesNothingOnDragOrRelease() {
        var gesture = PickUpGesture()
        gesture.press(onElvis: false, at: onHim)
        #expect(!gesture.isPressed)
        #expect(gesture.drag(to: CGPoint(x: 160, y: 90), windowOrigin: windowOrigin) == nil)
        #expect(gesture.release() == nil)
        #expect(gesture.releaseIfButtonCameUpUnseen(buttonIsDown: false) == nil)
    }

    @Test func aHeldButtonKeepsThePress() {
        var gesture = pressedOnHim()
        #expect(gesture.releaseIfButtonCameUpUnseen(buttonIsDown: true) == nil)
        #expect(gesture.isPressed)
    }

    @Test func aLostButtonUpEndsAPressTheWayAReleaseDoes() {
        var patted = pressedOnHim()
        #expect(patted.releaseIfButtonCameUpUnseen(buttonIsDown: false) == .pat)
        #expect(!patted.isPressed)

        var carried = lifted()
        #expect(carried.releaseIfButtonCameUpUnseen(buttonIsDown: false) == .putDown)
        #expect(!carried.isPressed)
    }
}
