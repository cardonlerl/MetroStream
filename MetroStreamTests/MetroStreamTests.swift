import XCTest
@testable import MetroStream

final class MetroRepositoryTests: XCTestCase {
    func testRepositoryContainsCoreLinesAndStations() {
        let repository = MetroRepository()

        XCTAssertGreaterThanOrEqual(repository.lines.count, 5)
        XCTAssertNotNil(repository.station(named: "人民广场"))
        XCTAssertNotNil(repository.station(named: "静安寺"))
        XCTAssertNotNil(repository.station(named: "徐家汇"))
    }

    func testNearbyStationsOnlyIncludesStationsWithinTwoKilometers() throws {
        let repository = MetroRepository()
        let peopleSquare = try XCTUnwrap(repository.station(named: "人民广场"))

        let nearby = repository.nearbyStations(
            latitude: peopleSquare.latitude,
            longitude: peopleSquare.longitude,
            radiusMeters: 2_000
        )

        XCTAssertTrue(nearby.contains { $0.station.name == "人民广场" })
        XCTAssertFalse(nearby.contains { $0.station.name == "静安寺" && $0.distanceMeters > 2_000 })
        XCTAssertTrue(nearby.allSatisfy { $0.distanceMeters <= 2_000 })
    }

    func testRouteEstimateUsesSharedLineWhenPossible() throws {
        let repository = MetroRepository()
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))

        let route = try XCTUnwrap(repository.route(from: start, to: end))

        XCTAssertEqual(route.lineName, "2号线")
        XCTAssertEqual(route.start.name, "人民广场")
        XCTAssertEqual(route.end.name, "静安寺")
        XCTAssertGreaterThanOrEqual(route.estimatedMinutes, 4)
    }

    func testSeedCabinEntriesAreRouteBoundAndLimited() throws {
        let repository = MetroRepository()
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))
        let route = try XCTUnwrap(repository.route(from: start, to: end))

        let entries = repository.seedEntries(for: route, cabinIndex: 0)

        XCTAssertFalse(entries.isEmpty)
        XCTAssertLessThanOrEqual(entries.count, 6)
        XCTAssertTrue(entries.allSatisfy { !$0.isMine })
    }
}
