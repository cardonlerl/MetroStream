import SwiftUI

struct MetroMapView: View {
    let repository: MetroRepository
    var highlightedRoutes: [RoutePlan] = []
    var selectedStationID: String?
    var onStationTap: ((MetroStation) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(repository.lines) { line in
                    linePath(line, in: size)
                        .stroke(Color(hex: line.colorHex).opacity(0.42), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }

                ForEach(highlightedRoutes) { route in
                    if let line = repository.lines.first(where: { $0.id == route.lineID }) {
                        routePath(route, line: line, in: size)
                            .stroke(Color(hex: line.colorHex), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }

                ForEach(repository.stations) { station in
                    let point = screenPoint(station.mapPoint, in: size)
                    Button {
                        onStationTap?(station)
                    } label: {
                        Circle()
                            .fill(selectedStationID == station.id ? SardineColors.ink : SardineColors.paperRaised)
                            .frame(width: selectedStationID == station.id ? 10 : 7, height: selectedStationID == station.id ? 10 : 7)
                            .overlay(Circle().stroke(SardineColors.ink.opacity(0.55), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .disabled(onStationTap == nil)
                    .accessibilityLabel(station.name)
                }
            }
            .padding(4)
        }
    }

    private func linePath(_ line: MetroLine, in size: CGSize) -> Path {
        Path { path in
            for (index, stationID) in line.stationIDs.enumerated() {
                guard let station = repository.station(id: stationID) else { continue }
                let point = screenPoint(station.mapPoint, in: size)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func routePath(_ route: RoutePlan, line: MetroLine, in size: CGSize) -> Path {
        Path { path in
            guard
                let startIndex = line.stationIDs.firstIndex(of: route.start.id),
                let endIndex = line.stationIDs.firstIndex(of: route.end.id)
            else { return }

            let bounds = startIndex <= endIndex ? startIndex...endIndex : endIndex...startIndex
            for (offset, stationID) in line.stationIDs[bounds].enumerated() {
                guard let station = repository.station(id: stationID) else { continue }
                let point = screenPoint(station.mapPoint, in: size)
                if offset == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func screenPoint(_ mapPoint: MapPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * mapPoint.x / 170,
            y: size.height * mapPoint.y / 200
        )
    }
}
