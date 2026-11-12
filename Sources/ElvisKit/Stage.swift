import CoreGraphics
import Foundation

public struct Stage: Sendable {
    private struct Pendulum: Sendable {
        var angle = 0.0
        var velocity = 0.0
    }

    var rng: SplitMix
    private var serial = -1
    private var blendFrom = Pose()
    private var blendAge = 1.0
    private(set) var shown = Pose()
    private(set) var facing = 1.0
    private var ear = Pendulum()
    private var dangle = Pendulum()
    private var headAt: CGPoint?
    private var headVelocity = CGPoint.zero
    private var headAcceleration = CGPoint.zero
    var particles: [Particle] = []
    private var doorAlpha = 0.0
    private var blinkIn = 3.0
    private var blinkLeft = 0.0
    private(set) var lastElapsed = 0.0
    var emitDebt: [Particle.Kind: Double] = [:]
    private var time = 0.0

    private static let blendTime = 0.22
    private static let earLength = 12.0
    private static let earGravity = 700.0

    public init(seed: UInt64) {
        rng = SplitMix(seed: seed)
    }

    /// - Parameter yardOrigin: where the yard itself sits, in dog units. Moving it swings his ears and, while he is
    ///   being carried, the rest of him.
    public mutating func advance(_ m: Moment, dt: Double, yardOrigin: CGPoint = .zero) -> Frame {
        time += dt
        let started = m.serial != serial
        if started {
            serial = m.serial
            blendFrom = shown
            blendAge = 0
            lastElapsed = 0
        }
        blendAge += dt

        var pose = Choreography.pose(for: m)
        pose = blendFrom.mixed(with: pose, ease(blendAge / Stage.blendTime))

        let turnRate = 9.0 * dt
        facing += min(turnRate, max(-turnRate, m.world.facing - facing))
        let scale = facing * pose.turn
        let side = scale >= 0 ? 1.0 : -1.0
        let drawScale = abs(scale) < 0.06 ? 0.06 * side : scale

        let head = CGPoint(x: yardOrigin.x + m.world.x + drawScale * pose.head.x, y: yardOrigin.y + pose.head.y + pose.lift)
        let push = headMotion(to: head, dt: dt)
        Stage.swing(&ear, push: push, length: Stage.earLength, damping: 5.5, limit: 2.2, dt: dt)
        if m.action == .held {
            Stage.swing(&dangle, push: push, length: 26, damping: 3, limit: 1.0, dt: dt)
            hang(&pose, at: dangle.angle * side)
        } else {
            dangle = Pendulum()
        }
        shown = pose
        watchCursor(&pose, m, side: side)
        blink(&pose, dt)
        let swing = ear.angle * side
        let fling = pose.earFling
        let ears = [swing + fling, swing + fling * 0.8]

        emit(m, pose: pose, scale: drawScale, started: started, dt: dt)
        moveParticles(dt)
        lastElapsed = m.elapsed
        doorAlpha += min(dt * 3.5, max(-dt * 3.5, (m.world.doorOpen ? 1 : 0) - doorAlpha))

        var frame = Frame()
        frame.pose = pose
        frame.action = m.action
        frame.elapsed = m.elapsed
        frame.x = m.world.x
        frame.facing = drawScale
        frame.ears = ears
        frame.particles = particles
        frame.ball = m.world.ball
        frame.doorAlpha = doorAlpha
        frame.mud = m.world.mud
        frame.time = time
        if case .go(let target, let gait) = m.action, gait == .sniff, abs(target - m.world.x) > 18 {
            frame.trailTo = target
        }
        return frame
    }

    public var isSettled: Bool { blendAge > Stage.blendTime }

    private mutating func blink(_ pose: inout Pose, _ dt: Double) {
        blinkIn -= dt
        if blinkIn <= 0 {
            blinkLeft = 0.13
            blinkIn = Double.random(in: 2.4...6.5, using: &rng)
        }
        if blinkLeft > 0 {
            blinkLeft -= dt
            if pose.eyes > 0.5, pose.happyEyes < 0.5 { pose.eyes = 0.05 }
        }
    }

    private func watchCursor(_ pose: inout Pose, _ m: Moment, side: Double) {
        guard let cursor = m.world.cursor, pose.eyes > 0.5, pose.look == .zero, !m.action.isAsleep else { return }
        let dx = (cursor.x - m.world.x) * side - pose.head.x
        let dy = cursor.y - pose.head.y
        let distance = max(1, (dx * dx + dy * dy).squareRoot())
        pose.look = CGPoint(x: dx / distance, y: dy / distance)
        if pose.front < 0.5 { pose.pitch += max(-0.2, min(0.3, dy / 120)) }
    }

    private mutating func headMotion(to head: CGPoint, dt: Double) -> CGPoint {
        guard dt > 0 else { return .zero }
        if let last = headAt {
            let velocity = (head - last) * (1 / dt)
            let acceleration = (velocity - headVelocity) * (1 / dt)
            headVelocity = velocity
            headAcceleration = headAcceleration.mixed(acceleration, 0.5)
        }
        headAt = head
        return CGPoint(
            x: max(-2600, min(2600, headAcceleration.x + headVelocity.x * 6)),
            y: max(-650, min(2600, headAcceleration.y)))
    }

    private static func swing(_ pendulum: inout Pendulum, push: CGPoint, length: Double, damping: Double, limit: Double, dt: Double) {
        guard dt > 0 else { return }
        let steps = 3
        let h = dt / Double(steps)
        for _ in 0..<steps {
            let pull = ((earGravity + push.y) * sin(pendulum.angle) + push.x * cos(pendulum.angle)) / length
            pendulum.velocity += (-pull - damping * pendulum.velocity) * h
            pendulum.angle += pendulum.velocity * h
        }
        if abs(pendulum.angle) > limit {
            pendulum.angle = pendulum.angle > 0 ? limit : -limit
            pendulum.velocity = 0
        }
    }

    private func hang(_ pose: inout Pose, at angle: Double) {
        pose.hip = pose.shoulder + (pose.hip - pose.shoulder).rotated(angle)
        pose.paws = pose.paws.map { pose.shoulder + ($0 - pose.shoulder).rotated(angle) }
    }
}
