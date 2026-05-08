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

final class RideSessionTests: XCTestCase {
    func testRideAllowsThreeEntriesAndRejectsFourth() throws {
        let repository = MetroRepository()
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))
        let route = try XCTUnwrap(repository.route(from: start, to: end))
        var ride = RideSession(route: route, startedAt: Date(timeIntervalSince1970: 10))

        try ride.publish(Self.entry("one", route: route))
        try ride.publish(Self.entry("two", route: route))
        try ride.publish(Self.entry("three", route: route))

        XCTAssertThrowsError(try ride.publish(Self.entry("four", route: route))) { error in
            XCTAssertEqual(error as? PublishError, .limitReached)
        }
        XCTAssertEqual(ride.publishedEntries.count, 3)
    }

    func testMemoryStorePersistsOnlyRidesWithPublishedEntries() throws {
        let repository = MetroRepository()
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))
        let route = try XCTUnwrap(repository.route(from: start, to: end))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        let store = MemoryStore(fileURL: url)
        var ride = RideSession(route: route, startedAt: Date(timeIntervalSince1970: 20))

        store.save(ride: ride)
        XCTAssertTrue(store.load().isEmpty)

        try ride.publish(Self.entry("kept", route: route))
        store.save(ride: ride)

        let memories = store.load()
        XCTAssertEqual(memories.count, 1)
        XCTAssertEqual(memories[0].entries.count, 1)
        XCTAssertEqual(memories[0].entries[0].text, "kept")
        XCTAssertTrue(memories[0].entries.allSatisfy(\.isMine))
    }

    private static func entry(_ text: String, route: RoutePlan) -> CabinEntry {
        CabinEntry(kind: .text, text: text, routeKey: route.routeKey, isMine: true)
    }
}
