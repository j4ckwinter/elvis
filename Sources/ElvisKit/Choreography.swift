import Foundation

/// Maps an action and the time spent in it to a pose. Pure, so any frame can be rendered on its own.
public enum Choreography {
    static let tau = 2 * Double.pi
    /// How far off the ground he dangles while carried, in dog units.
    static let carryHeight = 14.0

    public static func pose(for moment: Moment) -> Pose {
        let elapsed = moment.elapsed
        let length = max(moment.length, 0.01)
        let oddSerial = moment.serial % 2 == 1

        switch moment.action {
        case .sleep: return asleep(elapsed)
        case .sleepTwitch: return sleepTwitch(elapsed: elapsed, length: length)
        case .dream: return dream(elapsed: elapsed, length: length)
        case .sleepSigh: return sleepSigh(elapsed: elapsed, length: length)
        case .sleepWag: return sleepWag(elapsed: elapsed, length: length)
        case .doze: return doze(elapsed: elapsed)
        case .rest: return rest(elapsed: elapsed)
        case .sigh: return sigh(elapsed: elapsed, length: length)
        case .earFlap: return earFlap(elapsed: elapsed, length: length)
        case .yawn: return yawn(elapsed: elapsed, length: length)

        case .sit: return sit(elapsed: elapsed)
        case .lookAround: return lookAround(elapsed: elapsed, length: length)
        case .wagAtYou: return wagAtYou(elapsed: elapsed)
        case .scratch: return scratch(elapsed: elapsed, length: length)
        case .sneeze: return sneeze(elapsed: elapsed)
        case .stretch: return stretch(elapsed: elapsed, length: length)
        case .circle: return circle(elapsed: elapsed, length: length)
        case .chaseTail: return chaseTail(elapsed: elapsed)
        case .dizzy: return dizzy(elapsed: elapsed, length: length)
        case .shake: return shake(elapsed: elapsed, length: length)
        case .petted: return petted(elapsed: elapsed)
        case .nudgeBall: return nudgeBall(elapsed: elapsed, length: length)

        case .go(_, let style): return go(style, elapsed: elapsed, world: moment.world)

        case .sniffSpot: return sniffSpot(elapsed: elapsed, length: length)
        case .dig: return dig(elapsed: elapsed, length: length)
        case .point: return point(elapsed: elapsed)
        case .sniffAir: return sniffAir(elapsed: elapsed, length: length)
        case .checkIn: return checkIn(elapsed: elapsed, oddSerial: oddSerial)
        case .pant: return pant(elapsed: elapsed)

        case .startle: return startle(elapsed: elapsed, length: length)
        case .boundUp: return boundUp(elapsed: elapsed, length: length)
        case .droop: return droop(elapsed: elapsed, length: length)
        case .spin: return spin(elapsed: elapsed, length: length)
        case .confused: return confused(elapsed: elapsed)
        case .flop: return flop(elapsed: elapsed, length: length)
        case .relief: return relief(elapsed: elapsed, length: length)

        case .watchBall: return watchBall(elapsed: elapsed)
        case .chaseBall: return gait(.run, elapsed)
        case .skid: return skid(elapsed: elapsed, length: length)
        case .grabBall: return grabBall(elapsed: elapsed, length: length)
        case .dropBall: return dropBall(elapsed: elapsed, length: length)
        case .proudSit: return proudSit(elapsed: elapsed)

        case .stare: return stare(elapsed: elapsed)
        case .tiltHead: return tiltHead(elapsed: elapsed, length: length, oddSerial: oddSerial)
        case .pawDoor: return pawDoor(elapsed: elapsed, length: length)
        case .glanceDoor: return glanceDoor(elapsed: elapsed, length: length)
        case .lieByDoor: return lieByDoor(elapsed: elapsed)

        case .held: return held(elapsed: elapsed)
        case .landed: return landed(elapsed: elapsed)
        }
    }

    static func asleep(_ t: Double) -> Pose {
        var p = Pose.chinDown
        breathe(&p, t, depth: 0.5, rate: 1.05)
        p.eyes = 0
        p.tail = -0.1
        return p
    }

    static func breathe(_ p: inout Pose, _ t: Double, depth: Double, rate: Double) {
        let breath = sin(t * rate) * depth
        p.shoulder.y += breath
        p.hip.y += breath * 0.6
    }

    static func faceYou(_ p: inout Pose) {
        p.front = 1
        p.head.x -= 1.6
        p.pitch = 0
    }

    static func happy(_ p: inout Pose, _ t: Double) {
        p.tongue = 0.85 + sin(t * 9) * 0.12
        p.mouth = 0.6
        p.brow = 0.5
    }

    static func droopEars(_ p: inout Pose, _ amount: Double) {
        p.earDroop = max(p.earDroop, amount)
        p.brow = min(p.brow, -amount)
    }
}
