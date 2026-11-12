public struct World: Equatable, Sendable {
    public var x = Yard.home
    public var facing = 1.0
    public var mud = 0.0
    public var glum = 0.0
    public var ball: Ball?
    public var doorOpen = false
    public var cursor: (x: Double, y: Double)?

    public init() {}

    public static func == (a: World, b: World) -> Bool {
        a.x == b.x && a.facing == b.facing && a.mud == b.mud && a.glum == b.glum && a.ball == b.ball
            && a.doorOpen == b.doorOpen && a.cursor?.x == b.cursor?.x && a.cursor?.y == b.cursor?.y
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

    mutating func fly(_ dt: Double) {
        vy -= Yard.gravity * dt
        x += vx * dt
        y += vy * dt
        spin += vx * dt / 3
        if x < 5 || x > Yard.width - 5 {
            x = min(Yard.width - 5, max(5, x))
            vx *= -0.5
        }
        if y <= 0 {
            y = 0
            if abs(vy) < 26 {
                state = .resting
                vx = 0
                vy = 0
                restedFor = 0
            } else {
                vy *= -0.48
                vx *= 0.6
            }
        }
    }
}
