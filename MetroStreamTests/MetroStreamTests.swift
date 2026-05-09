import XCTest
import SwiftUI
import UIKit
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

    func testRepositoryProvidesNoMockCabinEntries() throws {
        let repository = MetroRepository()
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))
        let route = try XCTUnwrap(repository.route(from: start, to: end))

        let entries = repository.seedEntries(for: route, cabinIndex: 0)

        XCTAssertTrue(entries.isEmpty)
    }

    func testAllStationLineMembershipsAreDrawnByTheirLines() {
        let repository = MetroRepository()

        for station in repository.stations {
            for lineID in station.lineIDs {
                let line = repository.lines.first(where: { $0.id == lineID })
                XCTAssertNotNil(line, "\(station.name) references missing line \(lineID)")
                guard let line else { continue }
                XCTAssertTrue(line.stationIDs.contains(station.id), "\(station.name) should be included in \(line.name)")
            }
        }
    }

    func testCoreLineSequencesFollowRealCentralTransfers() throws {
        let repository = MetroRepository()

        XCTAssertEqual(
            try XCTUnwrap(repository.lines.first { $0.id == "line1" }).stationIDs,
            ["xinzhuang", "shanghai-south-railway-station", "xujiahui", "changshu-road", "south-shaanxi-road", "people-square", "hanzhong-road", "shanghai-railway-station", "hulan-road", "fujin-road"]
        )
        XCTAssertEqual(
            try XCTUnwrap(repository.lines.first { $0.id == "line12" }).stationIDs,
            ["qixin-road", "cao-bao-road", "longcao-road", "longhua", "longhua-middle-road", "dashaqiao-road", "jiashan-road", "south-shaanxi-road", "nanjing-west-road", "hanzhong-road", "qufu-road", "tiantong-road", "dalian-road", "jiangpu-park", "jufeng-road", "jinhai-road"]
        )
        XCTAssertEqual(
            try XCTUnwrap(repository.lines.first { $0.id == "line13" }).stationIDs,
            ["jinyun-road", "jinshajiang-road", "longde-road", "hanzhong-road", "natural-history-museum", "nanjing-west-road", "xintiandi", "madang-road", "changqing-road", "dongming-road", "lianxi-road", "zhangjiang-road"]
        )
    }

    func testLineFiveAndSixSequencesUseCurrentTransferSpines() throws {
        let repository = MetroRepository()

        XCTAssertEqual(
            try XCTUnwrap(repository.lines.first { $0.id == "line5" }).stationIDs,
            ["xinzhuang", "chunshen-road", "yindu-road", "zhuanqiao", "beiqiao", "jianchuan-road", "dongchuan-road", "jiangchuan-road", "xidu", "xiaotang", "fengpu-avenue", "east-huancheng-road", "wangyuan-road", "jinhai-lake", "fengxian-xincheng"]
        )
        XCTAssertEqual(
            try XCTUnwrap(repository.lines.first { $0.id == "line6" }).stationIDs,
            ["gangcheng-road", "jufeng-road", "jinqiao-road", "minsheng-road", "century-avenue", "lancun-road", "dongming-road", "lingyan-south-road", "oriental-sports-center"]
        )
    }

    func testRepositoryContainsAllCurrentShanghaiMetroLines() {
        let repository = MetroRepository()
        let expectedLineIDs = (1...18).map { "line\($0)" } + ["pujiang", "airport-link", "maglev"]

        XCTAssertEqual(repository.lines.map(\.id), expectedLineIDs)
        XCTAssertEqual(repository.lines.map(\.name).suffix(3), ["浦江线", "市域机场线", "磁浮线"])
    }

    func testStationsOnLineAreReturnedInLineOrder() {
        let repository = MetroRepository()

        let stations = repository.stations(onLineID: "line2")

        XCTAssertEqual(
            stations.map(\.name),
            [
                "国家会展中心",
                "虹桥2号航站楼",
                "娄山关路",
                "中山公园",
                "静安寺",
                "南京西路",
                "人民广场",
                "南京东路",
                "陆家嘴",
                "世纪大道",
                "龙阳路",
                "张江高科",
                "浦东1号2号航站楼"
            ]
        )
    }

    func testLinesContainingStationsPreserveRepositoryOrder() throws {
        let repository = MetroRepository()
        let peopleSquare = try XCTUnwrap(repository.station(named: "人民广场"))
        let jingAnTemple = try XCTUnwrap(repository.station(named: "静安寺"))

        let lines = repository.lines(containingAnyStationIDs: Set([peopleSquare.id, jingAnTemple.id]))

        XCTAssertEqual(lines.map(\.name), ["1号线", "2号线", "7号线", "8号线", "14号线"])
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
}

final class StationSelectionCatalogTests: XCTestCase {
    func testStationOptionsFollowSelectedLine() {
        let repository = MetroRepository()
        let catalog = StationSelectorCatalog(repository: repository)

        let stationNames = catalog.stations(forLineID: "line10").map(\.name)

        XCTAssertTrue(stationNames.contains("新天地"))
        XCTAssertFalse(stationNames.contains("上海南站"))
    }

    func testGlobalSearchFindsStationsAcrossAllLines() {
        let repository = MetroRepository()
        let catalog = StationSelectorCatalog(repository: repository)

        let stationNames = catalog.searchStations(matching: "上海南").map(\.name)

        XCTAssertEqual(stationNames, ["上海南站"])
    }
}

final class DrawingPadMetricsTests: XCTestCase {
    func testCanvasHeightGivesEnoughRoomForTouchDrawing() {
        XCTAssertGreaterThanOrEqual(DrawingPadMetrics.canvasHeight, 240)
        XCTAssertLessThanOrEqual(DrawingPadMetrics.canvasHeight, 280)
    }
}

final class MetroMapLayoutTests: XCTestCase {
    func testOverpassRequestPostsEncodedGeoJSONQueryToInterpreter() throws {
        let bounds = GeoBounds(south: 31.18, west: 121.40, north: 31.25, east: 121.56)
        let client = OverpassMapClient(endpoint: URL(string: "https://overpass-api.de/api/interpreter")!)

        let request = try client.makeRequest(bounds: bounds)
        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        let decodedBody = try XCTUnwrap(body.removingPercentEncoding)

        XCTAssertEqual(request.url?.absoluteString, "https://overpass-api.de/api/interpreter")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(decodedBody.contains("[out:json]"))
        XCTAssertTrue(decodedBody.contains("out geom;"))
        XCTAssertTrue(decodedBody.contains("relation[\"type\"=\"route\"][\"route\"~\"subway|monorail|light_rail\"][\"network\"~\"上海地铁|Shanghai Metro\"](31.18,121.4,31.25,121.56);"))
        XCTAssertTrue(decodedBody.contains("relation[\"type\"=\"route\"][\"name\"~\"市域机场线|磁浮线\"](31.18,121.4,31.25,121.56);"))
    }

    func testOverpassGeoJSONParserClassifiesContextSubwayAndStationFeatures() throws {
        let data = Data(
            """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "properties": { "highway": "primary" },
                  "geometry": { "type": "LineString", "coordinates": [[121.45,31.22],[121.46,31.23]] }
                },
                {
                  "type": "Feature",
                  "properties": { "railway": "subway" },
                  "geometry": { "type": "LineString", "coordinates": [[121.47,31.22],[121.48,31.23]] }
                },
                {
                  "type": "Feature",
                  "properties": { "railway": "station", "station": "subway" },
                  "geometry": { "type": "Point", "coordinates": [121.49,31.24] }
                }
              ]
            }
            """.utf8
        )

        let map = try OverpassMapParser.parse(data: data, bounds: GeoBounds(south: 31.18, west: 121.40, north: 31.25, east: 121.56))

        XCTAssertEqual(map.features.map(\.kind), [.context, .subway, .station])
        XCTAssertEqual(map.features[0].coordinates.first?.count, 2)
        XCTAssertEqual(map.features[2].coordinates.first?.first, GeoCoordinate(latitude: 31.24, longitude: 121.49))
    }

    func testOverpassRelationMembersKeepRealMetroLineGeometry() throws {
        let data = Data(
            """
            {
              "elements": [
                {
                  "type": "relation",
                  "id": 1001,
                  "tags": { "type": "route", "route": "subway", "ref": "1", "name": "上海地铁1号线" },
                  "members": [
                    {
                      "type": "way",
                      "ref": 2001,
                      "role": "",
                      "geometry": [
                        { "lat": 31.20, "lon": 121.40 },
                        { "lat": 31.24, "lon": 121.47 }
                      ]
                    }
                  ]
                }
              ]
            }
            """.utf8
        )

        let map = try OverpassMapParser.parse(data: data, bounds: GeoBounds(south: 31.18, west: 121.40, north: 31.25, east: 121.56))

        XCTAssertEqual(map.features.first?.kind, .subway)
        XCTAssertEqual(map.features.first?.lineID, "line1")
        XCTAssertEqual(map.features.first?.coordinates.first?.first, GeoCoordinate(latitude: 31.20, longitude: 121.40))
    }

    func testOverpassParserKeepsPujiangLightRailAsMetroGeometry() throws {
        let data = Data(
            """
            {
              "elements": [
                {
                  "type": "relation",
                  "id": 8167020,
                  "tags": { "type": "route", "route": "light_rail", "ref": "浦江", "name": "浦江线：汇臻路 -> 沈杜公路" },
                  "members": [
                    {
                      "type": "way",
                      "ref": 3001,
                      "role": "",
                      "geometry": [
                        { "lat": 31.03, "lon": 121.51 },
                        { "lat": 31.06, "lon": 121.53 }
                      ]
                    }
                  ]
                }
              ]
            }
            """.utf8
        )

        let map = try OverpassMapParser.parse(data: data, bounds: GeoBounds(south: 31.02, west: 121.50, north: 31.07, east: 121.54))

        XCTAssertEqual(map.features.first?.kind, .subway)
        XCTAssertEqual(map.features.first?.lineID, "pujiang")
        XCTAssertEqual(map.features.first?.coordinates.first?.last, GeoCoordinate(latitude: 31.06, longitude: 121.53))
    }

    func testFilteringKeepsSelectedLineBrightAndDimsOtherLines() throws {
        let repository = MetroRepository()
        let layout = MetroMapLayout(repository: repository)
        let line1 = try XCTUnwrap(repository.lines.first { $0.id == "line1" })
        let line2 = try XCTUnwrap(repository.lines.first { $0.id == "line2" })

        XCTAssertEqual(layout.lineAppearance(for: line1, selectedLineID: nil).opacity, 1)
        XCTAssertEqual(layout.lineAppearance(for: line2, selectedLineID: "line1").opacity, MetroLineAppearance.dimmed.opacity)
        XCTAssertEqual(layout.lineAppearance(for: line2, selectedLineID: "line1").maskOpacity, 0)
        XCTAssertEqual(layout.lineAppearance(for: line1, selectedLineID: "line1").opacity, 1)
        XCTAssertEqual(layout.lineAppearance(for: line1, selectedLineID: "line1").maskOpacity, 0)
    }

    func testSchematicMapProjectionPreservesDesignedAspectRatio() {
        let repository = MetroRepository()
        let layout = MetroMapLayout(repository: repository)
        let size = CGSize(width: 400, height: 200)

        let topLeft = layout.screenPoint(MapPoint(x: 0, y: 0), in: size)
        let bottomRight = layout.screenPoint(MapPoint(x: 318, y: 270), in: size)
        let projectedAspect = (bottomRight.x - topLeft.x) / (bottomRight.y - topLeft.y)

        XCTAssertEqual(projectedAspect, 318.0 / 270.0, accuracy: 0.001)
        XCTAssertGreaterThan(topLeft.x, 4)
        XCTAssertLessThan(bottomRight.x, size.width - 4)
    }

    func testSelectedLineIsDrawnLast() throws {
        let repository = MetroRepository()
        let layout = MetroMapLayout(repository: repository)

        let orderedLines = layout.linesForDrawing(selectedLineID: "line1")

        XCTAssertEqual(orderedLines.last?.id, "line1")
        XCTAssertEqual(orderedLines.dropLast().map(\.id), repository.lines.filter { $0.id != "line1" }.map(\.id))
    }

    func testOverpassFeaturesPutSelectedLineLast() {
        let repository = MetroRepository()
        let layout = MetroMapLayout(repository: repository)
        let features = [
            OverpassMapFeature(id: "line-1", kind: .subway, coordinates: [[GeoCoordinate(latitude: 31.20, longitude: 121.45)]], lineID: "line1"),
            OverpassMapFeature(id: "line-2", kind: .subway, coordinates: [[GeoCoordinate(latitude: 31.21, longitude: 121.46)]], lineID: "line2"),
            OverpassMapFeature(id: "context", kind: .context, coordinates: [[GeoCoordinate(latitude: 31.22, longitude: 121.47)]])
        ]

        let orderedFeatures = layout.featuresForDrawing(features, selectedLineID: "line1")

        XCTAssertEqual(orderedFeatures.map(\.id), ["line-2", "context", "line-1"])
    }

    func testMapLayerPlanKeepsSelectedOverpassLineAboveSchematicLines() {
        let repository = MetroRepository()
        let layout = MetroMapLayout(repository: repository)

        let layers = layout.lineLayers(
            realLineIDs: Set(["line1", "line2"]),
            usesGeoFallback: false,
            selectedLineID: "line1"
        )

        XCTAssertEqual(layers.last, MetroMapLineLayer(source: .overpass, lineIDs: ["line1"]))
        XCTAssertTrue(layers.dropLast().allSatisfy { !$0.lineIDs.contains("line1") })
    }

    func testMapFocusZoomsAndCentersSelectedLine() throws {
        let repository = MetroRepository()
        let layout = MetroMapLayout(repository: repository)
        let size = CGSize(width: 320, height: 420)
        let baseMap = OverpassMap.empty(bounds: GeoBounds(stations: repository.stations))
        let lineRect = try XCTUnwrap(layout.selectedLineScreenRect(selectedLineID: "line1", baseMap: baseMap, usesGeoFallback: true, in: size))

        let focus = layout.focus(for: "line1", baseMap: baseMap, usesGeoFallback: true, in: size)
        let centeredPoint = focus.transform(lineRect.center, in: size)

        XCTAssertGreaterThan(focus.scale, 1)
        XCTAssertEqual(centeredPoint.x, size.width / 2, accuracy: 0.001)
        XCTAssertEqual(centeredPoint.y, size.height / 2, accuracy: 0.001)
    }

    func testMemoryAnnotationFramesDoNotOverlapOnSelectedLine() throws {
        let repository = MetroRepository()
        let layout = MetroMapLayout(repository: repository)
        let size = CGSize(width: 320, height: 420)
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let end = try XCTUnwrap(repository.station(named: "静安寺"))
        let route = try XCTUnwrap(repository.route(from: start, to: end))
        let memories = (0..<4).map { index in
            UserMemory(
                route: route,
                startedAt: Date(timeIntervalSince1970: Double(index)),
                entries: [
                    CabinEntry(kind: .text, text: "第\(index)条", routeKey: route.routeKey)
                ]
            )
        }

        let frames = layout.memoryAnnotationFrames(
            for: memories,
            selectedLineID: "line2",
            baseMap: .empty(bounds: GeoBounds(stations: repository.stations)),
            usesGeoFallback: true,
            in: size
        )

        XCTAssertEqual(frames.count, memories.count)
        for firstIndex in frames.indices {
            for secondIndex in frames.indices where firstIndex < secondIndex {
                XCTAssertFalse(
                    frames[firstIndex].intersects(frames[secondIndex]),
                    "frames \(firstIndex) and \(secondIndex) should not overlap"
                )
            }
        }
    }

    func testLinePolylinesKeepStationAnchorsAndUseSchematicBends() throws {
        let repository = MetroRepository()
        let layout = MetroMapLayout(repository: repository)

        for line in repository.lines {
            let points = layout.polyline(for: line)
            let firstStation = try XCTUnwrap(repository.station(id: try XCTUnwrap(line.stationIDs.first)))
            let lastStation = try XCTUnwrap(repository.station(id: try XCTUnwrap(line.stationIDs.last)))

            XCTAssertEqual(points.first, firstStation.mapPoint)
            XCTAssertEqual(points.last, lastStation.mapPoint)

            for stationID in line.stationIDs {
                let station = try XCTUnwrap(repository.station(id: stationID))
                XCTAssertTrue(points.contains(station.mapPoint), "\(line.name) should pass through \(station.name)")
            }
        }

        let line7 = try XCTUnwrap(repository.lines.first { $0.id == "line7" })
        XCTAssertGreaterThan(layout.polyline(for: line7).count, line7.stationIDs.count)
    }

    func testInterchangeStationsUseLargerMapNodes() throws {
        let repository = MetroRepository()
        let peopleSquare = try XCTUnwrap(repository.station(named: "人民广场"))
        let loushanguanRoad = try XCTUnwrap(repository.station(named: "娄山关路"))

        XCTAssertEqual(MetroMapLayout.nodeKind(for: peopleSquare), .interchange)
        XCTAssertEqual(MetroMapLayout.nodeKind(for: loushanguanRoad), .regular)
        XCTAssertGreaterThan(
            MetroMapLayout.nodeKind(for: peopleSquare).diameter,
            MetroMapLayout.nodeKind(for: loushanguanRoad).diameter
        )
    }

    func testMapStationCoordinatesUseBroadReadableArea() {
        let repository = MetroRepository()
        let xs = repository.stations.map(\.mapPoint.x)
        let ys = repository.stations.map(\.mapPoint.y)

        XCTAssertGreaterThanOrEqual((xs.max() ?? 0) - (xs.min() ?? 0), 280)
        XCTAssertGreaterThanOrEqual((ys.max() ?? 0) - (ys.min() ?? 0), 205)
    }
}

final class HomeViewTests: XCTestCase {
    @MainActor
    func testMetroMapViewAcceptsBaseMapForCanvasRendering() {
        let view = MetroMapView(repository: MetroRepository())
        let storedPropertyNames = Mirror(reflecting: view).children.compactMap(\.label)

        XCTAssertTrue(storedPropertyNames.contains("baseMap"))
    }

    @MainActor
    func testMetroMapViewAcceptsLineMemoriesForMapAnnotations() {
        let view = MetroMapView(repository: MetroRepository())
        let storedPropertyNames = Mirror(reflecting: view).children.compactMap(\.label)

        XCTAssertTrue(storedPropertyNames.contains("lineMemories"))
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}

final class StationSelectionViewTests: XCTestCase {
    func testHomeTabStartsWithDepartureThenHistory() {
        XCTAssertEqual(HomeTab.allCases, [.departure, .history])
    }

    @MainActor
    func testHomeViewKeepsNativeTabSelectionState() {
        let appState = AppState(memoryStore: MemoryStore(fileURL: temporaryURL()))
        let view = HomeView(appState: appState, locationService: LocationService())
        let storedPropertyNames = Mirror(reflecting: view).children.compactMap(\.label)

        XCTAssertTrue(storedPropertyNames.contains("_selectedHomeTab"))
    }

    @MainActor
    func testHistoryTabKeepsMapStateOnHomeView() {
        let appState = AppState(memoryStore: MemoryStore(fileURL: temporaryURL()))
        let view = HomeView(appState: appState, locationService: LocationService())
        let storedPropertyNames = Mirror(reflecting: view).children.compactMap(\.label)

        XCTAssertTrue(storedPropertyNames.contains("_baseMap"))
        XCTAssertTrue(storedPropertyNames.contains("_selectedLineID"))
    }

    func testLineWheelKeepsCarouselScrollStyling() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("MetroStream/Views/Home/HomeView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("LineWheelPicker"))
        XCTAssertTrue(source.contains(".scrollTransition"))
        XCTAssertTrue(source.contains(".scrollTargetBehavior(.viewAligned)"))
        XCTAssertTrue(source.contains("let sidePadding ="))
        XCTAssertTrue(source.contains(".frame(width: itemWidth)"))
        XCTAssertFalse(source.contains(".containerRelativeFrame(.horizontal"))
    }

    func testLineWheelUsesLightweightSelectionStyle() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("MetroStream/Views/Home/HomeView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains(".background(isSelected ? color"))
        XCTAssertFalse(source.contains(".shadow(color: isSelected ?"))
        XCTAssertFalse(source.contains("LineWheelBackdrop"))
    }

    func testLineWheelScrollPositionDrivesSelectedLine() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("MetroStream/Views/Home/HomeView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(".onChange(of: scrollPosition)"))
        XCTAssertTrue(source.contains("selectedLineID = newValue"))
    }

    func testHistoryTabDefaultsToLineOne() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("MetroStream/Views/Home/HomeView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("@State private var selectedLineID: String? = \"line1\""))
    }

    func testHistoryMapFillsTabAndShowsSelectedLineMemoriesWithoutEdgeFade() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("MetroStream/Views/Home/HomeView.swift"),
            encoding: .utf8
        )
        let mapSource = try String(
            contentsOf: projectRoot.appendingPathComponent("MetroStream/Views/Shared/MetroMapView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("MapEdgeFade"))
        XCTAssertFalse(source.contains(".aspectRatio(318.0 / 270.0"))
        XCTAssertTrue(source.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        XCTAssertTrue(source.contains(".ignoresSafeArea()"))
        XCTAssertTrue(source.contains("lineMemories: selectedLineMemories"))
        XCTAssertTrue(mapSource.contains(".blur(radius: selectedLineID == nil ? 0 :"))
    }

    func testHomeTabSelectedTintAvoidsInkBlack() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("MetroStream/Views/Home/HomeView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains(".tint(SardineColors.ink)"))
    }

    @MainActor
    func testStationSelectionViewDoesNotOwnBottomTabSelection() {
        let appState = AppState(memoryStore: MemoryStore(fileURL: temporaryURL()))
        let view = StationSelectionView(appState: appState, locationService: LocationService())
        let storedPropertyNames = Mirror(reflecting: view).children.compactMap(\.label)

        XCTAssertFalse(storedPropertyNames.contains("_selectedTab"))
    }

    func testStationSelectionUsesHalfSheetLineStationSelector() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("MetroStream/Views/StationSelection/StationSelectionView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("StationSelectorSheet"))
        XCTAssertTrue(source.contains(".sheet(item: $activeSelector)"))
        XCTAssertTrue(source.contains("TextField(\"搜索站点\""))
        XCTAssertTrue(source.contains("searchStations(matching: query)"))
        XCTAssertFalse(source.contains("TextField(\"站名\""))
        XCTAssertFalse(source.contains("private var stationList"))
    }

    func testDepartureTicketButtonMovesAboveHomeTabBar() {
        let normalOrigin = DepartureTicketLayout.actionButtonOrigin(reservesBottomTabSpace: false)
        let tabOrigin = DepartureTicketLayout.actionButtonOrigin(reservesBottomTabSpace: true)

        XCTAssertEqual(normalOrigin.y, 738)
        XCTAssertLessThan(tabOrigin.y + DepartureTicketLayout.actionButtonSize.height, normalOrigin.y)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
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
    func testDepartureTicketRouteEntersCabinWithTicketStations() throws {
        let repository = MetroRepository()
        let store = MemoryStore(fileURL: temporaryURL())
        let appState = AppState(repository: repository, memoryStore: store)

        XCTAssertTrue(DepartureTicketRoute.featured.apply(to: appState))

        XCTAssertEqual(appState.screen, .cabin)
        XCTAssertEqual(appState.currentRoute?.start.name, "新天地")
        XCTAssertEqual(appState.currentRoute?.end.name, "上海南站")
        XCTAssertNotNil(appState.currentRide)
    }

    func testDepartureTicketRouteUsesChosenStationsBeforeDefaults() throws {
        let repository = MetroRepository()
        let store = MemoryStore(fileURL: temporaryURL())
        let appState = AppState(repository: repository, memoryStore: store)
        let start = try XCTUnwrap(repository.station(named: "人民广场"))
        let destination = try XCTUnwrap(repository.station(named: "静安寺"))

        appState.selectStart(start)
        appState.selectDestination(destination)
        XCTAssertTrue(DepartureTicketRoute.featured.apply(to: appState))

        XCTAssertEqual(appState.currentRoute?.start.name, "人民广场")
        XCTAssertEqual(appState.currentRoute?.end.name, "静安寺")
    }

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

final class CabinSceneMetricsTests: XCTestCase {
    func testCabinSceneUsesOnlyBackgroundImageWithoutOverlayPeopleOrBubbles() {
        XCTAssertEqual(CabinSceneMetrics.passengerCount, 0)
        XCTAssertEqual(CabinSceneMetrics.visibleBubbleCount(forEntryCount: 0), 0)
        XCTAssertEqual(CabinSceneMetrics.visibleBubbleCount(forEntryCount: 6), 0)
    }

    func testCabinBackgroundUsesCenteredNinetyPercentCropAndSmallMotionOffset() {
        XCTAssertEqual(CabinSceneMetrics.backgroundVisibleFraction, 0.95, accuracy: 0.001)
        XCTAssertEqual(CabinSceneMetrics.backgroundScale, 1 / 0.95, accuracy: 0.001)
        XCTAssertEqual(CabinSceneMetrics.sceneCornerRadius, 0)
        XCTAssertEqual(CabinSceneMetrics.sceneHorizontalPadding, 0)

        let frameSize = CGSize(width: 402, height: 874)
        let imageAspectRatio = CGFloat(922.0 / 1412.0)
        let travelLimit = CabinSceneMetrics.motionOffsetLimit(
            in: frameSize,
            imageAspectRatio: imageAspectRatio
        )
        let verticalTravel = frameSize.height * (CabinSceneMetrics.backgroundScale - 1) / 2

        XCTAssertEqual(travelLimit.height, verticalTravel, accuracy: 0.001)
        XCTAssertGreaterThan(travelLimit.width, travelLimit.height * 3)

        let maxOffset = CabinSceneMetrics.motionOffset(
            forRoll: 1,
            pitch: -1,
            frameSize: frameSize,
            imageAspectRatio: imageAspectRatio
        )
        XCTAssertEqual(maxOffset.width, travelLimit.width, accuracy: 0.001)
        XCTAssertEqual(maxOffset.height, travelLimit.height, accuracy: 0.001)

        let clampedOffset = CabinSceneMetrics.motionOffset(
            forRoll: -2,
            pitch: 2,
            frameSize: frameSize,
            imageAspectRatio: imageAspectRatio
        )
        XCTAssertEqual(clampedOffset.width, -travelLimit.width, accuracy: 0.001)
        XCTAssertEqual(clampedOffset.height, -travelLimit.height, accuracy: 0.001)
    }

    func testCabinBackgroundResourceLoadsFromBundlePNG() {
        XCTAssertNotNil(CabinBackgroundResource.image(in: .main))
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
