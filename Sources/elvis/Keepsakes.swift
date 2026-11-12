import Foundation

struct Keepsakes: Codable {
    var sounds = true
    var leftCorner = false
    var mud = 0.0
    var day = ""
    var spot: Spot?

    struct Spot: Codable {
        var x: Double
        var y: Double
    }

    static var path: String { EventSocket.directory + "/state.json" }

    static func load() -> Keepsakes {
        guard let data = FileManager.default.contents(atPath: path),
              let saved = try? JSONDecoder().decode(Keepsakes.self, from: data)
        else { return Keepsakes() }
        return saved
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: URL(fileURLWithPath: Keepsakes.path), options: .atomic)
    }

    static var today: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
