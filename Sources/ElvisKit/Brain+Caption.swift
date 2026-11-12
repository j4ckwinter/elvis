extension Brain {
    public var caption: String {
        switch action {
        case .sleep, .sleepSigh: return "fast asleep"
        case .sleepTwitch: return "asleep, paws going"
        case .dream: return "dreaming about a tennis ball"
        case .sleepWag: return "asleep, but pleased about something"
        case .doze: return "dozing with one ear on you"
        case .rest, .sigh, .earFlap, .yawn: return "having a lie down"
        case .sit, .lookAround: return "keeping an eye on things"
        case .wagAtYou, .checkIn: return "checking you still like him"
        case .scratch: return "dealing with an itch"
        case .sneeze: return "surprised by his own sneeze"
        case .stretch: return "having a big stretch"
        case .circle: return "choosing the exact right spot"
        case .chaseTail: return "has spotted his tail again"
        case .dizzy: return "regretting the tail thing"
        case .shake: return "sharing the mud around"
        case .petted: return "being a very good boy"
        case .nudgeBall: return "wondering if you saw the ball"
        case .go(_, let gait):
            switch gait {
            case .sniff: return "following a very important smell"
            case .slink, .trudge: return "carrying on, bravely"
            case .prance: return "bringing it back, look, look"
            case .run: return "going as fast as he can"
            case .walk, .trot: return world.doorOpen ? "off to the door" : "on his way somewhere"
            }
        case .sniffSpot: return "sure there's something right here"
        case .dig: return "helping with the edits"
        case .point: return "pointing at the terminal"
        case .sniffAir: return "smelling the internet"
        case .pant: return "catching his breath"
        case .listen: return "listening for the helpers"
        case .startle: return "awake! awake"
        case .boundUp: return "ready, so ready"
        case .droop: return "sorry about the tests"
        case .spin: return "they pass, they pass"
        case .confused: return "not sure what just happened"
        case .buryBone: return "burying that one for later"
        case .bark: return "telling the whole street"
        case .watchBall, .chaseBall, .skid, .grabBall: return "ball ball ball"
        case .dropBall, .proudSit: return "brought you this"
        case .flop: return "done in, and delighted"
        case .stare, .tiltHead, .pawDoor, .glanceDoor: return "waiting by the door for you"
        case .lieByDoor: return "still waiting by the door"
        case .relief: return "you answered"
        case .held: return "being carried, legs going"
        case .landed: return "back on solid ground"
        }
    }

    public var company: String? {
        let counts = tally
        var parts: [String] = []
        if counts.working > 0 { parts.append("\(counts.working) \(counts.working == 1 ? "session" : "sessions") working") }
        if counts.waiting > 0 { parts.append("\(counts.waiting) waiting for you") }
        if counts.helpers > 0 { parts.append("\(counts.helpers) \(counts.helpers == 1 ? "helper" : "helpers") out") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
