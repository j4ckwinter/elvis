import CoreGraphics
import Foundation

public struct Pose: Equatable, Sendable {
    public var hip = CGPoint(x: -8, y: 18)
    public var shoulder = CGPoint(x: 8, y: 19)
    public var paws = [CGPoint(x: 9.5, y: 0), CGPoint(x: 7, y: 0), CGPoint(x: -10.5, y: 0), CGPoint(x: -7.5, y: 0)]
    public var rearBend = -1.0
    public var head = CGPoint(x: 15.5, y: 28)
    public var front = 0.0
    public var pitch = 0.0
    public var tilt = 0.0
    public var earLift = 0.0
    public var earDroop = 0.0
    public var earFling = 0.0
    public var tail = 0.5
    public var eyes = 1.0
    public var happyEyes = 0.0
    public var brow = 0.0
    public var look = CGPoint.zero
    public var mouth = 0.0
    public var tongue = 0.0
    public var lift = 0.0
    public var lean = 0.0
    public var turn = 1.0

    public init() {}

    public static let stand = Pose()

    public static var sit: Pose {
        var p = Pose()
        p.hip = CGPoint(x: -6, y: 6.2)
        p.shoulder = CGPoint(x: 5, y: 19.5)
        p.paws = [CGPoint(x: 7.5, y: 0), CGPoint(x: 5, y: 0), CGPoint(x: -0.5, y: 0), CGPoint(x: -3, y: 0)]
        p.rearBend = 1
        p.head = CGPoint(x: 10, y: 29.5)
        p.tail = -0.12
        return p
    }

    public static var lie: Pose {
        var p = Pose()
        p.hip = CGPoint(x: -9, y: 5.8)
        p.shoulder = CGPoint(x: 8, y: 7.2)
        p.paws = [CGPoint(x: 21, y: 0.3), CGPoint(x: 18.5, y: 0.3), CGPoint(x: -2.5, y: 0), CGPoint(x: -5, y: 0)]
        p.rearBend = 1
        p.head = CGPoint(x: 14, y: 16.5)
        p.tail = -0.1
        return p
    }

    public static var chinDown: Pose {
        var p = lie
        p.head = CGPoint(x: 17.5, y: 5.6)
        p.pitch = -0.06
        return p
    }

    public static var sploot: Pose {
        var p = Pose()
        p.hip = CGPoint(x: -9, y: 5.2)
        p.shoulder = CGPoint(x: 8, y: 5.6)
        p.paws = [CGPoint(x: 22, y: 0.3), CGPoint(x: 19.5, y: 0.3), CGPoint(x: -25, y: 0.6), CGPoint(x: -22.5, y: 0.6)]
        p.rearBend = -1
        p.head = CGPoint(x: 17.5, y: 5.4)
        p.tail = -0.3
        return p
    }

    public static var bow: Pose {
        var p = Pose()
        p.hip = CGPoint(x: -7.5, y: 19)
        p.shoulder = CGPoint(x: 8.5, y: 7.2)
        p.paws = [CGPoint(x: 21, y: 0.2), CGPoint(x: 18.5, y: 0.2), CGPoint(x: -10, y: 0), CGPoint(x: -7, y: 0)]
        p.head = CGPoint(x: 16.5, y: 13.5)
        p.tail = 1.15
        return p
    }

    public static var noseDown: Pose {
        var p = Pose()
        p.shoulder = CGPoint(x: 8, y: 17.5)
        p.head = CGPoint(x: 17, y: 8.6)
        p.pitch = -0.62
        p.tail = 0.85
        return p
    }

    public func mixed(with other: Pose, _ t: Double) -> Pose {
        if t <= 0 { return self }
        if t >= 1 { return other }
        var p = Pose()
        p.hip = hip.mixed(other.hip, t)
        p.shoulder = shoulder.mixed(other.shoulder, t)
        p.paws = zip(paws, other.paws).map { $0.mixed($1, t) }
        p.rearBend = rearBend.mixed(other.rearBend, t)
        p.head = head.mixed(other.head, t)
        p.front = front.mixed(other.front, t)
        p.pitch = pitch.mixed(other.pitch, t)
        p.tilt = tilt.mixed(other.tilt, t)
        p.earLift = earLift.mixed(other.earLift, t)
        p.earDroop = earDroop.mixed(other.earDroop, t)
        p.earFling = earFling.mixed(other.earFling, t)
        p.tail = tail.mixed(other.tail, t)
        p.eyes = eyes.mixed(other.eyes, t)
        p.happyEyes = happyEyes.mixed(other.happyEyes, t)
        p.brow = brow.mixed(other.brow, t)
        p.look = look.mixed(other.look, t)
        p.mouth = mouth.mixed(other.mouth, t)
        p.tongue = tongue.mixed(other.tongue, t)
        p.lift = lift.mixed(other.lift, t)
        p.lean = lean.mixed(other.lean, t)
        p.turn = turn.mixed(other.turn, t)
        return p
    }

    public var isFinite: Bool {
        let points = [hip, shoulder, head, look] + paws
        let scalars = [rearBend, front, pitch, tilt, earLift, earDroop, earFling, tail, eyes, happyEyes, brow, mouth, tongue, lift, lean, turn]
        return points.allSatisfy { $0.x.isFinite && $0.y.isFinite } && scalars.allSatisfy(\.isFinite)
    }
}

extension Double {
    func mixed(_ other: Double, _ t: Double) -> Double { self + (other - self) * t }
}

extension CGPoint {
    func mixed(_ other: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: x + (other.x - x) * t, y: y + (other.y - y) * t)
    }

    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: Double) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
    var length: Double { (x * x + y * y).squareRoot() }

    func rotated(_ angle: Double) -> CGPoint {
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: x * c - y * s, y: x * s + y * c)
    }
}

func ease(_ t: Double) -> Double {
    let x = min(1, max(0, t))
    return x * x * (3 - 2 * x)
}

func swell(_ t: Double, _ duration: Double, attack: Double = 0.25, release: Double = 0.25) -> Double {
    min(ease(t / attack), ease((duration - t) / release))
}
