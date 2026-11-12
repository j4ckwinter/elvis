import Foundation

/// The strip of screen Elvis lives in, measured in dog units. Ground is y = 0 and x grows to the right.
public enum Yard {
    public static let width = 230.0
    public static let height = 84.0
    public static let home = 112.0
    public static let leftEdge = 24.0
    public static let rightEdge = 184.0
    public static let door = 214.0
    /// Where Elvis sits to wait at the door.
    public static let doorSpot = 180.0
    public static let gravity = 260.0
}

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
    case startle, boundUp, droop, spin, confused
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

public struct Ball: Equatable, Sendable {
    public enum State: Equatable, Sendable { case flying, resting, carried }
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var state: State
    public var spin = 0.0
    public var restedFor = 0.0

    public init(x: Double, y: Double, vx: Double, vy: Double, state: State) {
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.state = state
    }
}

public struct World: Equatable, Sendable {
    public var x = Yard.home
    /// +1 facing right, -1 facing left.
    public var facing = 1.0
    public var mud = 0.0
    /// 1 straight after a test failure, fading back to 0.
    public var glum = 0.0
    public var ball: Ball?
    public var doorOpen = false
    /// Cursor position in yard units when it is close enough to be interesting.
    public var cursor: (x: Double, y: Double)?

    public init() {}

    public static func == (a: World, b: World) -> Bool {
        a.x == b.x && a.facing == b.facing && a.mud == b.mud && a.glum == b.glum && a.ball == b.ball
            && a.doorOpen == b.doorOpen && a.cursor?.x == b.cursor?.x && a.cursor?.y == b.cursor?.y
    }
}

public struct SplitMix: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
