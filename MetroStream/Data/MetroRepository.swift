import Foundation

struct MetroRepository {
    let lines: [MetroLine]
    let stations: [MetroStation]
    private let seededEntries: [CabinEntry]

    init() {
        let seed = MetroSeed.make()
        self.lines = seed.lines
        self.stations = seed.stations
        self.seededEntries = seed.entries
    }

    func station(named name: String) -> MetroStation? {
        stations.first { $0.name == name }
    }

    func station(id: String) -> MetroStation? {
        stations.first { $0.id == id }
    }

    func stations(onLineID lineID: String) -> [MetroStation] {
        guard let line = line(id: lineID) else { return [] }
        return line.stationIDs.compactMap(station(id:))
    }

    func lines(containingAnyStationIDs stationIDs: Set<String>) -> [MetroLine] {
        lines.filter { line in
            line.stationIDs.contains { stationIDs.contains($0) }
        }
    }

    func firstLine(containing station: MetroStation) -> MetroLine? {
        station.lineIDs.compactMap(line(id:)).first
    }

    func nearbyStations(latitude: Double, longitude: Double, radiusMeters: Double) -> [LocatedStation] {
        stations
            .map { station in
                LocatedStation(
                    station: station,
                    distanceMeters: distanceMeters(
                        fromLatitude: latitude,
                        longitude: longitude,
                        toLatitude: station.latitude,
                        longitude: station.longitude
                    )
                )
            }
            .filter { $0.distanceMeters <= radiusMeters }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    func route(from start: MetroStation, to end: MetroStation) -> RoutePlan? {
        let sharedLineIDs = start.lineIDs.filter { end.lineIDs.contains($0) }
        guard let line = sharedLineIDs.compactMap(line(id:)).first else {
            return transferRoute(from: start, to: end)
        }
        return plan(on: line, from: start, to: end)
    }

    func seedEntries(for route: RoutePlan, cabinIndex: Int) -> [CabinEntry] {
        let matches = seededEntries.filter { $0.routeKey == route.routeKey || $0.routeKey == "any" }
        guard !matches.isEmpty else { return [] }
        let offset = max(0, cabinIndex) % matches.count
        return Array((matches[offset...] + matches[..<offset]).prefix(6))
    }

    private func line(id: String) -> MetroLine? {
        lines.first { $0.id == id }
    }

    private func plan(on line: MetroLine, from start: MetroStation, to end: MetroStation) -> RoutePlan? {
        guard
            let startIndex = line.stationIDs.firstIndex(of: start.id),
            let endIndex = line.stationIDs.firstIndex(of: end.id)
        else { return nil }

        let stationHops = abs(line.stationIDs.distance(from: startIndex, to: endIndex))
        return RoutePlan(
            start: start,
            end: end,
            lineID: line.id,
            lineName: line.name,
            estimatedMinutes: max(4, stationHops * 4 + 1)
        )
    }

    private func transferRoute(from start: MetroStation, to end: MetroStation) -> RoutePlan? {
        guard
            let lineID = start.lineIDs.first,
            let line = line(id: lineID)
        else { return nil }

        let geographicMinutes = Int(max(8, distanceMeters(
            fromLatitude: start.latitude,
            longitude: start.longitude,
            toLatitude: end.latitude,
            longitude: end.longitude
        ) / 420))

        return RoutePlan(
            start: start,
            end: end,
            lineID: line.id,
            lineName: line.name,
            estimatedMinutes: geographicMinutes
        )
    }

    private func distanceMeters(
        fromLatitude startLatitude: Double,
        longitude startLongitude: Double,
        toLatitude endLatitude: Double,
        longitude endLongitude: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let startLat = startLatitude * .pi / 180
        let endLat = endLatitude * .pi / 180
        let deltaLat = (endLatitude - startLatitude) * .pi / 180
        let deltaLon = (endLongitude - startLongitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(startLat) * cos(endLat) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

private enum MetroSeed {
    struct Seed {
        let lines: [MetroLine]
        let stations: [MetroStation]
        let entries: [CabinEntry]
    }

    static func make() -> Seed {
        let stations: [MetroStation] = [
            station("xujiahui", "徐家汇", 31.1939, 121.4368, ["line1", "line9"], 44, 150),
            station("south-shaanxi-road", "陕西南路", 31.2149, 121.4584, ["line1", "line10"], 70, 128),
            station("people-square", "人民广场", 31.2304, 121.4737, ["line1", "line2", "line8"], 92, 108),
            station("hanzhong-road", "汉中路", 31.2400, 121.4580, ["line1", "line12"], 76, 84),
            station("zhongshan-park", "中山公园", 31.2244, 121.4244, ["line2"], 36, 104),
            station("jing-an-temple", "静安寺", 31.2230, 121.4453, ["line2", "line7"], 58, 106),
            station("nanjing-west-road", "南京西路", 31.2296, 121.4598, ["line2", "line12", "line13"], 76, 106),
            station("east-nanjing-road", "南京东路", 31.2380, 121.4846, ["line2", "line10"], 110, 105),
            station("loushanguan-road", "娄山关路", 31.2118, 121.4041, ["line2"], 18, 112),
            station("changshu-road", "常熟路", 31.2145, 121.4490, ["line7"], 62, 137),
            station("zhaojiabang-road", "肇嘉浜路", 31.1992, 121.4502, ["line7", "line9"], 64, 160),
            station("longyang-road", "龙阳路", 31.2035, 121.5578, ["line2", "line7"], 148, 128),
            station("yishan-road", "宜山路", 31.1830, 121.4330, ["line9"], 42, 170),
            station("xintiandi", "新天地", 31.2193, 121.4752, ["line10", "line13"], 94, 132),
            station("yuyuan-garden", "豫园", 31.2270, 121.4939, ["line10"], 120, 125),
            station("laoximen", "老西门", 31.2180, 121.4890, ["line8", "line10"], 112, 142),
            station("lujiazui", "陆家嘴", 31.2397, 121.4998, ["line2"], 130, 100),
            station("century-avenue", "世纪大道", 31.2288, 121.5260, ["line2", "line9"], 148, 108)
        ]

        let lines = [
            MetroLine(id: "line1", name: "1号线", colorHex: "#C84F43", stationIDs: ["xujiahui", "south-shaanxi-road", "people-square", "hanzhong-road"]),
            MetroLine(id: "line2", name: "2号线", colorHex: "#79A868", stationIDs: ["loushanguan-road", "zhongshan-park", "jing-an-temple", "nanjing-west-road", "people-square", "east-nanjing-road", "lujiazui", "century-avenue", "longyang-road"]),
            MetroLine(id: "line7", name: "7号线", colorHex: "#D2A24A", stationIDs: ["jing-an-temple", "changshu-road", "zhaojiabang-road", "longyang-road"]),
            MetroLine(id: "line9", name: "9号线", colorHex: "#79A9C9", stationIDs: ["xujiahui", "zhaojiabang-road", "century-avenue"]),
            MetroLine(id: "line10", name: "10号线", colorHex: "#8F7DBA", stationIDs: ["south-shaanxi-road", "xintiandi", "laoximen", "yuyuan-garden", "east-nanjing-road"]),
            MetroLine(id: "line8", name: "8号线", colorHex: "#6AA99A", stationIDs: ["people-square", "laoximen"])
        ]

        let anyEntries = [
            text("any", "车门上有一小块夕阳。"),
            text("any", "一个红色帆布包在膝盖上睡着了。"),
            music("any", "慢慢", "不急着回家。"),
            text("any", "有人把伞抱得像一束花。"),
            text("any", "玻璃里的人比车厢里的人安静。"),
            music("any", "地铁等待", "今天的心跳慢一点。")
        ]
        let routeEntries = [
            text("people-square-jing-an-temple", "人民广场上车后，所有人都像刚从梦里出来。"),
            text("people-square-jing-an-temple", "静安寺前一站，车厢忽然松了一点。")
        ]

        return Seed(lines: lines, stations: stations, entries: routeEntries + anyEntries)
    }

    private static func station(
        _ id: String,
        _ name: String,
        _ latitude: Double,
        _ longitude: Double,
        _ lineIDs: [String],
        _ x: Double,
        _ y: Double
    ) -> MetroStation {
        MetroStation(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            lineIDs: lineIDs,
            mapPoint: MapPoint(x: x, y: y)
        )
    }

    private static func text(_ routeKey: String, _ text: String) -> CabinEntry {
        CabinEntry(kind: .text, text: text, routeKey: routeKey)
    }

    private static func music(_ routeKey: String, _ song: String, _ mood: String) -> CabinEntry {
        CabinEntry(kind: .music, text: mood, songTitle: song, routeKey: routeKey)
    }
}
