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

    func validateForExport() throws {
        guard speedMetersPerSecond.isFinite, speedMetersPerSecond > 0, speedMetersPerSecond <= 100 else {
            throw ConfigurationError.invalidSpeed
        }
        guard (1...1_000).contains(laps) else { throw ConfigurationError.invalidLaps }
    }

    enum ConfigurationError: LocalizedError {
        case invalidSpeed
        case invalidLaps

        var errorDescription: String? {
            switch self {
            case .invalidSpeed: return "速度必须大于 0 且不超过 100 米/秒"
            case .invalidLaps: return "圈数必须在 1 到 1000 之间"
            }
        }
    }
}
