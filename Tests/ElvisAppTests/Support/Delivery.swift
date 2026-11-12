import Foundation
import Testing

struct Delivery {
    let wire: String
    let fields: [String: String]

    init(only lines: [String]) throws {
        try #require(lines.count == 1)
        wire = lines[0]
        fields = try #require(JSONSerialization.jsonObject(with: Data(wire.utf8)) as? [String: String])
    }
}
