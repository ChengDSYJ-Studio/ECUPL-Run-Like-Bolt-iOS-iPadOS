import Foundation
import CoreLocation

struct TrackPath {
    struct Sample: Identifiable { let id = UUID(); let coordinate: CLLocationCoordinate2D; let distance: CLLocationDistance }

    let points: [CLLocationCoordinate2D]
    let cumulative: [CLLocationDistance]
    let length: CLLocationDistance

    init(configuration: TrackConfiguration) throws {
        guard configuration.corners.count == 4 else { throw TrackError.cornerCount }
        let corners = try configuration.corners.map { point -> CLLocationCoordinate2D in
            guard (-90...90).contains(point.latitude), (-180...180).contains(point.longitude) else { throw TrackError.invalidCoordinate }
            return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }
        let ordered = Self.order(corners)
        let rounding = 0.22
        let entries = (0..<4).map { Self.interpolate(ordered[$0], ordered[($0 + 3) % 4], rounding) }
        let exits = (0..<4).map { Self.interpolate(ordered[$0], ordered[($0 + 1) % 4], rounding) }
        var built: [CLLocationCoordinate2D] = [exits[0]]
        for index in 0..<4 {
            let next = (index + 1) % 4
            let entry = entries[next], corner = ordered[next], exit = exits[next]
            built.append(entry)
            for step in 1...32 {
                let t = Double(step) / 32
                built.append(Self.quadratic(entry, corner, exit, t))
            }
        }
        var sums: [CLLocationDistance] = [0]
        for index in 1..<built.count { sums.append(sums[index - 1] + Self.distance(built[index - 1], built[index])) }
        let fullLength = sums.last! + Self.distance(built.last!, built.first!)
        guard (20...10_000).contains(fullLength) else { throw TrackError.invalidLength }
        points = built; cumulative = sums; length = fullLength
    }

    func sampled(spacingMeters: CLLocationDistance = 5) -> [Sample] {
        let count = max(2, Int(ceil(length / spacingMeters)))
        return (0...count).map { index in sample(at: min(Double(index) * length / Double(count), length - 0.01)) }
    }

    func sample(at distance: CLLocationDistance) -> Sample {
        let normalized = distance.truncatingRemainder(dividingBy: length)
        for index in 1..<cumulative.count where normalized <= cumulative[index] {
            return interpolateSegment(from: index - 1, to: index, target: normalized - cumulative[index - 1], total: distance)
        }
        return interpolateSegment(from: points.count - 1, to: 0, target: normalized - cumulative.last!, total: distance)
    }

    private func interpolateSegment(from: Int, to: Int, target: Double, total: Double) -> Sample {
        let segment = Self.distance(points[from], points[to])
        return Sample(coordinate: Self.interpolate(points[from], points[to], segment == 0 ? 0 : target / segment), distance: total)
    }

    private static func distance(_ left: CLLocationCoordinate2D, _ right: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: left.latitude, longitude: left.longitude).distance(from: CLLocation(latitude: right.latitude, longitude: right.longitude))
    }

    private static func order(_ source: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        let centerLat = source.map(\.latitude).reduce(0, +) / Double(source.count)
        let centerLon = source.map(\.longitude).reduce(0, +) / Double(source.count)
        let scale = cos(centerLat * .pi / 180)
        return source.sorted { atan2($0.latitude - centerLat, ($0.longitude - centerLon) * scale) < atan2($1.latitude - centerLat, ($1.longitude - centerLon) * scale) }
    }

    private static func interpolate(_ left: CLLocationCoordinate2D, _ right: CLLocationCoordinate2D, _ fraction: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: left.latitude + (right.latitude - left.latitude) * fraction, longitude: left.longitude + (right.longitude - left.longitude) * fraction)
    }

    private static func quadratic(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D, _ t: Double) -> CLLocationCoordinate2D {
        let u = 1 - t
        return CLLocationCoordinate2D(latitude: u*u*a.latitude + 2*u*t*b.latitude + t*t*c.latitude, longitude: u*u*a.longitude + 2*u*t*b.longitude + t*t*c.longitude)
    }

    enum TrackError: LocalizedError { case cornerCount, invalidCoordinate, invalidLength
        var errorDescription: String? { switch self { case .cornerCount: return "需要四个角点"; case .invalidCoordinate: return "经纬度超出范围"; case .invalidLength: return "路线周长必须在 20 米到 10 千米之间" } }
    }
}
