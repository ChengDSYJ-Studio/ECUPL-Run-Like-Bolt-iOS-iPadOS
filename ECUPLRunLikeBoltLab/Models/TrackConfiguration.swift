import Foundation

struct Coordinate: Codable, Hashable, Identifiable {
    var id = UUID()
    var latitude: Double
    var longitude: Double

    enum CodingKeys: String, CodingKey { case latitude, longitude }
}

struct TrackConfiguration: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String = "未命名操场"
    var corners: [Coordinate] = Array(repeating: Coordinate(latitude: 0, longitude: 0), count: 4)
    var speedMetersPerSecond: Double = 3.0
    var laps: Int = 5
    var scheduledStart: Date?

    enum CodingKeys: String, CodingKey { case name, corners, speedMetersPerSecond, laps, scheduledStart }
}
