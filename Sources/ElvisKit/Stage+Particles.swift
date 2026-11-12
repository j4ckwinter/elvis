import CoreGraphics
import Foundation

extension Stage {
    public mutating func showWhine(at m: Moment) {
        let pose = shown
        let mouth = mouthPoint(pose, x: m.world.x, scale: facing)
        for i in 0..<3 {
            particles.append(Particle(kind: .whine, x: mouth.x + Double(i) * 1.5 * (facing >= 0 ? 1 : -1), y: mouth.y + 2, vx: 5 * (facing >= 0 ? 1 : -1), vy: 6, age: -Double(i) * 0.3, life: 1.1, size: 2.4))
        }
    }

    private func mouthPoint(_ pose: Pose, x: Double, scale: Double) -> CGPoint {
        let local = pose.front > 0.5
            ? pose.head + CGPoint(x: 0, y: -3.5)
            : pose.head + CGPoint(x: 11.5, y: -1.5).rotated(pose.pitch)
        return CGPoint(x: x + scale * local.x, y: local.y + pose.lift)
    }

    mutating func emit(_ m: Moment, pose: Pose, scale: Double, started: Bool, dt: Double) {
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

    mutating func moveParticles(_ dt: Double) {
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
