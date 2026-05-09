import Foundation

struct MapPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
}

struct GeoCoordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
}

struct GeoBounds: Codable, Equatable, Hashable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double

    static let shanghaiCore = GeoBounds(south: 31.16, west: 121.38, north: 31.26, east: 121.58)

    init(south: Double, west: Double, north: Double, east: Double) {
        self.south = south
        self.west = west
        self.north = north
        self.east = east
    }

    init(stations: [MetroStation], paddingRatio: Double = 0.06) {
        guard
            let minLatitude = stations.map(\.latitude).min(),
            let maxLatitude = stations.map(\.latitude).max(),
            let minLongitude = stations.map(\.longitude).min(),
            let maxLongitude = stations.map(\.longitude).max()
        else {
            self = .shanghaiCore
            return
        }

        let latitudePadding = max(0.01, (maxLatitude - minLatitude) * paddingRatio)
        let longitudePadding = max(0.01, (maxLongitude - minLongitude) * paddingRatio)
        self.init(
            south: minLatitude - latitudePadding,
            west: minLongitude - longitudePadding,
            north: maxLatitude + latitudePadding,
            east: maxLongitude + longitudePadding
        )
    }
}

enum OverpassMapFeatureKind: String, Codable, Equatable {
    case context
    case subway
    case station
}

struct OverpassMapFeature: Identifiable, Codable, Equatable {
    let id: String
    let kind: OverpassMapFeatureKind
    let coordinates: [[GeoCoordinate]]
    let lineID: String?

    init(id: String, kind: OverpassMapFeatureKind, coordinates: [[GeoCoordinate]], lineID: String? = nil) {
        self.id = id
        self.kind = kind
        self.coordinates = coordinates
        self.lineID = lineID
    }
}

struct OverpassMap: Codable, Equatable {
    let bounds: GeoBounds
    let features: [OverpassMapFeature]

    static func empty(bounds: GeoBounds = .shanghaiCore) -> OverpassMap {
        OverpassMap(bounds: bounds, features: [])
    }
}

struct OverpassMapClient {
    let endpoint: URL

    static let live = OverpassMapClient(endpoint: URL(string: "https://overpass-api.de/api/interpreter")!)

    func makeRequest(bounds: GeoBounds) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(encoded(query(for: bounds)))".data(using: .utf8)
        return request
    }

    func fetch(bounds: GeoBounds) async throws -> OverpassMap {
        let request = try makeRequest(bounds: bounds)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try OverpassMapParser.parse(data: data, bounds: bounds)
    }

    private func query(for bounds: GeoBounds) -> String {
        let bbox = "\(bounds.south),\(bounds.west),\(bounds.north),\(bounds.east)"
        return """
        [out:json][timeout:18];
        (
          relation["type"="route"]["route"~"subway|monorail|light_rail"]["network"~"上海地铁|Shanghai Metro"](\(bbox));
          relation["type"="route"]["name"~"市域机场线|磁浮线"](\(bbox));
          node["railway"="station"]["station"="subway"](\(bbox));
          node["station"="subway"](\(bbox));
        );
        out geom;
        """
    }

    private func encoded(_ query: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
    }
}

enum OverpassMapParser {
    static func parse(data: Data, bounds: GeoBounds) throws -> OverpassMap {
        let decoder = JSONDecoder()
        if let collection = try? decoder.decode(GeoJSONFeatureCollection.self, from: data) {
            return OverpassMap(bounds: bounds, features: collection.features.enumerated().compactMap { index, feature in
                feature.mapFeature(id: "geojson-\(index)")
            })
        }

        let response = try decoder.decode(OverpassDerivedResponse.self, from: data)
        return OverpassMap(bounds: bounds, features: response.elements.enumerated().compactMap { index, element in
            element.mapFeature(id: "overpass-\(element.id ?? Int64(index))")
        })
    }
}

private struct GeoJSONFeatureCollection: Decodable {
    let features: [GeoJSONFeature]
}

private struct GeoJSONFeature: Decodable {
    let properties: [String: String]
    let geometry: GeoJSONGeometry

    private enum CodingKeys: String, CodingKey {
        case properties
        case geometry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        properties = (try? container.decode([String: String].self, forKey: .properties)) ?? [:]
        geometry = try container.decode(GeoJSONGeometry.self, forKey: .geometry)
    }

    func mapFeature(id: String) -> OverpassMapFeature? {
        let coordinates = geometry.coordinateLines
        guard !coordinates.isEmpty else { return nil }
        return OverpassMapFeature(id: id, kind: properties.featureKind, coordinates: coordinates, lineID: properties.metroLineID)
    }
}

private struct OverpassDerivedResponse: Decodable {
    let elements: [OverpassDerivedElement]
}

private struct OverpassDerivedElement: Decodable {
    let id: Int64?
    let tags: [String: String]
    let geometry: OverpassGeometry?
    let members: [OverpassRelationMember]

    private enum CodingKeys: String, CodingKey {
        case id
        case tags
        case geometry
        case members
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(Int64.self, forKey: .id)
        tags = (try? container.decode([String: String].self, forKey: .tags)) ?? [:]
        geometry = try? container.decode(OverpassGeometry.self, forKey: .geometry)
        members = (try? container.decode([OverpassRelationMember].self, forKey: .members)) ?? []
    }

    func mapFeature(id: String) -> OverpassMapFeature? {
        let coordinates = (geometry?.coordinateLines ?? []) + members.flatMap(\.coordinateLines)
        guard !coordinates.isEmpty else { return nil }
        return OverpassMapFeature(id: id, kind: tags.featureKind, coordinates: coordinates, lineID: tags.metroLineID)
    }
}

private struct OverpassRelationMember: Decodable {
    let coordinateLines: [[GeoCoordinate]]

    private enum CodingKeys: String, CodingKey {
        case geometry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let points = (try? container.decode([OverpassGeometryPoint].self, forKey: .geometry)) ?? []
        coordinateLines = points.count > 1 ? [points.map { GeoCoordinate(latitude: $0.lat, longitude: $0.lon) }] : []
    }
}

private struct GeoJSONGeometry: Decodable {
    let coordinateLines: [[GeoCoordinate]]

    private enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "Point":
            let coordinate = try container.decode([Double].self, forKey: .coordinates)
            coordinateLines = [Self.coordinateLine(from: coordinate).map { [$0] } ?? []].filter { !$0.isEmpty }
        case "LineString":
            let coordinates = try container.decode([[Double]].self, forKey: .coordinates)
            coordinateLines = [coordinates.compactMap(Self.coordinateLine(from:))]
        case "MultiLineString", "Polygon":
            let coordinates = try container.decode([[[Double]]].self, forKey: .coordinates)
            coordinateLines = coordinates.map { $0.compactMap(Self.coordinateLine(from:)) }
        default:
            coordinateLines = []
        }
    }

    private static func coordinateLine(from values: [Double]) -> GeoCoordinate? {
        guard values.count >= 2 else { return nil }
        return GeoCoordinate(latitude: values[1], longitude: values[0])
    }
}

private struct OverpassGeometry: Decodable {
    let coordinateLines: [[GeoCoordinate]]

    init(from decoder: Decoder) throws {
        if let geoJSON = try? GeoJSONGeometry(from: decoder) {
            coordinateLines = geoJSON.coordinateLines
            return
        }

        let points = try [OverpassGeometryPoint](from: decoder)
        coordinateLines = [points.map { GeoCoordinate(latitude: $0.lat, longitude: $0.lon) }]
    }
}

private struct OverpassGeometryPoint: Decodable {
    let lat: Double
    let lon: Double
}

private extension Dictionary where Key == String, Value == String {
    var featureKind: OverpassMapFeatureKind {
        if self["station"] == "subway" || self["railway"] == "station" || self["public_transport"] == "station" {
            return .station
        }

        if self["railway"] == "subway"
            || self["railway"] == "light_rail"
            || self["railway"] == "monorail"
            || self["route"] == "subway"
            || self["route"] == "light_rail"
            || self["route"] == "monorail"
            || self["subway"] != nil
        {
            return .subway
        }

        return .context
    }

    var metroLineID: String? {
        guard featureKind == .subway else { return nil }

        let combined = [self["ref"], self["name"], self["name:zh"], self["line"], self["colour"]]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if combined.contains("浦江") || combined.contains("pujiang") || combined.contains(" pj") || combined == "pj" {
            return "pujiang"
        }

        if combined.contains("机场") || combined.contains("airport") || combined.contains(" al") || combined == "al" {
            return "airport-link"
        }

        if combined.contains("磁浮") || combined.contains("maglev") || combined.contains(" maglev") || combined == "m" {
            return "maglev"
        }

        for number in (1...18).reversed() {
            if combined.contains("\(number)号线")
                || combined.contains("line \(number)")
                || combined.contains("line\(number)")
                || combined.split(whereSeparator: { !$0.isNumber }).contains(String(number)[...])
            {
                return "line\(number)"
            }
        }

        return nil
    }
}

struct MetroStation: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let lineIDs: [String]
    let mapPoint: MapPoint
}

struct MetroLine: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    let stationIDs: [String]
}

struct LocatedStation: Equatable {
    let station: MetroStation
    let distanceMeters: Double
}

struct RoutePlan: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let start: MetroStation
    let end: MetroStation
    let lineID: String
    let lineName: String
    let estimatedMinutes: Int

    init(
        id: UUID = UUID(),
        start: MetroStation,
        end: MetroStation,
        lineID: String,
        lineName: String,
        estimatedMinutes: Int
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.lineID = lineID
        self.lineName = lineName
        self.estimatedMinutes = estimatedMinutes
    }

    var routeKey: String {
        "\(start.id)-\(end.id)"
    }
}

enum CabinEntryKind: String, Codable, CaseIterable {
    case text
    case drawing
    case music
}

struct DrawingStroke: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var points: [MapPoint]
    var width: Double
    var isEraser: Bool

    init(id: UUID = UUID(), points: [MapPoint], width: Double = 3, isEraser: Bool = false) {
        self.id = id
        self.points = points
        self.width = width
        self.isEraser = isEraser
    }
}

struct CabinEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var kind: CabinEntryKind
    var text: String
    var songTitle: String?
    var drawing: [DrawingStroke]
    var routeKey: String
    var isMine: Bool

    init(
        id: UUID = UUID(),
        kind: CabinEntryKind,
        text: String,
        songTitle: String? = nil,
        drawing: [DrawingStroke] = [],
        routeKey: String,
        isMine: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.songTitle = songTitle
        self.drawing = drawing
        self.routeKey = routeKey
        self.isMine = isMine
    }
}

enum PublishError: Error, Equatable {
    case limitReached
    case empty
}

struct RideSession: Identifiable, Codable, Equatable {
    let id: UUID
    var route: RoutePlan
    var startedAt: Date
    var publishedEntries: [CabinEntry]

    init(
        id: UUID = UUID(),
        route: RoutePlan,
        startedAt: Date = Date(),
        publishedEntries: [CabinEntry] = []
    ) {
        self.id = id
        self.route = route
        self.startedAt = startedAt
        self.publishedEntries = publishedEntries
    }

    mutating func publish(_ entry: CabinEntry) throws {
        guard publishedEntries.count < 3 else {
            throw PublishError.limitReached
        }
        guard !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !entry.drawing.isEmpty else {
            throw PublishError.empty
        }
        var mine = entry
        mine.isMine = true
        publishedEntries.append(mine)
    }
}

struct UserMemory: Identifiable, Codable, Equatable {
    let id: UUID
    var route: RoutePlan
    var startedAt: Date
    var entries: [CabinEntry]

    init(id: UUID = UUID(), route: RoutePlan, startedAt: Date, entries: [CabinEntry]) {
        self.id = id
        self.route = route
        self.startedAt = startedAt
        self.entries = entries
    }
}
