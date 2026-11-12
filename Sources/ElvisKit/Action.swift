public enum Gait: Equatable, Sendable {
    case walk, sniff, trot, prance, run, slink, trudge

    public var speed: Double {
        switch self {
        case .walk: return 15
        case .sniff: return 10
        case .trot: return 30
        case .prance: return 21
        case .run: return 68
        case .slink: return 8
        case .trudge: return 9
        }
    }
}

public enum Action: Equatable, Sendable {
    case sleep, sleepTwitch, dream, sleepSigh, sleepWag
    case doze, rest, sigh, earFlap
    case sit, lookAround, wagAtYou, scratch, sneeze, yawn, stretch, circle, chaseTail, dizzy, shake, petted, nudgeBall
    case go(to: Double, gait: Gait)
    case sniffSpot, dig, point, sniffAir, checkIn, pant
    case startle, boundUp, droop, spin, confused, buryBone, bark
    case watchBall, chaseBall, skid, grabBall, dropBall, proudSit
    case flop
    case stare, tiltHead, pawDoor, glanceDoor, lieByDoor, relief
    case held, landed

    public var isAsleep: Bool {
        switch self {
        case .sleep, .sleepTwitch, .dream, .sleepSigh, .sleepWag: return true
        default: return false
        }
    }

    public var isLyingDown: Bool {
        switch self {
        case .doze, .rest, .sigh, .earFlap, .flop, .lieByDoor: return true
        default: return isAsleep
        }
    }
}
