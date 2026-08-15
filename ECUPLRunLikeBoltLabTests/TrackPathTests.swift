import XCTest
@testable import ECUPLRunLikeBoltLab

final class TrackPathTests: XCTestCase {
    func testRectangleProducesReasonableLoop() throws {
        let config = TrackConfiguration(name: "Test", corners: [Coordinate(latitude: 31.2300, longitude: 121.4700), Coordinate(latitude: 31.2300, longitude: 121.4710), Coordinate(latitude: 31.2305, longitude: 121.4710), Coordinate(latitude: 31.2305, longitude: 121.4700)], speedMetersPerSecond: 3, laps: 2)
        let path = try TrackPath(configuration: config)
        XCTAssertGreaterThan(path.length, 200)
        XCTAssertLessThan(path.length, 400)
        XCTAssertFalse(path.sampled().isEmpty)
    }

    func testSamplingClosesAtExactLoopDistance() throws {
        let config = TrackConfiguration(name: "Test", corners: [Coordinate(latitude: 31.2300, longitude: 121.4700), Coordinate(latitude: 31.2300, longitude: 121.4710), Coordinate(latitude: 31.2305, longitude: 121.4710), Coordinate(latitude: 31.2305, longitude: 121.4700)])
        let path = try TrackPath(configuration: config)
        let samples = path.sampled()

        let first = try XCTUnwrap(samples.first)
        let last = try XCTUnwrap(samples.last)
        XCTAssertEqual(first.coordinate.latitude, last.coordinate.latitude, accuracy: 0.000_000_1)
        XCTAssertEqual(first.coordinate.longitude, last.coordinate.longitude, accuracy: 0.000_000_1)
        XCTAssertEqual(last.distance, path.length, accuracy: 0.001)
    }

    func testExporterRejectsZeroSpeed() {
        var config = TrackConfiguration()
        config.speedMetersPerSecond = 0
        XCTAssertThrowsError(try GPXExporter.export(configuration: config))
    }

    func testExporterProducesGPX11WithoutLegacySpeedElement() throws {
        let config = TrackConfiguration(name: "A&B", corners: [Coordinate(latitude: 31.2300, longitude: 121.4700), Coordinate(latitude: 31.2300, longitude: 121.4710), Coordinate(latitude: 31.2305, longitude: 121.4710), Coordinate(latitude: 31.2305, longitude: 121.4700)], speedMetersPerSecond: 3, laps: 2, scheduledStart: Date(timeIntervalSince1970: 0))
        let url = try GPXExporter.export(configuration: config)
        let xml = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(xml.contains("<name>A&amp;B</name>"))
        XCTAssertFalse(xml.contains("<speed>"))
        XCTAssertTrue(xml.contains("<time>1970-01-01T00:00:00Z</time>"))
    }
}
