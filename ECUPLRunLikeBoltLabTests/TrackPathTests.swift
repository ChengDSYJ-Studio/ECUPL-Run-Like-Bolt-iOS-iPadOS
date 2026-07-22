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
}
