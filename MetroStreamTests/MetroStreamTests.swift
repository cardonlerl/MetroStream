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

    func testStationsOnLineAreReturnedInLineOrder() throws {
        let repository = MetroRepository()

        let stations = repository.stations(onLineID: "line2")

        XCTAssertEqual(stations.map(\.name), [
            "娄山关路",
            "中山公园",
            "静安寺",
            "南京西路",
            "人民广场",
            "南京东路",
            "陆家嘴",
            "世纪大道",
            "龙阳路"
        ])
    }

    func testLinesContainingStationsPreserveRepositoryOrder() throws {
        let repository = MetroRepository()
        let peopleSquare = try XCTUnwrap(repository.station(named: "人民广场"))
        let jingAnTemple = try XCTUnwrap(repository.station(named: "静安寺"))

        let lines = repository.lines(containingAnyStationIDs: Set([peopleSquare.id, jingAnTemple.id]))

        XCTAssertEqual(lines.map(\.name), ["1号线", "2号线", "7号线", "8号线"])
    }

    func testFirstLineReturnsNilWhenStationHasNoLine() {
        let repository = MetroRepository()
        let station = MetroStation(
            id: "temporary",
            name: "临时站",
            latitude: 0,
            longitude: 0,
            lineIDs: [],
            mapPoint: MapPoint(x: 0, y: 0)
        )

        XCTAssertNil(repository.firstLine(containing: station))
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

final class AppStateTests: XCTestCase {
    func testSelectingStationsAndEnteringCabinCreatesRide() throws {
        let repository = MetroRepository()
        let store = MemoryStore(fileURL: temporaryURL())
        let appState = AppState(repository: repository, memoryStore: store)
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))

        appState.openSelection()
        appState.selectStart(start)
        appState.selectDestination(end)
        appState.enterCabin()

        XCTAssertEqual(appState.screen, .cabin)
        XCTAssertEqual(appState.currentRoute?.lineName, "2号线")
        XCTAssertEqual(appState.currentRide?.route.start.name, "人民广场")
    }

    func testPublishingAndEndingRideStoresMemory() throws {
        let repository = MetroRepository()
        let store = MemoryStore(fileURL: temporaryURL())
        let appState = AppState(repository: repository, memoryStore: store)
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))

        appState.selectStart(start)
        appState.selectDestination(end)
        appState.enterCabin()
        try appState.publish(CabinEntry(kind: .text, text: "留下这一句", routeKey: appState.currentRoute?.routeKey ?? ""))
        appState.endRide()

        XCTAssertEqual(appState.screen, .home)
        XCTAssertNil(appState.currentRide)
        XCTAssertEqual(appState.memories.count, 1)
        XCTAssertEqual(appState.memories[0].entries[0].text, "留下这一句")
    }

    func testEndingRideWithoutPublishedContentLeavesNoMemory() throws {
        let repository = MetroRepository()
        let store = MemoryStore(fileURL: temporaryURL())
        let appState = AppState(repository: repository, memoryStore: store)
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))

        appState.selectStart(start)
        appState.selectDestination(end)
        appState.enterCabin()
        appState.endRide()

        XCTAssertTrue(appState.memories.isEmpty)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}
