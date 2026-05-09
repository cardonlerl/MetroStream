import SwiftUI

struct StationSelectionView: View {
    @Bindable var appState: AppState
    @Bindable var locationService: LocationService
    var showsBackButton = true

    init(appState: AppState, locationService: LocationService, showsBackButton: Bool = true) {
        self.appState = appState
        self.locationService = locationService
        self.showsBackButton = showsBackButton
    }

    var body: some View {
        DepartureVisualScreen(appState: appState, reservesBottomTabSpace: !showsBackButton)
            .ignoresSafeArea()
    }
}

private struct DepartureVisualScreen: View {
    @Bindable var appState: AppState
    let reservesBottomTabSpace: Bool
    @State private var activeSelector: StationSelectionTarget?
    private let backgroundImage = DepartureVisualResource.image(named: "DepartureBackground", fileExtension: "png", in: .main)
    private let ticketInk = Color(red: 135 / 255, green: 53 / 255, blue: 17 / 255)
    private let buttonFill = Color(red: 175 / 255, green: 98 / 255, blue: 64 / 255)
    private let ticketPaper = Color(red: 242 / 255, green: 228 / 255, blue: 210 / 255)
    private let linePurple = Color(red: 204 / 255, green: 166 / 255, blue: 212 / 255)
    private let lineYellow = Color(red: 1, green: 232 / 255, blue: 0)

    private var catalog: StationSelectorCatalog {
        StationSelectorCatalog(repository: appState.repository)
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.width / 393, proxy.size.height / 852)
            let scaledSize = CGSize(width: 393 * scale, height: 852 * scale)
            let offset = CGSize(
                width: (proxy.size.width - scaledSize.width) / 2,
                height: (proxy.size.height - scaledSize.height) / 2
            )
            let actionButtonOrigin = DepartureTicketLayout.actionButtonOrigin(
                reservesBottomTabSpace: reservesBottomTabSpace
            )

            ZStack(alignment: .topLeading) {
                Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)

                if let backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 520, height: 926)
                        .blur(radius: 4)
                        .offset(x: -55, y: -74)
                }

                ticketHeader

                Rectangle()
                    .fill(ticketInk.opacity(0.64))
                    .frame(width: 392, height: 377)
                    .rotationEffect(.degrees(-4.5))
                    .offset(x: -4, y: 207)

                DepartureTicketShape()
                    .fill(ticketPaper)
                    .frame(width: 360, height: 357)
                    .offset(x: 14, y: 218)

                TicketTicks(color: Color(red: 176 / 255, green: 124 / 255, blue: 101 / 255), count: 34)
                    .frame(width: 132, height: 6)
                    .offset(x: 22, y: 226)

                TicketTicks(color: .white, count: 16)
                    .frame(width: 60, height: 6)
                    .rotationEffect(.degrees(-4.5))
                    .offset(x: 353, y: 569)

                ticketContent

                Button {
                    _ = DepartureTicketRoute.featured.apply(to: appState)
                } label: {
                    Text("出发")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: DepartureTicketLayout.actionButtonSize.width, height: DepartureTicketLayout.actionButtonSize.height)
                        .background(buttonFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .offset(x: actionButtonOrigin.x, y: actionButtonOrigin.y)
            }
            .frame(width: 393, height: 852, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(offset)
        }
        .sheet(item: $activeSelector) { target in
            StationSelectorSheet(
                catalog: catalog,
                target: target,
                initialLineID: selectedLineID(for: target)
            ) { station in
                select(station, for: target)
            }
            .presentationDetents([.fraction(0.54), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var ticketHeader: some View {
        Group {
            Text("上海")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(ticketInk.opacity(0.2))
                .offset(x: 14, y: 163)

            Text("SHANGHAI")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(ticketInk.opacity(0.2))
                .offset(x: 185, y: 163)
        }
    }

    private var ticketContent: some View {
        Group {
            Text("出发站")
                .ticketCaption(ticketInk)
                .offset(x: 54, y: 254)

            Button {
                activeSelector = .start
            } label: {
                TicketStationRow(
                    lineNumber: selectedLineNumber(for: .start),
                    color: selectedLineColor(for: .start),
                    stationName: appState.selectedStart?.name ?? "一大会址 · 新天地站"
                )
                .frame(width: 280, height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 54, y: 284)

            TicketDashedLine(color: ticketInk.opacity(0.64))
                .frame(width: 312, height: 1)
                .offset(x: 38, y: 348)

            Text("到达站")
                .ticketCaption(ticketInk)
                .offset(x: 54, y: 384)

            Button {
                activeSelector = .destination
            } label: {
                TicketStationRow(
                    lineNumber: selectedLineNumber(for: .destination),
                    color: selectedLineColor(for: .destination),
                    stationName: appState.selectedDestination?.name ?? "上海南站"
                )
                .frame(width: 280, height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 54, y: 414)

            TicketDashedLine(color: ticketInk.opacity(0.64))
                .frame(width: 312, height: 1)
                .offset(x: 38, y: 478)

            ticketMeta
        }
    }

    private var ticketMeta: some View {
        Group {
            TicketMetaPair(title: "日期", value: "2026-05-09")
                .offset(x: 38, y: 502)

            TicketMetaPair(title: "乘客", value: "USERNAME")
                .offset(x: 194, y: 502)

            TicketMetaPair(title: "城市", value: "SHANGHI")
                .offset(x: 38, y: 532)

            TicketMetaPair(title: "人数", value: "1")
                .offset(x: 194, y: 532)
        }
    }

    private func selectedLineID(for target: StationSelectionTarget) -> String? {
        switch target {
        case .start:
            return appState.selectedStart?.lineIDs.first ?? "line10"
        case .destination:
            return appState.selectedDestination?.lineIDs.first ?? "line3"
        }
    }

    private func selectedLineNumber(for target: StationSelectionTarget) -> String {
        guard let lineID = selectedLineID(for: target), let line = catalog.line(forLineID: lineID) else {
            return target == .start ? "10" : "3"
        }
        return StationSelectorCatalog.badgeText(for: line)
    }

    private func selectedLineColor(for target: StationSelectionTarget) -> Color {
        guard let lineID = selectedLineID(for: target), let line = catalog.line(forLineID: lineID) else {
            return target == .start ? linePurple : lineYellow
        }
        return Color(hex: line.colorHex)
    }

    private func select(_ station: MetroStation, for target: StationSelectionTarget) {
        switch target {
        case .start:
            appState.selectStart(station)
        case .destination:
            appState.selectDestination(station)
        }
        activeSelector = nil
    }
}

struct DepartureTicketLayout {
    static let actionButtonSize = CGSize(width: 112, height: 48)

    static func actionButtonOrigin(reservesBottomTabSpace: Bool) -> CGPoint {
        CGPoint(x: 141, y: reservesBottomTabSpace ? 662 : 738)
    }
}

struct DepartureTicketRoute {
    static let featured = DepartureTicketRoute(startStationName: "新天地", destinationStationName: "上海南站")

    let startStationName: String
    let destinationStationName: String

    func apply(to appState: AppState) -> Bool {
        guard
            let start = appState.selectedStart ?? appState.repository.station(named: startStationName),
            let destination = appState.selectedDestination ?? appState.repository.station(named: destinationStationName)
        else { return false }

        appState.selectStart(start)
        appState.selectDestination(destination)
        appState.enterCabin()
        return appState.currentRide != nil
    }
}

enum StationSelectionTarget: String, Identifiable {
    case start
    case destination

    var id: String { rawValue }
}

struct StationSelectorCatalog {
    let repository: MetroRepository

    var lines: [MetroLine] {
        repository.lines
    }

    func line(forLineID lineID: String) -> MetroLine? {
        lines.first { $0.id == lineID }
    }

    func line(for station: MetroStation, preferredLineID: String? = nil) -> MetroLine? {
        if let preferredLineID, station.lineIDs.contains(preferredLineID), let line = line(forLineID: preferredLineID) {
            return line
        }
        return station.lineIDs.compactMap(line(forLineID:)).first
    }

    func stations(forLineID lineID: String) -> [MetroStation] {
        repository.stations(onLineID: lineID)
    }

    func searchStations(matching query: String) -> [MetroStation] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        return repository.stations.filter { station in
            station.name.localizedStandardContains(trimmedQuery)
        }
    }

    static func badgeText(for line: MetroLine) -> String {
        if line.id.hasPrefix("line") {
            return String(line.id.dropFirst(4))
        }
        return String(line.name.prefix(1))
    }
}

private struct TicketStationRow: View {
    let lineNumber: String
    let color: Color
    let stationName: String

    private let ticketInk = Color(red: 135 / 255, green: 53 / 255, blue: 17 / 255)

    var body: some View {
        HStack(spacing: 16) {
            Text(lineNumber)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(color, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))

            Text(stationName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ticketInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            ChevronDownMark()
                .stroke(Color(red: 175 / 255, green: 98 / 255, blue: 64 / 255), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 20)
        }
    }
}

private struct StationSelectorSheet: View {
    let catalog: StationSelectorCatalog
    let target: StationSelectionTarget
    let onSelect: (MetroStation) -> Void

    @State private var selectedLineID: String
    @State private var query = ""

    private let ticketInk = Color(red: 135 / 255, green: 53 / 255, blue: 17 / 255)
    private let buttonFill = Color(red: 175 / 255, green: 98 / 255, blue: 64 / 255)
    private let ticketPaper = Color(red: 242 / 255, green: 228 / 255, blue: 210 / 255)

    init(
        catalog: StationSelectorCatalog,
        target: StationSelectionTarget,
        initialLineID: String?,
        onSelect: @escaping (MetroStation) -> Void
    ) {
        self.catalog = catalog
        self.target = target
        self.onSelect = onSelect
        self._selectedLineID = State(initialValue: initialLineID ?? catalog.lines.first?.id ?? "")
    }

    private var shownStations: [MetroStation] {
        let searchResults = catalog.searchStations(matching: query)
        return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? catalog.stations(forLineID: selectedLineID)
            : searchResults
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ticketInk.opacity(0.52))

                TextField("搜索站点", text: $query)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(ticketInk)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(ticketInk.opacity(0.08), in: Capsule())
            .padding(.horizontal, 18)
            .padding(.top, 18)

            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(catalog.lines) { line in
                            Button {
                                selectedLineID = line.id
                                query = ""
                            } label: {
                                Text(line.name)
                                    .font(.system(size: 14, weight: selectedLineID == line.id ? .medium : .regular))
                                    .foregroundStyle(selectedLineID == line.id ? .white : ticketInk)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .frame(height: 38)
                                    .background(
                                        selectedLineID == line.id
                                            ? buttonFill
                                            : ticketInk.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
                .frame(width: 118)

                Rectangle()
                    .fill(ticketInk.opacity(0.16))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(shownStations) { station in
                            Button {
                                onSelect(station)
                            } label: {
                                StationSelectorStationRow(
                                    station: station,
                                    line: catalog.line(for: station, preferredLineID: selectedLineID)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                }
            }
        }
        .background(ticketPaper)
    }
}

private struct StationSelectorStationRow: View {
    let station: MetroStation
    let line: MetroLine?

    private let ticketInk = Color(red: 135 / 255, green: 53 / 255, blue: 17 / 255)

    var body: some View {
        HStack(spacing: 12) {
            Text(line.map(StationSelectorCatalog.badgeText(for:)) ?? "")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.78))
                .frame(width: 26, height: 26)
                .background(line.map { Color(hex: $0.colorHex) } ?? ticketInk.opacity(0.16), in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 1.6))

            Text(station.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ticketInk)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)
        }
        .frame(height: 48)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ticketInk.opacity(0.12))
                .frame(height: 1)
        }
    }
}

private struct TicketMetaPair: View {
    let title: String
    let value: String

    private let ticketInk = Color(red: 135 / 255, green: 53 / 255, blue: 17 / 255)

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Text(value)
        }
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(ticketInk.opacity(0.53))
        .frame(height: 18, alignment: .center)
    }
}

private struct TicketTicks: View {
    let color: Color
    let count: Int

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                guard count > 1 else { return }
                let step = size.width / CGFloat(count - 1)

                for index in 0..<count {
                    var path = Path()
                    let x = CGFloat(index) * step
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(color), lineWidth: 1 / max(proxy.size.width / 132, 1))
                }
            }
        }
    }
}

private struct TicketDashedLine: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1, lineCap: .butt, dash: [2, 4])
            )
        }
    }
}

private struct DepartureTicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let x = rect.minX
        let y = rect.minY
        let width = rect.width
        let height = rect.height
        let scaleX = width / 360
        let scaleY = height / 357

        func point(_ pointX: CGFloat, _ pointY: CGFloat) -> CGPoint {
            CGPoint(x: x + pointX * scaleX, y: y + pointY * scaleY)
        }

        var path = Path()
        path.move(to: point(360, 110))
        path.addCurve(to: point(340, 130), control1: point(348.954, 110), control2: point(340, 118.954))
        path.addCurve(to: point(360, 150), control1: point(340, 141.046), control2: point(348.954, 150))
        path.addLine(to: point(360, 357))
        path.addLine(to: point(0, 357))
        path.addLine(to: point(0, 150))
        path.addCurve(to: point(20, 130), control1: point(11.046, 150), control2: point(20, 141.046))
        path.addCurve(to: point(0, 110), control1: point(20, 118.954), control2: point(11.046, 110))
        path.addLine(to: point(0, 0))
        path.addLine(to: point(360, 0))
        path.closeSubpath()
        return path
    }
}

private struct ChevronDownMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + rect.height * 0.38))
        return path
    }
}

private extension Text {
    func ticketCaption(_ color: Color) -> some View {
        font(.system(size: 12, weight: .regular))
            .foregroundStyle(color.opacity(0.53))
            .frame(height: 18, alignment: .center)
    }
}

private enum DepartureVisualResource {
    static func image(named name: String, fileExtension: String, in bundle: Bundle) -> UIImage? {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
