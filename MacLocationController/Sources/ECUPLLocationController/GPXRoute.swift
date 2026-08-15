import CoreLocation
import Foundation
import MapKit

struct GPXRoute: Identifiable {
    let id = UUID()
    let url: URL
    let coordinates: [CLLocationCoordinate2D]
    let firstTime: Date?
    let lastTime: Date?

    var name: String { url.lastPathComponent }
    var pointCount: Int { coordinates.count }

    var durationText: String {
        guard let firstTime, let lastTime else { return "无时间戳" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(0, lastTime.timeIntervalSince(firstTime))) ?? "—"
    }

    var region: MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLatitude = latitudes.min() ?? first.latitude
        let maxLatitude = latitudes.max() ?? first.latitude
        let minLongitude = longitudes.min() ?? first.longitude
        let maxLongitude = longitudes.max() ?? first.longitude
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.001, (maxLatitude - minLatitude) * 1.35),
                longitudeDelta: max(0.001, (maxLongitude - minLongitude) * 1.35)
            )
        )
    }

    static func load(from url: URL) throws -> GPXRoute {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber, size.intValue > 128 * 1024 * 1024 {
            throw GPXError.fileTooLarge
        }
        guard let parser = XMLParser(contentsOf: url) else { throw GPXError.unreadable }
        let delegate = GPXParserDelegate()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else {
            if let error = delegate.error { throw error }
            throw GPXError.invalidXML(parser.parserError?.localizedDescription ?? "未知 XML 错误")
        }
        guard delegate.coordinates.count >= 2 else { throw GPXError.notEnoughPoints }
        return GPXRoute(
            url: url,
            coordinates: delegate.coordinates,
            firstTime: delegate.times.compactMap { $0 }.first,
            lastTime: delegate.times.compactMap { $0 }.last
        )
    }

    enum GPXError: LocalizedError {
        case unreadable
        case fileTooLarge
        case invalidXML(String)
        case invalidCoordinate
        case notEnoughPoints
        case tooManyPoints

        var errorDescription: String? {
            switch self {
            case .unreadable: return "无法读取 GPX 文件"
            case .fileTooLarge: return "GPX 文件超过 128 MB 上限"
            case .invalidXML(let detail): return "GPX XML 无效：\(detail)"
            case .invalidCoordinate: return "GPX 中存在无效经纬度"
            case .notEnoughPoints: return "GPX 至少需要两个 trkpt 轨迹点"
            case .tooManyPoints: return "GPX 超过 250000 个轨迹点上限"
            }
        }
    }
}

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    var coordinates: [CLLocationCoordinate2D] = []
    var times: [Date?] = []
    var error: GPXRoute.GPXError?
    private var insideTrackPoint = false
    private var collectingTime = false
    private var currentTime = ""
    private let formatter = ISO8601DateFormatter()

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if localName == "trkpt" {
            guard coordinates.count < 250_000 else {
                error = .tooManyPoints
                parser.abortParsing()
                return
            }
            guard let latitudeText = attributeDict["lat"],
                  let longitudeText = attributeDict["lon"],
                  let latitude = Double(latitudeText),
                  let longitude = Double(longitudeText),
                  latitude.isFinite, longitude.isFinite,
                  (-90...90).contains(latitude), (-180...180).contains(longitude) else {
                error = .invalidCoordinate
                parser.abortParsing()
                return
            }
            coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            times.append(nil)
            insideTrackPoint = true
        } else if localName == "time", insideTrackPoint {
            collectingTime = true
            currentTime = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collectingTime { currentTime += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if localName == "time", collectingTime {
            collectingTime = false
            times[times.count - 1] = formatter.date(from: currentTime.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if localName == "trkpt" {
            insideTrackPoint = false
        }
    }
}
