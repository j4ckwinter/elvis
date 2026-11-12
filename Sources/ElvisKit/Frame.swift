public struct Particle: Sendable {
    public enum Kind: Sendable { case zzz, heart, drop, dirt, puff, whine, bang, query, woof }
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

public struct Frame: Sendable {
    public var pose = Pose()
    public var action = Action.sit
    public var elapsed = 0.0
    public var x = Yard.home
    public var facing = 1.0
    public var ears = [0.0, 0.0]
    public var particles: [Particle] = []
    public var ball: Ball?
    public var doorAlpha = 0.0
    public var mud = 0.0
    public var trailTo: Double?
    public var time = 0.0
    public init() {}
}
