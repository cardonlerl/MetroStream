import SwiftUI

struct MetroMapView: View {
    let repository: MetroRepository
    var backgroundColor: Color = SardineColors.paper
    var baseMap: OverpassMap = .empty()
    var highlightedRoutes: [RoutePlan] = []
    var lineMemories: [UserMemory] = []
    var selectedStationID: String?
    var selectedLineID: String?
    var onStationTap: ((MetroStation) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = MetroMapLayout(repository: repository)
            let realLineIDs = Set(baseMap.features.compactMap(\.lineID))
            let usesGeoFallback = realLineIDs.isEmpty && onStationTap == nil && highlightedRoutes.isEmpty
            let focus = layout.focus(for: selectedLineID, baseMap: baseMap, usesGeoFallback: usesGeoFallback, in: size)
            let lineLayers = layout.lineLayers(realLineIDs: realLineIDs, usesGeoFallback: usesGeoFallback, selectedLineID: selectedLineID)
            let selectedLayer = lineLayers.last(where: { layer in
                selectedLineID.map { layer.lineIDs.contains($0) } ?? false
            })
            let backgroundLayers = lineLayers.filter { layer in
                guard let selectedLayer else { return true }
                return layer != selectedLayer
            }
            ZStack {
                backgroundColor

                ZStack {
                    ZStack {
                        OverpassBaseMapCanvas(map: baseMap)
                        ForEach(Array(backgroundLayers.enumerated()), id: \.offset) { _, layer in
                            lineLayer(layer, layout: layout, size: size)
                        }

                        ForEach(highlightedRoutes) { route in
                            if let line = repository.lines.first(where: { $0.id == route.lineID }) {
                                let points = layout.polyline(for: line, from: route.start.id, to: route.end.id)
                                linePath(points, layout: layout, in: size)
                                    .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: layout.lineWidth(in: size) + 4, lineCap: .butt, lineJoin: .miter))
                                linePath(points, layout: layout, in: size)
                                    .stroke(Color(hex: line.colorHex), style: StrokeStyle(lineWidth: layout.lineWidth(in: size), lineCap: .butt, lineJoin: .miter))
                            }
                        }

                        if !usesGeoFallback && shouldShowSchematicStations(realLineIDs: realLineIDs) {
                            ForEach(repository.stations) { station in
                                let point = layout.screenPoint(station.mapPoint, in: size)
                                Button {
                                    onStationTap?(station)
                                } label: {
                                    stationNode(for: station, selectedLineID: selectedLineID)
                                        .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.plain)
                                .position(point)
                                .disabled(onStationTap == nil)
                                .accessibilityLabel(station.name)
                            }
                        }

                        if usesGeoFallback {
                            RepositoryGeoStationsCanvas(repository: repository, selectedLineID: selectedLineID)
                        }
                    }
                    .blur(radius: selectedLineID == nil ? 0 : 2.6)

                    if let selectedLayer {
                        lineLayer(selectedLayer, layout: layout, size: size)
                    }

                    if let selectedLineID, !lineMemories.isEmpty {
                        let annotationFrames = layout.memoryAnnotationFrames(
                            for: lineMemories,
                            selectedLineID: selectedLineID,
                            baseMap: baseMap,
                            usesGeoFallback: usesGeoFallback,
                            in: size
                        )

                        ForEach(Array(lineMemories.enumerated()), id: \.element.id) { index, memory in
                            MemoryRouteAnnotation(memory: memory)
                                .position(annotationFrames[index].center)
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(focus.scale)
                .offset(focus.offset)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.36), value: focus)
        }
    }

    @ViewBuilder
    private func lineLayer(_ layer: MetroMapLineLayer, layout: MetroMapLayout, size: CGSize) -> some View {
        switch layer.source {
        case .overpass:
            OverpassMetroLinesCanvas(
                map: baseMap,
                repository: repository,
                backgroundColor: backgroundColor,
                selectedLineID: selectedLineID,
                lineIDs: Set(layer.lineIDs)
            )
        case .repositoryGeo:
            RepositoryGeoMapCanvas(
                repository: repository,
                backgroundColor: backgroundColor,
                selectedLineID: selectedLineID,
                lineIDs: Set(layer.lineIDs)
            )
        case .schematic:
            ForEach(repository.lines.filter { layer.lineIDs.contains($0.id) }) { line in
                let appearance = layout.lineAppearance(for: line, selectedLineID: selectedLineID)
                let points = layout.polyline(for: line)
                linePath(points, layout: layout, in: size)
                    .stroke(
                        Color(hex: line.colorHex).opacity(appearance.opacity),
                        style: StrokeStyle(lineWidth: layout.lineWidth(in: size), lineCap: .butt, lineJoin: .miter)
                    )

                if appearance.maskOpacity > 0 {
                    linePath(points, layout: layout, in: size)
                        .stroke(
                            backgroundColor.opacity(appearance.maskOpacity),
                            style: StrokeStyle(lineWidth: layout.lineWidth(in: size) + 3, lineCap: .butt, lineJoin: .miter)
                        )
                }
            }
        }
    }

    private func linePath(_ points: [MapPoint], layout: MetroMapLayout, in size: CGSize) -> Path {
        Path { path in
            let screenPoints = points.map { layout.screenPoint($0, in: size) }
            guard let first = screenPoints.first else { return }
            path.move(to: first)

            for point in screenPoints.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func stationNode(for station: MetroStation, selectedLineID: String?) -> some View {
        let kind = MetroMapLayout.nodeKind(for: station)
        let isSelected = selectedStationID == station.id
        let diameter = CGFloat(isSelected ? max(kind.diameter, 11) : kind.diameter)
        let belongsToSelectedLine = selectedLineID.map { station.lineIDs.contains($0) } ?? true
        let nodeOpacity = isSelected ? 1 : (belongsToSelectedLine ? 0.58 : 0.2)

        return Circle()
            .fill(isSelected ? Color.black : Color.white.opacity(nodeOpacity))
            .frame(width: diameter, height: diameter)
            .overlay(
                Circle().stroke(
                    isSelected ? Color.white : Color.black.opacity(nodeOpacity),
                    lineWidth: CGFloat(kind.strokeWidth)
                )
            )
    }

    private func shouldShowSchematicStations(realLineIDs: Set<String>) -> Bool {
        realLineIDs.isEmpty || onStationTap != nil || !highlightedRoutes.isEmpty
    }

}

private struct MemoryRouteAnnotation: View {
    let memory: UserMemory

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(memory.entries.prefix(2))) { entry in
                MemoryAnnotationEntry(entry: entry)
            }
        }
        .frame(width: 96, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(SardineColors.paperRaised.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(SardineColors.hairline.opacity(0.72), lineWidth: 0.8))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MemoryAnnotationEntry: View {
    let entry: CabinEntry

    var body: some View {
        switch entry.kind {
        case .text:
            Text(entry.text)
                .font(.system(size: 10, weight: .regular, design: .serif))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        case .drawing:
            MemoryAnnotationDrawing(strokes: entry.drawing)
                .frame(height: 30)
        case .music:
            Text(musicText)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
    }

    private var musicText: String {
        guard let songTitle = entry.songTitle, !songTitle.isEmpty else {
            return entry.text
        }
        return "《\(songTitle)》"
    }
}

private struct MemoryAnnotationDrawing: View {
    let strokes: [DrawingStroke]

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                var path = Path()
                for (index, point) in stroke.points.enumerated() {
                    let cgPoint = CGPoint(x: size.width * point.x, y: size.height * point.y)
                    if index == 0 {
                        path.move(to: cgPoint)
                    } else {
                        path.addLine(to: cgPoint)
                    }
                }
                let color = stroke.isEraser ? SardineColors.paperRaised : SardineColors.ink.opacity(0.74)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: max(1.2, stroke.width * 0.58), lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct OverpassBaseMapCanvas: View {
    let map: OverpassMap

    var body: some View {
        Canvas { context, size in
            for feature in map.features where feature.lineID == nil {
                draw(feature, in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ feature: OverpassMapFeature, in context: inout GraphicsContext, size: CGSize) {
        for line in feature.coordinates {
            guard let first = line.first else { continue }
            let firstPoint = screenPoint(first, size: size)

            switch feature.kind {
            case .station:
                let rect = CGRect(x: firstPoint.x - 1.2, y: firstPoint.y - 1.2, width: 2.4, height: 2.4)
                context.fill(Path(ellipseIn: rect), with: .color(SardineColors.ink.opacity(0.025)))
            case .subway, .context:
                guard line.count > 1 else { continue }
                var path = Path()
                path.move(to: firstPoint)
                for coordinate in line.dropFirst() {
                    path.addLine(to: screenPoint(coordinate, size: size))
                }
                context.stroke(path, with: .color(color(for: feature.kind)), style: StrokeStyle(lineWidth: width(for: feature.kind), lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func color(for kind: OverpassMapFeatureKind) -> Color {
        switch kind {
        case .context:
            return SardineColors.ink.opacity(0.014)
        case .subway:
            return SardineColors.ink.opacity(0.032)
        case .station:
            return SardineColors.ink.opacity(0.025)
        }
    }

    private func width(for kind: OverpassMapFeatureKind) -> CGFloat {
        switch kind {
        case .context:
            return 0.7
        case .subway:
            return 1.1
        case .station:
            return 1
        }
    }

    private func screenPoint(_ coordinate: GeoCoordinate, size: CGSize) -> CGPoint {
        MetroGeoProjection(bounds: map.bounds, size: size).screenPoint(coordinate)
    }
}

private struct OverpassMetroLinesCanvas: View {
    let map: OverpassMap
    let repository: MetroRepository
    let backgroundColor: Color
    let selectedLineID: String?
    let lineIDs: Set<String>

    var body: some View {
        Canvas { context, size in
            for feature in orderedFeatures {
                draw(feature, in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private var orderedFeatures: [OverpassMapFeature] {
        MetroMapLayout(repository: repository)
            .featuresForDrawing(
                map.features.filter { feature in
                    feature.lineID.map { lineIDs.contains($0) } ?? false
                },
                selectedLineID: selectedLineID
            )
    }

    private func draw(_ feature: OverpassMapFeature, in context: inout GraphicsContext, size: CGSize) {
        guard
            let lineID = feature.lineID,
            let metroLine = repository.lines.first(where: { $0.id == lineID })
        else { return }

        let appearance = MetroMapLayout(repository: repository).lineAppearance(for: metroLine, selectedLineID: selectedLineID)
        for coordinateLine in feature.coordinates where coordinateLine.count > 1 {
            let path = path(for: coordinateLine, bounds: map.bounds, size: size)
            context.stroke(
                path,
                with: .color(Color(hex: metroLine.colorHex).opacity(appearance.opacity)),
                style: StrokeStyle(lineWidth: lineWidth(size: size), lineCap: .round, lineJoin: .round)
            )

            if appearance.maskOpacity > 0 {
                context.stroke(
                    path,
                    with: .color(backgroundColor.opacity(appearance.maskOpacity)),
                    style: StrokeStyle(lineWidth: lineWidth(size: size) + 3, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func path(for coordinates: [GeoCoordinate], bounds: GeoBounds, size: CGSize) -> Path {
        let projection = MetroGeoProjection(bounds: bounds, size: size)
        return Path { path in
            guard let first = coordinates.first else { return }
            path.move(to: projection.screenPoint(first))
            for coordinate in coordinates.dropFirst() {
                path.addLine(to: projection.screenPoint(coordinate))
            }
        }
    }

    private func lineWidth(size: CGSize) -> CGFloat {
        max(2.4, min(size.width, size.height) * 0.012)
    }
}

private struct RepositoryGeoMapCanvas: View {
    let repository: MetroRepository
    let backgroundColor: Color
    let selectedLineID: String?
    let lineIDs: Set<String>

    var body: some View {
        Canvas { context, size in
            let bounds = GeoBounds(stations: repository.stations)
            let projection = MetroGeoProjection(bounds: bounds, size: size)
            let layout = MetroMapLayout(repository: repository)
            for line in layout.linesForDrawing(selectedLineID: selectedLineID) where lineIDs.contains(line.id) {
                draw(line, projection: projection, in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ line: MetroLine, projection: MetroGeoProjection, in context: inout GraphicsContext, size: CGSize) {
        let coordinates = line.stationIDs.compactMap { stationID -> GeoCoordinate? in
            guard let station = repository.station(id: stationID) else { return nil }
            return GeoCoordinate(latitude: station.latitude, longitude: station.longitude)
        }
        guard coordinates.count > 1 else { return }

        let appearance = MetroMapLayout(repository: repository).lineAppearance(for: line, selectedLineID: selectedLineID)
        let path = Path { path in
            guard let first = coordinates.first else { return }
            path.move(to: projection.screenPoint(first))
            for coordinate in coordinates.dropFirst() {
                path.addLine(to: projection.screenPoint(coordinate))
            }
        }

        context.stroke(
            path,
            with: .color(Color(hex: line.colorHex).opacity(appearance.opacity)),
            style: StrokeStyle(lineWidth: max(2.8, min(size.width, size.height) * 0.013), lineCap: .round, lineJoin: .round)
        )

        if appearance.maskOpacity > 0 {
            context.stroke(
                path,
                with: .color(backgroundColor.opacity(appearance.maskOpacity)),
                style: StrokeStyle(lineWidth: max(5.2, min(size.width, size.height) * 0.02), lineCap: .round, lineJoin: .round)
            )
        }
    }

}

private struct RepositoryGeoStationsCanvas: View {
    let repository: MetroRepository
    let selectedLineID: String?

    var body: some View {
        Canvas { context, size in
            let bounds = GeoBounds(stations: repository.stations)
            let projection = MetroGeoProjection(bounds: bounds, size: size)
            drawStations(projection: projection, in: &context)
        }
        .allowsHitTesting(false)
    }

    private func drawStations(projection: MetroGeoProjection, in context: inout GraphicsContext) {
        for station in repository.stations {
            let belongsToSelectedLine = selectedLineID.map { station.lineIDs.contains($0) } ?? false
            let opacity = selectedLineID == nil ? 0.08 : (belongsToSelectedLine ? 0.16 : 0.04)
            let radius = station.lineIDs.count > 1 ? 2.2 : 1.4
            let point = projection.screenPoint(GeoCoordinate(latitude: station.latitude, longitude: station.longitude))
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(SardineColors.ink.opacity(opacity)))
        }
    }
}

private struct MetroGeoProjection {
    let bounds: GeoBounds
    let size: CGSize

    func screenPoint(_ coordinate: GeoCoordinate) -> CGPoint {
        let longitudeSpan = max(0.0001, bounds.east - bounds.west)
        let latitudeSpan = max(0.0001, bounds.north - bounds.south)
        let scale = min(size.width / longitudeSpan, size.height / latitudeSpan)
        let projectedWidth = longitudeSpan * scale
        let projectedHeight = latitudeSpan * scale
        let origin = CGPoint(
            x: (size.width - projectedWidth) / 2,
            y: (size.height - projectedHeight) / 2
        )
        return CGPoint(
            x: origin.x + (coordinate.longitude - bounds.west) * scale,
            y: origin.y + (bounds.north - coordinate.latitude) * scale
        )
    }
}

struct MetroMapFocus: Equatable {
    let scale: CGFloat
    let offset: CGSize

    static let identity = MetroMapFocus(scale: 1, offset: .zero)

    func transform(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGPoint(
            x: center.x + (point.x - center.x) * scale + offset.width,
            y: center.y + (point.y - center.y) * scale + offset.height
        )
    }
}

struct MetroLineAppearance: Equatable {
    let opacity: Double
    let maskOpacity: Double

    static let normal = MetroLineAppearance(opacity: 1, maskOpacity: 0)
    static let dimmed = MetroLineAppearance(opacity: 0.2, maskOpacity: 0)
}

enum MetroMapLineLayerSource: Equatable {
    case overpass
    case repositoryGeo
    case schematic
}

struct MetroMapLineLayer: Equatable {
    let source: MetroMapLineLayerSource
    let lineIDs: [String]
}

enum MetroMapNodeKind: Equatable {
    case regular
    case interchange

    var diameter: Double {
        switch self {
        case .regular:
            return 6
        case .interchange:
            return 11
        }
    }

    var strokeWidth: Double {
        switch self {
        case .regular:
            return 2
        case .interchange:
            return 2.4
        }
    }
}

struct MetroMapLayout {
    let repository: MetroRepository

    private static let canvasWidth = 318.0
    private static let canvasHeight = 270.0

    func polyline(for line: MetroLine) -> [MapPoint] {
        polyline(for: line, stationIDs: Array(line.stationIDs))
    }

    func polyline(for line: MetroLine, from startStationID: String, to endStationID: String) -> [MapPoint] {
        guard
            let startIndex = line.stationIDs.firstIndex(of: startStationID),
            let endIndex = line.stationIDs.firstIndex(of: endStationID)
        else { return [] }

        let bounds = startIndex <= endIndex ? startIndex...endIndex : endIndex...startIndex
        return polyline(for: line, stationIDs: Array(line.stationIDs[bounds]))
    }

    func screenPoint(_ mapPoint: MapPoint, in size: CGSize) -> CGPoint {
        let margin = max(4.0, min(size.width, size.height) * 0.024)
        let availableWidth = max(1.0, size.width - margin * 2)
        let availableHeight = max(1.0, size.height - margin * 2)
        let scale = min(availableWidth / Self.canvasWidth, availableHeight / Self.canvasHeight)
        let width = Self.canvasWidth * scale
        let height = Self.canvasHeight * scale
        let origin = CGPoint(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2
        )
        return CGPoint(
            x: origin.x + mapPoint.x * scale,
            y: origin.y + mapPoint.y * scale
        )
    }

    static func nodeKind(for station: MetroStation) -> MetroMapNodeKind {
        station.lineIDs.count > 1 ? .interchange : .regular
    }

    func lineAppearance(for line: MetroLine, selectedLineID: String?) -> MetroLineAppearance {
        guard let selectedLineID, selectedLineID != line.id else {
            return .normal
        }
        return .dimmed
    }

    func linesForDrawing(selectedLineID: String?) -> [MetroLine] {
        guard let selectedLineID else { return repository.lines }
        return repository.lines
            .filter { $0.id != selectedLineID } +
            repository.lines.filter { $0.id == selectedLineID }
    }

    func featuresForDrawing(_ features: [OverpassMapFeature], selectedLineID: String?) -> [OverpassMapFeature] {
        guard let selectedLineID else { return features }
        return features
            .filter { $0.lineID != selectedLineID } +
            features.filter { $0.lineID == selectedLineID }
    }

    func lineLayers(realLineIDs: Set<String>, usesGeoFallback: Bool, selectedLineID: String?) -> [MetroMapLineLayer] {
        let allLineIDs = repository.lines.map(\.id)
        let selectedLineID = selectedLineID.flatMap { allLineIDs.contains($0) ? $0 : nil }
        var layers: [MetroMapLineLayer] = []

        func append(_ source: MetroMapLineLayerSource, lineIDs: [String]) {
            guard !lineIDs.isEmpty else { return }
            layers.append(MetroMapLineLayer(source: source, lineIDs: lineIDs))
        }

        append(.overpass, lineIDs: allLineIDs.filter { realLineIDs.contains($0) && $0 != selectedLineID })

        if usesGeoFallback {
            append(.repositoryGeo, lineIDs: allLineIDs.filter { $0 != selectedLineID })
        } else {
            append(.schematic, lineIDs: allLineIDs.filter { lineID in
                (realLineIDs.isEmpty || !realLineIDs.contains(lineID)) && lineID != selectedLineID
            })
        }

        guard let selectedLineID else { return layers }
        if usesGeoFallback {
            append(.repositoryGeo, lineIDs: [selectedLineID])
        } else if realLineIDs.contains(selectedLineID) {
            append(.overpass, lineIDs: [selectedLineID])
        } else {
            append(.schematic, lineIDs: [selectedLineID])
        }

        return layers
    }

    func selectedLineScreenRect(selectedLineID: String?, baseMap: OverpassMap, usesGeoFallback: Bool, in size: CGSize) -> CGRect? {
        guard
            let selectedLineID,
            let line = repository.lines.first(where: { $0.id == selectedLineID })
        else { return nil }

        let overpassCoordinates = baseMap.features
            .filter { $0.lineID == selectedLineID }
            .flatMap(\.coordinates)
            .flatMap { $0 }

        if !overpassCoordinates.isEmpty {
            let projection = MetroGeoProjection(bounds: baseMap.bounds, size: size)
            return screenRect(overpassCoordinates.map(projection.screenPoint))
        }

        if usesGeoFallback {
            let projection = MetroGeoProjection(bounds: GeoBounds(stations: repository.stations), size: size)
            let coordinates = line.stationIDs.compactMap { stationID -> GeoCoordinate? in
                guard let station = repository.station(id: stationID) else { return nil }
                return GeoCoordinate(latitude: station.latitude, longitude: station.longitude)
            }
            return screenRect(coordinates.map(projection.screenPoint))
        }

        return screenRect(polyline(for: line).map { screenPoint($0, in: size) })
    }

    func focus(for selectedLineID: String?, baseMap: OverpassMap, usesGeoFallback: Bool, in size: CGSize) -> MetroMapFocus {
        guard let rect = selectedLineScreenRect(selectedLineID: selectedLineID, baseMap: baseMap, usesGeoFallback: usesGeoFallback, in: size) else {
            return .identity
        }

        let targetWidth = max(1, size.width * 0.72)
        let targetHeight = max(1, size.height * 0.72)
        let widthScale = targetWidth / max(rect.width, 1)
        let heightScale = targetHeight / max(rect.height, 1)
        let scale = min(2.35, max(1.18, min(widthScale, heightScale)))
        let viewCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let rectCenter = CGPoint(x: rect.midX, y: rect.midY)
        return MetroMapFocus(
            scale: scale,
            offset: CGSize(
                width: (viewCenter.x - rectCenter.x) * scale,
                height: (viewCenter.y - rectCenter.y) * scale
            )
        )
    }

    func lineWidth(in size: CGSize) -> CGFloat {
        max(4.5, min(size.width, size.height) * 0.018)
    }

    func memoryAnnotationFrames(
        for memories: [UserMemory],
        selectedLineID: String,
        baseMap: OverpassMap,
        usesGeoFallback: Bool,
        in size: CGSize
    ) -> [CGRect] {
        var placedFrames: [CGRect] = []

        for (index, memory) in memories.enumerated() {
            let candidates = memoryAnnotationCandidateCenters(
                for: memory,
                index: index,
                selectedLineID: selectedLineID,
                baseMap: baseMap,
                usesGeoFallback: usesGeoFallback,
                in: size
            )
            let frame = candidates
                .map { memoryAnnotationFrame(centeredAt: $0, in: size) }
                .first { candidate in
                    !placedFrames.contains { $0.expanded(by: Self.memoryAnnotationGap).intersects(candidate) }
                }
                ?? fallbackMemoryAnnotationFrame(index: index, placedFrames: placedFrames, in: size)
            placedFrames.append(frame)
        }

        return placedFrames
    }

    private func screenRect(_ points: [CGPoint]) -> CGRect? {
        guard
            let minX = points.map(\.x).min(),
            let maxX = points.map(\.x).max(),
            let minY = points.map(\.y).min(),
            let maxY = points.map(\.y).max()
        else { return nil }

        return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
    }

    private func polyline(for line: MetroLine, stationIDs: [String]) -> [MapPoint] {
        guard
            let firstID = stationIDs.first,
            let firstStation = repository.station(id: firstID)
        else { return [] }

        var points = [firstStation.mapPoint]
        for index in 0..<(stationIDs.count - 1) {
            let from = stationIDs[index]
            let to = stationIDs[index + 1]
            points.append(contentsOf: bends(lineID: line.id, from: from, to: to))
            if let station = repository.station(id: to) {
                points.append(station.mapPoint)
            }
        }
        return points
    }

    private func bends(lineID: String, from: String, to: String) -> [MapPoint] {
        let key = SegmentKey(lineID: lineID, from: from, to: to)
        if let points = Self.segmentBends[key] {
            return points
        }

        let reverseKey = SegmentKey(lineID: lineID, from: to, to: from)
        return Self.segmentBends[reverseKey].map { Array($0.reversed()) } ?? []
    }

    private func memoryAnnotationCandidateCenters(
        for memory: UserMemory,
        index: Int,
        selectedLineID: String,
        baseMap: OverpassMap,
        usesGeoFallback: Bool,
        in size: CGSize
    ) -> [CGPoint] {
        let start = stationPoint(
            memory.route.start,
            selectedLineID: selectedLineID,
            baseMap: baseMap,
            usesGeoFallback: usesGeoFallback,
            in: size
        )
        let end = stationPoint(
            memory.route.end,
            selectedLineID: selectedLineID,
            baseMap: baseMap,
            usesGeoFallback: usesGeoFallback,
            in: size
        )
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, sqrt(dx * dx + dy * dy))
        let tangent = CGVector(dx: dx / length, dy: dy / length)
        let normal = CGVector(dx: -dy / length, dy: dx / length)
        let routeMidpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let preferredSides: [CGFloat] = index.isMultiple(of: 2) ? [1, -1] : [-1, 1]
        let tangentOffsets: [CGFloat] = [0, -1, 1, -2, 2].map { $0 * (Self.memoryAnnotationSize.width + Self.memoryAnnotationGap) }

        var candidates: [CGPoint] = []
        for lane in 0..<4 {
            let spread = Self.memoryAnnotationBaseSpread + CGFloat(lane) * Self.memoryAnnotationLaneStep
            for side in preferredSides {
                for tangentOffset in tangentOffsets {
                    candidates.append(
                        routeMidpoint
                            .offset(by: normal, distance: spread * side)
                            .offset(by: tangent, distance: tangentOffset)
                    )
                }
            }
        }

        return candidates
    }

    private func stationPoint(
        _ station: MetroStation,
        selectedLineID: String,
        baseMap: OverpassMap,
        usesGeoFallback: Bool,
        in size: CGSize
    ) -> CGPoint {
        let hasOverpassGeometry = baseMap.features.contains { $0.lineID == selectedLineID }
        if usesGeoFallback || hasOverpassGeometry {
            let bounds = usesGeoFallback ? GeoBounds(stations: repository.stations) : baseMap.bounds
            return MetroGeoProjection(bounds: bounds, size: size)
                .screenPoint(GeoCoordinate(latitude: station.latitude, longitude: station.longitude))
        }

        return screenPoint(station.mapPoint, in: size)
    }

    private func memoryAnnotationFrame(centeredAt center: CGPoint, in size: CGSize) -> CGRect {
        let halfWidth = Self.memoryAnnotationSize.width / 2
        let halfHeight = Self.memoryAnnotationSize.height / 2
        let center = CGPoint(
            x: clamped(
                center.x,
                lower: halfWidth + Self.memoryAnnotationEdgePadding,
                upper: size.width - halfWidth - Self.memoryAnnotationEdgePadding
            ),
            y: clamped(
                center.y,
                lower: halfHeight + Self.memoryAnnotationEdgePadding,
                upper: size.height - halfHeight - Self.memoryAnnotationEdgePadding
            )
        )
        return CGRect(
            x: center.x - halfWidth,
            y: center.y - halfHeight,
            width: Self.memoryAnnotationSize.width,
            height: Self.memoryAnnotationSize.height
        )
    }

    private func fallbackMemoryAnnotationFrame(index: Int, placedFrames: [CGRect], in size: CGSize) -> CGRect {
        let columnStride = Self.memoryAnnotationSize.width + Self.memoryAnnotationGap
        let rowStride = Self.memoryAnnotationSize.height + Self.memoryAnnotationGap
        let availableWidth = max(Self.memoryAnnotationSize.width, size.width - Self.memoryAnnotationEdgePadding * 2)
        let columns = max(1, Int((availableWidth + Self.memoryAnnotationGap) / columnStride))
        let slotsToCheck = max(index + columns * 3, placedFrames.count + columns * 3)

        for slot in index..<slotsToCheck {
            let frame = memoryAnnotationStackFrame(
                slot: slot,
                columns: columns,
                columnStride: columnStride,
                rowStride: rowStride,
                in: size
            )
            if !placedFrames.contains(where: { $0.expanded(by: Self.memoryAnnotationGap).intersects(frame) }) {
                return frame
            }
        }

        return memoryAnnotationStackFrame(
            slot: index,
            columns: columns,
            columnStride: columnStride,
            rowStride: rowStride,
            in: size
        )
    }

    private func memoryAnnotationStackFrame(
        slot: Int,
        columns: Int,
        columnStride: CGFloat,
        rowStride: CGFloat,
        in size: CGSize
    ) -> CGRect {
        let column = slot % columns
        let row = slot / columns
        return memoryAnnotationFrame(
            centeredAt: CGPoint(
                x: Self.memoryAnnotationEdgePadding + Self.memoryAnnotationSize.width / 2 + CGFloat(column) * columnStride,
                y: Self.memoryAnnotationEdgePadding + Self.memoryAnnotationSize.height / 2 + CGFloat(row) * rowStride
            ),
            in: size
        )
    }

    private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        let upper = max(lower, upper)
        return min(max(value, lower), upper)
    }

    private static let memoryAnnotationSize = CGSize(width: 112, height: 84)
    private static let memoryAnnotationGap: CGFloat = 8
    private static let memoryAnnotationEdgePadding: CGFloat = 10
    private static let memoryAnnotationBaseSpread: CGFloat = 64
    private static let memoryAnnotationLaneStep: CGFloat = 120

    private static let segmentBends: [SegmentKey: [MapPoint]] = [
        SegmentKey(lineID: "line2", from: "loushanguan-road", to: "zhongshan-park"): [
            MapPoint(x: 36, y: 105)
        ],
        SegmentKey(lineID: "line7", from: "jing-an-temple", to: "changshu-road"): [
            MapPoint(x: 118, y: 136)
        ],
        SegmentKey(lineID: "line7", from: "zhaojiabang-road", to: "longyang-road"): [
            MapPoint(x: 230, y: 170),
            MapPoint(x: 268, y: 130)
        ],
        SegmentKey(lineID: "line9", from: "yishan-road", to: "xujiahui"): [
            MapPoint(x: 108, y: 235)
        ],
        SegmentKey(lineID: "line9", from: "zhaojiabang-road", to: "century-avenue"): [
            MapPoint(x: 212, y: 170),
            MapPoint(x: 235, y: 136)
        ],
        SegmentKey(lineID: "line10", from: "laoximen", to: "yuyuan-garden"): [
            MapPoint(x: 230, y: 146)
        ],
        SegmentKey(lineID: "line10", from: "yuyuan-garden", to: "east-nanjing-road"): [
            MapPoint(x: 230, y: 105)
        ],
        SegmentKey(lineID: "line12", from: "south-shaanxi-road", to: "nanjing-west-road"): [
            MapPoint(x: 122, y: 140)
        ],
        SegmentKey(lineID: "line12", from: "nanjing-west-road", to: "hanzhong-road"): [
            MapPoint(x: 122, y: 58)
        ],
        SegmentKey(lineID: "line13", from: "hanzhong-road", to: "nanjing-west-road"): [
            MapPoint(x: 190, y: 28),
            MapPoint(x: 190, y: 76)
        ],
        SegmentKey(lineID: "line13", from: "nanjing-west-road", to: "xintiandi"): [
            MapPoint(x: 158, y: 128)
        ],
        SegmentKey(lineID: "line8", from: "people-square", to: "laoximen"): [
            MapPoint(x: 186, y: 126)
        ]
    ]
}

private struct SegmentKey: Hashable {
    let lineID: String
    let from: String
    let to: String
}

private extension CGPoint {
    func offset(by vector: CGVector, distance: CGFloat) -> CGPoint {
        CGPoint(
            x: x + vector.dx * distance,
            y: y + vector.dy * distance
        )
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    func expanded(by inset: CGFloat) -> CGRect {
        insetBy(dx: -inset, dy: -inset)
    }
}
