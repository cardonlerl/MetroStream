import Foundation

struct MetroRepository {
    let lines: [MetroLine]
    let stations: [MetroStation]

    init() {
        let seed = MetroSeed.make()
        self.lines = seed.lines
        self.stations = seed.stations
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

    func seedEntries(for _: RoutePlan, cabinIndex _: Int) -> [CabinEntry] {
        []
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
    }

    static func make() -> Seed {
        let lines = [
            MetroLine(id: "line1", name: "1号线", colorHex: "#E4002B", stationIDs: ["xinzhuang", "shanghai-south-railway-station", "xujiahui", "changshu-road", "south-shaanxi-road", "people-square", "hanzhong-road", "shanghai-railway-station", "hulan-road", "fujin-road"]),
            MetroLine(id: "line2", name: "2号线", colorHex: "#8CC63E", stationIDs: ["national-exhibition-and-convention-center", "hongqiao-t2", "loushanguan-road", "zhongshan-park", "jing-an-temple", "nanjing-west-road", "people-square", "east-nanjing-road", "lujiazui", "century-avenue", "longyang-road", "zhangjiang-high-tech-park", "pudong-t1t2"]),
            MetroLine(id: "line3", name: "3号线", colorHex: "#FFD100", stationIDs: ["shanghai-south-railway-station", "yishan-road", "hongqiao-road", "zhongshan-park", "shanghai-railway-station", "baoshan-road", "baoyang-road", "jiangyang-north-road"]),
            MetroLine(id: "line4", name: "4号线", colorHex: "#5F259F", stationIDs: ["yishan-road", "hongqiao-road", "zhongshan-park", "shanghai-railway-station", "baoshan-road", "hailun-road", "dalian-road", "century-avenue", "lancun-road", "xizang-south-road", "shanghai-stadium", "yishan-road"]),
            MetroLine(id: "line5", name: "5号线", colorHex: "#AC4FC6", stationIDs: ["xinzhuang", "chunshen-road", "yindu-road", "zhuanqiao", "beiqiao", "jianchuan-road", "dongchuan-road", "jiangchuan-road", "xidu", "xiaotang", "fengpu-avenue", "east-huancheng-road", "wangyuan-road", "jinhai-lake", "fengxian-xincheng"]),
            MetroLine(id: "line6", name: "6号线", colorHex: "#D4145A", stationIDs: ["gangcheng-road", "jufeng-road", "jinqiao-road", "minsheng-road", "century-avenue", "lancun-road", "dongming-road", "lingyan-south-road", "oriental-sports-center"]),
            MetroLine(id: "line7", name: "7号线", colorHex: "#FFC533", stationIDs: ["meilan-lake", "shanghai-university", "jing-an-temple", "changshu-road", "zhaojiabang-road", "longhua-middle-road", "longyang-road", "huamu-road"]),
            MetroLine(id: "line8", name: "8号线", colorHex: "#00A7E1", stationIDs: ["shiguang-road", "hongkou-football-stadium", "people-square", "laoximen", "xizang-south-road", "oriental-sports-center", "shendu-highway"]),
            MetroLine(id: "line9", name: "9号线", colorHex: "#82C7E8", stationIDs: ["shanghai-songjiang-railway-station", "qibao", "yishan-road", "xujiahui", "zhaojiabang-road", "madang-road", "century-avenue", "jinqiao", "caolu"]),
            MetroLine(id: "line10", name: "10号线", colorHex: "#7660A8", stationIDs: ["hongqiao-railway-station", "hongqiao-t2", "hongqiao-road", "south-shaanxi-road", "xintiandi", "laoximen", "yuyuan-garden", "east-nanjing-road", "hailun-road", "jiangwan-stadium"]),
            MetroLine(id: "line11", name: "11号线", colorHex: "#8B1E41", stationIDs: ["huaqiao", "jiading-north", "zhenru", "jiangsu-road", "xujiahui", "longhua", "disney-resort"]),
            MetroLine(id: "line12", name: "12号线", colorHex: "#007A3D", stationIDs: ["qixin-road", "cao-bao-road", "longcao-road", "longhua", "longhua-middle-road", "dashaqiao-road", "jiashan-road", "south-shaanxi-road", "nanjing-west-road", "hanzhong-road", "qufu-road", "tiantong-road", "dalian-road", "jiangpu-park", "jufeng-road", "jinhai-road"]),
            MetroLine(id: "line13", name: "13号线", colorHex: "#F3A3C7", stationIDs: ["jinyun-road", "jinshajiang-road", "longde-road", "hanzhong-road", "natural-history-museum", "nanjing-west-road", "xintiandi", "madang-road", "changqing-road", "dongming-road", "lianxi-road", "zhangjiang-road"]),
            MetroLine(id: "line14", name: "14号线", colorHex: "#C9A227", stationIDs: ["fengbang", "zhenru", "jing-an-temple", "huangpi-south-road", "yuyuan-garden", "lujiazui", "pudong-avenue", "jinqiao", "guiqiao-road"]),
            MetroLine(id: "line15", name: "15号线", colorHex: "#B690C8", stationIDs: ["gucun-park", "shanghai-west-railway-station", "wuzhong-road", "guilin-road", "shanghai-south-railway-station", "zhumei-road", "zizhu-hi-tech-park"]),
            MetroLine(id: "line16", name: "16号线", colorHex: "#7CC242", stationIDs: ["longyang-road", "luoshan-road", "huinan", "dishui-lake"]),
            MetroLine(id: "line17", name: "17号线", colorHex: "#B88967", stationIDs: ["hongqiao-railway-station", "national-exhibition-and-convention-center", "zhujiajiao", "oriental-land"]),
            MetroLine(id: "line18", name: "18号线", colorHex: "#C7A46B", stationIDs: ["kangwen-road", "changjiang-south-road", "fudan-university", "jiangpu-park", "minsheng-road", "century-avenue", "longyang-road", "yuqiao", "hangtou"]),
            MetroLine(id: "pujiang", name: "浦江线", colorHex: "#B4B4B4", stationIDs: ["shendu-highway", "sanlu-highway", "huizhen-road"]),
            MetroLine(id: "airport-link", name: "市域机场线", colorHex: "#55C8D3", stationIDs: ["hongqiao-t2", "zhongchun-road", "jinghong-road", "south-sanlin", "east-kangqiao", "shanghai-international-resort", "pudong-t1t2"]),
            MetroLine(id: "maglev", name: "磁浮线", colorHex: "#A0A0A0", stationIDs: ["longyang-road", "pudong-t1t2"])
        ]

        let lineIDsByStation = Dictionary(grouping: lines.flatMap { line in
            line.stationIDs.map { (stationID: $0, lineID: line.id) }
        }, by: \.stationID).mapValues { pairs in
            pairs.reduce(into: [String]()) { result, pair in
                if !result.contains(pair.lineID) {
                    result.append(pair.lineID)
                }
            }
        }

        let stations = stationSeeds.map { seed in
            station(seed.id, seed.name, seed.latitude, seed.longitude, lineIDsByStation[seed.id] ?? [], seed.x, seed.y)
        }

        return Seed(lines: lines, stations: stations)
    }

    private struct StationSeed {
        let id: String
        let name: String
        let latitude: Double
        let longitude: Double
        let x: Double
        let y: Double
    }

    private static let stationSeeds: [StationSeed] = [
        StationSeed(id: "xinzhuang", name: "莘庄", latitude: 31.1110, longitude: 121.3853, x: 118, y: 215),
        StationSeed(id: "shanghai-south-railway-station", name: "上海南站", latitude: 31.1547, longitude: 121.4300, x: 142, y: 198),
        StationSeed(id: "xujiahui", name: "徐家汇", latitude: 31.1939, longitude: 121.4368, x: 150, y: 180),
        StationSeed(id: "changshu-road", name: "常熟路", latitude: 31.2145, longitude: 121.4490, x: 150, y: 158),
        StationSeed(id: "south-shaanxi-road", name: "陕西南路", latitude: 31.2149, longitude: 121.4584, x: 160, y: 145),
        StationSeed(id: "people-square", name: "人民广场", latitude: 31.2304, longitude: 121.4737, x: 176, y: 118),
        StationSeed(id: "hanzhong-road", name: "汉中路", latitude: 31.2400, longitude: 121.4580, x: 162, y: 94),
        StationSeed(id: "shanghai-railway-station", name: "上海火车站", latitude: 31.2495, longitude: 121.4559, x: 158, y: 76),
        StationSeed(id: "hulan-road", name: "呼兰路", latitude: 31.3393, longitude: 121.4375, x: 148, y: 36),
        StationSeed(id: "fujin-road", name: "富锦路", latitude: 31.3924, longitude: 121.4247, x: 142, y: 12),
        StationSeed(id: "national-exhibition-and-convention-center", name: "国家会展中心", latitude: 31.1906, longitude: 121.3020, x: 72, y: 135),
        StationSeed(id: "hongqiao-t2", name: "虹桥2号航站楼", latitude: 31.1979, longitude: 121.3260, x: 90, y: 145),
        StationSeed(id: "loushanguan-road", name: "娄山关路", latitude: 31.2118, longitude: 121.4041, x: 124, y: 128),
        StationSeed(id: "zhongshan-park", name: "中山公园", latitude: 31.2244, longitude: 121.4244, x: 136, y: 118),
        StationSeed(id: "jing-an-temple", name: "静安寺", latitude: 31.2230, longitude: 121.4453, x: 154, y: 118),
        StationSeed(id: "nanjing-west-road", name: "南京西路", latitude: 31.2296, longitude: 121.4598, x: 166, y: 118),
        StationSeed(id: "east-nanjing-road", name: "南京东路", latitude: 31.2380, longitude: 121.4846, x: 190, y: 118),
        StationSeed(id: "lujiazui", name: "陆家嘴", latitude: 31.2397, longitude: 121.4998, x: 210, y: 116),
        StationSeed(id: "century-avenue", name: "世纪大道", latitude: 31.2288, longitude: 121.5260, x: 235, y: 128),
        StationSeed(id: "longyang-road", name: "龙阳路", latitude: 31.2035, longitude: 121.5578, x: 260, y: 164),
        StationSeed(id: "zhangjiang-high-tech-park", name: "张江高科", latitude: 31.2036, longitude: 121.5940, x: 282, y: 166),
        StationSeed(id: "pudong-t1t2", name: "浦东1号2号航站楼", latitude: 31.1500, longitude: 121.8060, x: 314, y: 198),
        StationSeed(id: "yishan-road", name: "宜山路", latitude: 31.1830, longitude: 121.4330, x: 140, y: 188),
        StationSeed(id: "hongqiao-road", name: "虹桥路", latitude: 31.2028, longitude: 121.4203, x: 130, y: 166),
        StationSeed(id: "baoshan-road", name: "宝山路", latitude: 31.2500, longitude: 121.4766, x: 176, y: 78),
        StationSeed(id: "baoyang-road", name: "宝杨路", latitude: 31.3825, longitude: 121.4792, x: 176, y: 22),
        StationSeed(id: "jiangyang-north-road", name: "江杨北路", latitude: 31.4077, longitude: 121.4460, x: 160, y: 8),
        StationSeed(id: "hailun-road", name: "海伦路", latitude: 31.2596, longitude: 121.4884, x: 190, y: 82),
        StationSeed(id: "dalian-road", name: "大连路", latitude: 31.2584, longitude: 121.5196, x: 220, y: 92),
        StationSeed(id: "lancun-road", name: "蓝村路", latitude: 31.2117, longitude: 121.5271, x: 236, y: 154),
        StationSeed(id: "xizang-south-road", name: "西藏南路", latitude: 31.2019, longitude: 121.4896, x: 200, y: 160),
        StationSeed(id: "shanghai-stadium", name: "上海体育场", latitude: 31.1837, longitude: 121.4437, x: 152, y: 190),
        StationSeed(id: "chunshen-road", name: "春申路", latitude: 31.0985, longitude: 121.3851, x: 116, y: 224),
        StationSeed(id: "yindu-road", name: "银都路", latitude: 31.0891, longitude: 121.3921, x: 118, y: 230),
        StationSeed(id: "zhuanqiao", name: "颛桥", latitude: 31.0671, longitude: 121.4016, x: 122, y: 236),
        StationSeed(id: "beiqiao", name: "北桥", latitude: 31.0454, longitude: 121.4103, x: 126, y: 242),
        StationSeed(id: "jianchuan-road", name: "剑川路", latitude: 31.0263, longitude: 121.4168, x: 130, y: 246),
        StationSeed(id: "dongchuan-road", name: "东川路", latitude: 31.0264, longitude: 121.4196, x: 132, y: 248),
        StationSeed(id: "jiangchuan-road", name: "江川路", latitude: 31.0063, longitude: 121.4246, x: 136, y: 254),
        StationSeed(id: "xidu", name: "西渡", latitude: 30.9894, longitude: 121.4324, x: 144, y: 258),
        StationSeed(id: "xiaotang", name: "萧塘", latitude: 30.9657, longitude: 121.4484, x: 152, y: 260),
        StationSeed(id: "fengpu-avenue", name: "奉浦大道", latitude: 30.9430, longitude: 121.4620, x: 158, y: 262),
        StationSeed(id: "east-huancheng-road", name: "环城东路", latitude: 30.9292, longitude: 121.4785, x: 164, y: 264),
        StationSeed(id: "wangyuan-road", name: "望园路", latitude: 30.9208, longitude: 121.4910, x: 170, y: 266),
        StationSeed(id: "jinhai-lake", name: "金海湖", latitude: 30.9158, longitude: 121.5031, x: 176, y: 268),
        StationSeed(id: "fengxian-xincheng", name: "奉贤新城", latitude: 30.9184, longitude: 121.4962, x: 182, y: 270),
        StationSeed(id: "gangcheng-road", name: "港城路", latitude: 31.3528, longitude: 121.5749, x: 245, y: 32),
        StationSeed(id: "jufeng-road", name: "巨峰路", latitude: 31.2802, longitude: 121.5880, x: 255, y: 72),
        StationSeed(id: "jinqiao-road", name: "金桥路", latitude: 31.2520, longitude: 121.5898, x: 256, y: 94),
        StationSeed(id: "lingyan-south-road", name: "灵岩南路", latitude: 31.1437, longitude: 121.5007, x: 212, y: 214),
        StationSeed(id: "oriental-sports-center", name: "东方体育中心", latitude: 31.1591, longitude: 121.4800, x: 198, y: 208),
        StationSeed(id: "meilan-lake", name: "美兰湖", latitude: 31.4075, longitude: 121.3565, x: 116, y: 10),
        StationSeed(id: "shanghai-university", name: "上海大学", latitude: 31.3206, longitude: 121.3937, x: 130, y: 48),
        StationSeed(id: "zhaojiabang-road", name: "肇嘉浜路", latitude: 31.1992, longitude: 121.4502, x: 160, y: 176),
        StationSeed(id: "longhua-middle-road", name: "龙华中路", latitude: 31.1842, longitude: 121.4592, x: 174, y: 190),
        StationSeed(id: "huamu-road", name: "花木路", latitude: 31.2097, longitude: 121.5682, x: 268, y: 158),
        StationSeed(id: "shiguang-road", name: "市光路", latitude: 31.3223, longitude: 121.5386, x: 218, y: 48),
        StationSeed(id: "hongkou-football-stadium", name: "虹口足球场", latitude: 31.2724, longitude: 121.4792, x: 184, y: 74),
        StationSeed(id: "laoximen", name: "老西门", latitude: 31.2180, longitude: 121.4890, x: 196, y: 144),
        StationSeed(id: "shendu-highway", name: "沈杜公路", latitude: 31.0670, longitude: 121.5123, x: 212, y: 238),
        StationSeed(id: "shanghai-songjiang-railway-station", name: "上海松江站", latitude: 31.0175, longitude: 121.2276, x: 38, y: 236),
        StationSeed(id: "qibao", name: "七宝", latitude: 31.1614, longitude: 121.3497, x: 98, y: 188),
        StationSeed(id: "madang-road", name: "马当路", latitude: 31.2096, longitude: 121.4774, x: 184, y: 154),
        StationSeed(id: "jinqiao", name: "金桥", latitude: 31.2538, longitude: 121.6133, x: 268, y: 100),
        StationSeed(id: "caolu", name: "曹路", latitude: 31.2702, longitude: 121.6830, x: 300, y: 82),
        StationSeed(id: "hongqiao-railway-station", name: "虹桥火车站", latitude: 31.1944, longitude: 121.3189, x: 82, y: 145),
        StationSeed(id: "xintiandi", name: "新天地", latitude: 31.2193, longitude: 121.4752, x: 184, y: 146),
        StationSeed(id: "yuyuan-garden", name: "豫园", latitude: 31.2270, longitude: 121.4939, x: 200, y: 132),
        StationSeed(id: "jiangwan-stadium", name: "江湾体育场", latitude: 31.3045, longitude: 121.5140, x: 206, y: 52),
        StationSeed(id: "huaqiao", name: "花桥", latitude: 31.2991, longitude: 121.1044, x: 8, y: 118),
        StationSeed(id: "jiading-north", name: "嘉定北", latitude: 31.3914, longitude: 121.2376, x: 54, y: 50),
        StationSeed(id: "zhenru", name: "真如", latitude: 31.2491, longitude: 121.4074, x: 126, y: 98),
        StationSeed(id: "jiangsu-road", name: "江苏路", latitude: 31.2204, longitude: 121.4306, x: 142, y: 126),
        StationSeed(id: "longhua", name: "龙华", latitude: 31.1726, longitude: 121.4528, x: 166, y: 198),
        StationSeed(id: "disney-resort", name: "迪士尼", latitude: 31.1440, longitude: 121.6676, x: 296, y: 206),
        StationSeed(id: "qixin-road", name: "七莘路", latitude: 31.1363, longitude: 121.3564, x: 104, y: 204),
        StationSeed(id: "cao-bao-road", name: "漕宝路", latitude: 31.1746, longitude: 121.4336, x: 134, y: 202),
        StationSeed(id: "longcao-road", name: "龙漕路", latitude: 31.1708, longitude: 121.4433, x: 154, y: 204),
        StationSeed(id: "dashaqiao-road", name: "大木桥路", latitude: 31.1999, longitude: 121.4630, x: 176, y: 178),
        StationSeed(id: "jiashan-road", name: "嘉善路", latitude: 31.2059, longitude: 121.4591, x: 168, y: 166),
        StationSeed(id: "qufu-road", name: "曲阜路", latitude: 31.2423, longitude: 121.4712, x: 176, y: 92),
        StationSeed(id: "tiantong-road", name: "天潼路", latitude: 31.2434, longitude: 121.4820, x: 188, y: 92),
        StationSeed(id: "jiangpu-park", name: "江浦公园", latitude: 31.2634, longitude: 121.5227, x: 222, y: 82),
        StationSeed(id: "jinhai-road", name: "金海路", latitude: 31.2636, longitude: 121.6387, x: 284, y: 86),
        StationSeed(id: "jinyun-road", name: "金运路", latitude: 31.2411, longitude: 121.3260, x: 88, y: 92),
        StationSeed(id: "jinshajiang-road", name: "金沙江路", latitude: 31.2370, longitude: 121.4130, x: 132, y: 100),
        StationSeed(id: "longde-road", name: "隆德路", latitude: 31.2337, longitude: 121.4247, x: 140, y: 102),
        StationSeed(id: "natural-history-museum", name: "自然博物馆", latitude: 31.2366, longitude: 121.4622, x: 166, y: 104),
        StationSeed(id: "changqing-road", name: "长清路", latitude: 31.1756, longitude: 121.4881, x: 202, y: 194),
        StationSeed(id: "dongming-road", name: "东明路", latitude: 31.1682, longitude: 121.5109, x: 222, y: 204),
        StationSeed(id: "lianxi-road", name: "莲溪路", latitude: 31.1683, longitude: 121.5654, x: 252, y: 202),
        StationSeed(id: "zhangjiang-road", name: "张江路", latitude: 31.1776, longitude: 121.6298, x: 286, y: 198),
        StationSeed(id: "fengbang", name: "封浜", latitude: 31.2482, longitude: 121.3207, x: 76, y: 104),
        StationSeed(id: "huangpi-south-road", name: "黄陂南路", latitude: 31.2245, longitude: 121.4745, x: 178, y: 138),
        StationSeed(id: "pudong-avenue", name: "浦东大道", latitude: 31.2448, longitude: 121.5235, x: 228, y: 106),
        StationSeed(id: "guiqiao-road", name: "桂桥路", latitude: 31.2593, longitude: 121.6447, x: 286, y: 96),
        StationSeed(id: "gucun-park", name: "顾村公园", latitude: 31.3441, longitude: 121.3799, x: 122, y: 30),
        StationSeed(id: "shanghai-west-railway-station", name: "上海西站", latitude: 31.2572, longitude: 121.4001, x: 124, y: 90),
        StationSeed(id: "wuzhong-road", name: "吴中路", latitude: 31.1861, longitude: 121.4083, x: 122, y: 176),
        StationSeed(id: "guilin-road", name: "桂林路", latitude: 31.1745, longitude: 121.4181, x: 132, y: 190),
        StationSeed(id: "zhumei-road", name: "朱梅路", latitude: 31.1159, longitude: 121.4332, x: 146, y: 228),
        StationSeed(id: "zizhu-hi-tech-park", name: "紫竹高新区", latitude: 31.0268, longitude: 121.4605, x: 154, y: 260),
        StationSeed(id: "luoshan-road", name: "罗山路", latitude: 31.1546, longitude: 121.5931, x: 276, y: 206),
        StationSeed(id: "huinan", name: "惠南", latitude: 31.0536, longitude: 121.7611, x: 306, y: 238),
        StationSeed(id: "dishui-lake", name: "滴水湖", latitude: 30.9069, longitude: 121.9296, x: 318, y: 270),
        StationSeed(id: "zhujiajiao", name: "朱家角", latitude: 31.1053, longitude: 121.0487, x: 20, y: 208),
        StationSeed(id: "oriental-land", name: "东方绿舟", latitude: 31.1017, longitude: 121.0150, x: 4, y: 210),
        StationSeed(id: "kangwen-road", name: "康文路", latitude: 31.3660, longitude: 121.5050, x: 198, y: 22),
        StationSeed(id: "changjiang-south-road", name: "长江南路", latitude: 31.3328, longitude: 121.4911, x: 196, y: 42),
        StationSeed(id: "fudan-university", name: "复旦大学", latitude: 31.3002, longitude: 121.5038, x: 202, y: 58),
        StationSeed(id: "minsheng-road", name: "民生路", latitude: 31.2347, longitude: 121.5435, x: 246, y: 118),
        StationSeed(id: "yuqiao", name: "御桥", latitude: 31.1550, longitude: 121.5709, x: 264, y: 218),
        StationSeed(id: "hangtou", name: "航头", latitude: 31.0299, longitude: 121.6030, x: 282, y: 254),
        StationSeed(id: "sanlu-highway", name: "三鲁公路", latitude: 31.0615, longitude: 121.5342, x: 222, y: 244),
        StationSeed(id: "huizhen-road", name: "汇臻路", latitude: 31.0446, longitude: 121.5433, x: 228, y: 252),
        StationSeed(id: "zhongchun-road", name: "中春路", latitude: 31.1579, longitude: 121.3370, x: 95, y: 195),
        StationSeed(id: "jinghong-road", name: "景洪路", latitude: 31.1105, longitude: 121.4500, x: 150, y: 226),
        StationSeed(id: "south-sanlin", name: "三林南", latitude: 31.1273, longitude: 121.5186, x: 220, y: 226),
        StationSeed(id: "east-kangqiao", name: "康桥东", latitude: 31.1320, longitude: 121.6170, x: 268, y: 224),
        StationSeed(id: "shanghai-international-resort", name: "上海国际旅游度假区", latitude: 31.1450, longitude: 121.6820, x: 296, y: 214)
    ]

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
}
