extension Brain {
    mutating func chooseNext() -> [Step] {
        if hovering, pettedThisHover, mode != .waiting || abs(world.x - Yard.doorSpot) < 2 {
            return [Step(action.isAsleep ? .sleep : .petted, action.isAsleep ? 4 : 1.8)]
        }
        switch mode {
        case .waiting: return nextWhileWaiting()
        case .working: return nextWhileWorking()
        case .calm: return nextWhileCalm()
        }
    }

    private mutating func nextWhileWaiting() -> [Step] {
        if abs(world.x - Yard.doorSpot) > 1 {
            return [Step(.go(to: Yard.doorSpot, gait: .trot))]
        }
        world.facing = 1
        if now - modeSince > 150 {
            return [Step(.lieByDoor, random(8, 14))]
        }
        if action != .stare { return [Step(.stare, random(3, 6))] }
        switch Int.random(in: 0..<3, using: &rng) {
        case 0: return [Step(.tiltHead, 1.8)]
        case 1: return [Step(.pawDoor, 1.9)]
        default: return [Step(.glanceDoor, 1.5)]
        }
    }

    private mutating func nextWhileWorking() -> [Step] {
        let gait: Gait = world.glum > 0.3 ? .slink : .sniff
        let recent = now - flavourAt < 8 ? flavour : nil
        flavour = nil
        let roll = Double.random(in: 0...1, using: &rng)

        if world.glum < 0.3 {
            if roll < 0.04 { return [Step(.chaseTail, 2.2), Step(.startle, 0.5)] }
            if roll < 0.13 { return [Step(.checkIn, 1.9)] }
            if now - modeSince > 25 * 60, roll < 0.2 { return [Step(.pant, 4)] }
        }
        switch recent {
        case .edit:
            return [Step(.go(to: spot(within: 26), gait: gait)), Step(.dig, 2.6)]
        case .shell:
            if roll < 0.6 { return [Step(.point, random(2.4, 3.8))] }
        case .web:
            return [Step(.sniffAir, 2.4)]
        case .read, .other, nil:
            break
        }
        let trail: Gait = world.glum > 0.3 ? .slink : (roll > 0.8 ? .trot : gait)
        return [Step(.go(to: spot(within: 90), gait: trail)), Step(.sniffSpot, random(1.4, 2.8))]
    }

    private mutating func nextWhileCalm() -> [Step] {
        let settled = now - max(settledSince, modeSince)
        let lying = action.isLyingDown

        if world.mud > 0.5, !action.isAsleep, action != .shake, chance(0.5) {
            return lying ? [Step(.sit, 0.8), Step(.shake, 1.7)] : [Step(.shake, 1.7)]
        }
        if settled < tuning.awakeFor {
            switch Int.random(in: 0..<12, using: &rng) {
            case 0, 1: return [Step(.sit, random(2.5, 4.5))]
            case 2, 3: return [Step(.lookAround, random(2.5, 4))]
            case 4: return [Step(.wagAtYou, 2.2)]
            case 5: return [Step(.scratch, 2.3)]
            case 6: return [Step(.sneeze, 1.0), Step(.sit, 1.2)]
            case 7: return [Step(.chaseTail, 2.6), Step(.dizzy, 1.6)]
            case 8:
                if let ball = world.ball, ball.state == .resting {
                    let side = world.x <= ball.x ? -1.0 : 1.0
                    return [Step(.go(to: ball.x + side * 14, gait: .trot)), Step(.nudgeBall, 0.7), Step(.wagAtYou, 2.4)]
                }
                return [Step(.stretch, 2.2)]
            case 9: return [Step(.go(to: spot(within: 40), gait: .walk)), Step(.sniffSpot, 1.6)]
            default: return [Step(.sit, random(2, 3.5))]
            }
        }
        if settled < tuning.restUntil {
            if !lying { return [Step(.circle, 1.7), Step(.rest, random(5, 8))] }
            switch Int.random(in: 0..<8, using: &rng) {
            case 0: return [Step(.earFlap, 1.0)]
            case 1: return [Step(.sigh, 2.0)]
            case 2: return [Step(.yawn, 2.0)]
            default: return [Step(.rest, random(5, 9))]
            }
        }
        if settled < tuning.dozeUntil {
            if !lying { return [Step(.circle, 1.7), Step(.doze, random(8, 12))] }
            return [Step(.doze, random(8, 12))]
        }
        if !lying { return [Step(.circle, 1.7), Step(.doze, 6)] }
        if action == .sleep {
            switch Int.random(in: 0..<5, using: &rng) {
            case 0: return [Step(.dream, 5.5)]
            case 1: return [Step(.sleepSigh, 2.4)]
            case 2: return [Step(.sleepWag, 2.2)]
            default: return [Step(.sleepTwitch, 2.6)]
            }
        }
        return [Step(.sleep, random(12, 28))]
    }

    private mutating func spot(within reach: Double) -> Double {
        let low = max(Yard.leftEdge, world.x - reach)
        let high = min(Yard.rightEdge, world.x + reach)
        guard low < high else { return min(Yard.rightEdge, max(Yard.leftEdge, world.x)) }
        for _ in 0..<4 {
            let candidate = random(low, high)
            if abs(candidate - world.x) > min(12, reach / 2) { return candidate }
        }
        return random(low, high)
    }

    private mutating func random(_ low: Double, _ high: Double) -> Double {
        Double.random(in: low...high, using: &rng)
    }
}
