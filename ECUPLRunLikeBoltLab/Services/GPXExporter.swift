import Foundation

enum GPXExporter {
    static func export(configuration: TrackConfiguration) throws -> URL {
        try configuration.validateForExport()
        let path = try TrackPath(configuration: configuration)
        let start = configuration.scheduledStart ?? Date()
        let formatter = ISO8601DateFormatter()
        let samples = path.sampled()
        let pointCount = 1 + configuration.laps * (samples.count - 1)
        guard pointCount <= 250_000 else { throw ExportError.tooManyPoints(pointCount) }
        var rows = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<gpx version=\"1.1\" creator=\"ECUPL Run Like Bolt Lab\" xmlns=\"http://www.topografix.com/GPX/1/1\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 https://www.topografix.com/GPX/1/1/gpx.xsd\">",
            "  <trk><name>\(escape(configuration.name))</name><trkseg>"
        ]
        rows.reserveCapacity(pointCount + 5)
        for lap in 0..<configuration.laps {
            for (index, sample) in samples.enumerated() {
                if lap > 0, index == 0 { continue }
                let totalDistance = Double(lap) * path.length + sample.distance
                let date = start.addingTimeInterval(totalDistance / configuration.speedMetersPerSecond)
                rows.append("    <trkpt lat=\"\(sample.coordinate.latitude)\" lon=\"\(sample.coordinate.longitude)\"><time>\(formatter.string(from: date))</time></trkpt>")
            }
        }
        rows += ["  </trkseg></trk>", "</gpx>"]
        let safeName = configuration.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)-\(configuration.laps)圈.gpx")
        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ text: String) -> String { text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;") }

    enum ExportError: LocalizedError {
        case tooManyPoints(Int)

        var errorDescription: String? {
            switch self {
            case .tooManyPoints(let count): return "路线将生成 \(count) 个轨迹点，超过 250000 点上限；请减少圈数"
            }
        }
    }
}
