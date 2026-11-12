import CoreGraphics
import Foundation

public struct Particle: Sendable {
    public enum Kind: Sendable { case zzz, heart, drop, dirt, puff, whine, bang, query }
    public var kind: Kind
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var age = 0.0
    public var life: Double
    public var size: Double
    public var muddy = false
}

/// What the painter draws for one frame.
public struct Frame: Sendable {
    public var pose = Pose()
    public var action = Action.sit
    public var elapsed = 0.0
    public var x = Yard.home
    /// Signed horizontal scale of the dog: the direction he faces, passing through zero as he turns round.
    public var facing = 1.0
    /// Ear angles from straight down, in the dog's own frame. Profile heads use the first.
    public var ears = [0.0, 0.0]
    public var particles: [Particle] = []
    public var ball: Ball?
    public var doorAlpha = 0.0
    public var mud = 0.0
    public var trailTo: Double?
    public var time = 0.0
    public init() {}
}

/// Turns brain moments into frames: blends between actions, swings the ears, blinks, and scatters particles.
public struct Stage: Sendable {
    private struct Pendulum: Sendable {
        var angle = 0.0
        var velocity = 0.0
    }

    private var rng: SplitMix
    private var serial = -1
    private var blendFrom = Pose()
    private var blendAge = 1.0
    private var shown = Pose()
    private var facing = 1.0
    private var ear = Pendulum()
    private var dangle = Pendulum()
    private var headAt: CGPoint?
    private var headVelocity = CGPoint.zero
    private var headAcceleration = CGPoint.zero
    private var particles: [Particle] = []
    private var doorAlpha = 0.0
    private var blinkIn = 3.0
    private var blinkLeft = 0.0
    private var lastElapsed = 0.0
    private var emitDebt: [Particle.Kind: Double] = [:]
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

    /// Shows the whine as well as playing it.
    public mutating func showWhine(at m: Moment) {
        let pose = shown
        let mouth = mouthPoint(pose, x: m.world.x, scale: facing)
        for i in 0..<3 {
            particles.append(Particle(kind: .whine, x: mouth.x + Double(i) * 1.5 * (facing >= 0 ? 1 : -1), y: mouth.y + 2, vx: 5 * (facing >= 0 ? 1 : -1), vy: 6, age: -Double(i) * 0.3, life: 1.1, size: 2.4))
        }
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

    /// Returns the sideways and upward push the head's movement puts on anything hanging from him.
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

    /// Swings everything below the scruff, which is where he is held.
    private func hang(_ pose: inout Pose, at angle: Double) {
        pose.hip = pose.shoulder + (pose.hip - pose.shoulder).rotated(angle)
        pose.paws = pose.paws.map { pose.shoulder + ($0 - pose.shoulder).rotated(angle) }
    }

    private func mouthPoint(_ pose: Pose, x: Double, scale: Double) -> CGPoint {
        let local = pose.front > 0.5
            ? pose.head + CGPoint(x: 0, y: -3.5)
            : pose.head + CGPoint(x: 11.5, y: -1.5).rotated(pose.pitch)
        return CGPoint(x: x + scale * local.x, y: local.y + pose.lift)
    }

    private mutating func emit(_ m: Moment, pose: Pose, scale: Double, started: Bool, dt: Double) {
        let x = m.world.x
        let side = scale >= 0 ? 1.0 : -1.0
        let nose = mouthPoint(pose, x: x, scale: scale)
        let top = CGPoint(x: x + scale * pose.head.x, y: pose.head.y + pose.lift + 8)
        func crossed(_ moment: Double) -> Bool { lastElapsed < moment && m.elapsed >= moment }

        switch m.action {
        case .sleep, .sleepTwitch, .dream, .sleepWag:
            if due(.zzz, every: 1.7, dt) {
                particles.append(Particle(kind: .zzz, x: top.x + side * 2, y: top.y - 2, vx: side * 2.2, vy: 5.5, life: 2.6, size: 2.2))
            }
        case .sleepSigh, .sigh:
            if crossed(m.length * 0.55) {
                particles.append(Particle(kind: .puff, x: nose.x + side * 2, y: nose.y, vx: side * 6, vy: 1, life: 0.9, size: 1.4))
            }
        case .petted:
            if due(.heart, every: 0.55, dt) { heart(above: top) }
        case .proudSit:
            if due(.heart, every: 1.5, dt) { heart(above: top) }
        case .relief:
            if started { heart(above: top) }
        case .shake:
            if m.elapsed > 0.15, m.elapsed < m.length - 0.3 {
                let count = owed(.drop, perSecond: 55, dt)
                for _ in 0..<count {
                    let angle = Double.random(in: 0.15...(Double.pi - 0.15), using: &rng)
                    let speed = Double.random(in: 30...70, using: &rng)
                    particles.append(Particle(
                        kind: .drop, x: x + Double.random(in: -10...10, using: &rng), y: Double.random(in: 8...24, using: &rng),
                        vx: cos(angle) * speed, vy: sin(angle) * speed, life: 0.9, size: Double.random(in: 0.5...1.1, using: &rng),
                        muddy: m.world.mud > 0.08))
                }
            }
        case .dig:
            let count = owed(.dirt, perSecond: 26, dt)
            for _ in 0..<count {
                particles.append(Particle(
                    kind: .dirt, x: x + scale * 12, y: 1,
                    vx: -side * Double.random(in: 18...46, using: &rng), vy: Double.random(in: 18...46, using: &rng),
                    life: 0.9, size: Double.random(in: 0.6...1.3, using: &rng)))
            }
        case .sniffSpot, .go(_, .sniff), .sniffAir:
            if due(.puff, every: 0.42, dt) {
                particles.append(Particle(kind: .puff, x: nose.x + side * 1.5, y: nose.y, vx: side * 3, vy: 3, life: 0.55, size: 0.9))
            }
        case .sneeze:
            if crossed(0.44) {
                for i in 0..<5 {
                    particles.append(Particle(kind: .puff, x: nose.x + side * 2, y: nose.y, vx: side * (14 + Double(i) * 5), vy: Double(i - 2) * 3, life: 0.55, size: 1.1))
                }
            }
        case .skid:
            let count = owed(.puff, perSecond: 22, dt)
            for _ in 0..<count {
                particles.append(Particle(kind: .puff, x: x + scale * 12, y: 1, vx: side * Double.random(in: 4...16, using: &rng), vy: Double.random(in: 2...10, using: &rng), life: 0.6, size: 1.5))
            }
        case .landed:
            if crossed(0.16) {
                for direction in [-1.0, 1.0] {
                    particles.append(Particle(kind: .puff, x: x + direction * 9, y: 1.5, vx: direction * 10, vy: 3, life: 0.6, size: 1.4))
                }
            }
        case .flop:
            if crossed(0.5) {
                for direction in [-1.0, 1.0] {
                    particles.append(Particle(kind: .puff, x: x + direction * 14, y: 1.5, vx: direction * 12, vy: 3, life: 0.7, size: 1.8))
                }
            }
        case .droop:
            if started || crossed(0.45) || crossed(0.9) {
                particles.append(Particle(kind: .whine, x: nose.x + 5, y: nose.y + 3, vx: 3, vy: 7, life: 1.0, size: 2.4))
            }
        case .startle, .watchBall:
            if started { particles.append(Particle(kind: .bang, x: top.x, y: top.y + 1, vx: 0, vy: 6, life: 0.7, size: 3.2)) }
        case .confused:
            if started { particles.append(Particle(kind: .query, x: top.x + 4, y: top.y + 1, vx: 0, vy: 3, life: 2.2, size: 3.4)) }
        default:
            break
        }
    }

    private mutating func heart(above top: CGPoint) {
        particles.append(Particle(
            kind: .heart, x: top.x + Double.random(in: -5...5, using: &rng), y: top.y,
            vx: Double.random(in: -2...2, using: &rng), vy: 9, life: 1.5, size: 2.3))
    }

    private mutating func due(_ kind: Particle.Kind, every interval: Double, _ dt: Double) -> Bool {
        owed(kind, perSecond: 1 / interval, dt) > 0
    }

    private mutating func owed(_ kind: Particle.Kind, perSecond rate: Double, _ dt: Double) -> Int {
        let total = (emitDebt[kind] ?? 0) + rate * dt
        let whole = Int(total)
        emitDebt[kind] = total - Double(whole)
        return whole
    }

    private mutating func moveParticles(_ dt: Double) {
        for i in particles.indices {
            particles[i].age += dt
            guard particles[i].age > 0 else { continue }
            switch particles[i].kind {
            case .drop, .dirt:
                particles[i].vy -= 190 * dt
            case .zzz:
                particles[i].vx += sin(particles[i].age * 3) * 2 * dt
            case .puff:
                particles[i].vx *= 1 - min(1, 3 * dt)
                particles[i].size += 2.2 * dt
            case .heart, .whine, .bang, .query:
                break
            }
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
        }
        particles.removeAll { $0.age >= $0.life || ($0.y < 0 && ($0.kind == .drop || $0.kind == .dirt)) }
        if particles.count > 160 { particles.removeFirst(particles.count - 160) }
    }
}
