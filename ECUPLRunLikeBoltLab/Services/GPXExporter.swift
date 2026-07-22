import Foundation

enum GPXExporter {
    static func export(configuration: TrackConfiguration) throws -> URL {
        let path = try TrackPath(configuration: configuration)
        let start = configuration.scheduledStart ?? Date()
        let interval = 5.0 / configuration.speedMetersPerSecond
        let formatter = ISO8601DateFormatter()
        let samples = path.sampled()
        var rows = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<gpx version=\"1.1\" creator=\"ECUPL Run Like Bolt Lab\" xmlns=\"http://www.topografix.com/GPX/1/1\">", "  <trk><name>\(escape(configuration.name))</name><trkseg>"]
        for lap in 0..<configuration.laps {
            for (index, sample) in samples.enumerated() {
                let date = start.addingTimeInterval((Double(lap * samples.count + index)) * interval)
                rows.append("    <trkpt lat=\"\(sample.coordinate.latitude)\" lon=\"\(sample.coordinate.longitude)\"><time>\(formatter.string(from: date))</time><speed>\(configuration.speedMetersPerSecond)</speed></trkpt>")
            }
        }
        rows += ["  </trkseg></trk>", "</gpx>"]
        let safeName = configuration.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)-\(configuration.laps)圈.gpx")
        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ text: String) -> String { text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;") }
}
