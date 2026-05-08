import Foundation

struct MapPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
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
