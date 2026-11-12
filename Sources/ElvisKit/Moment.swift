public struct Moment: Sendable {
    public var action: Action
    public var elapsed: Double
    public var length: Double
    public var serial: Int
    public var world: World
    public var mode: Brain.Mode
    public var now: Double

    public init(action: Action, elapsed: Double, length: Double, serial: Int = 0, world: World = World(), mode: Brain.Mode = .calm, now: Double = 0) {
        self.action = action
        self.elapsed = elapsed
        self.length = length
        self.serial = serial
        self.world = world
        self.mode = mode
        self.now = now
    }
}
