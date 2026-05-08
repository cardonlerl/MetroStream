import SwiftUI

struct StationSelectionView: View {
    @Bindable var appState: AppState
    @Bindable var locationService: LocationService
    @State private var query = ""
    @State private var selectingDestination = false
    @State private var showDistanceWarning = false

    private var nearbyStations: [LocatedStation] {
        locationService.nearbyStations(repository: appState.repository)
    }

    private var displayedStations: [MetroStation] {
        let source = selectingDestination
            ? appState.repository.stations
            : nearbyStations.map(\.station)
        guard !query.isEmpty else { return source }
        return source.filter { $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                topBar
                selectedStrip
                searchField
                stationList
                enterButton
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .task {
            locationService.requestAuthorization()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                appState.closeToHome()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(IconCircleButtonStyle())

            Spacer()

            Button("出发站") {
                selectingDestination = false
                query = ""
            }
            .buttonStyle(TextChipStyle(isSelected: !selectingDestination))

            Button("到达站") {
                selectingDestination = true
                query = ""
            }
            .buttonStyle(TextChipStyle(isSelected: selectingDestination))
        }
    }

    private var selectedStrip: some View {
        HStack(spacing: 10) {
            StationPill(text: appState.selectedStart?.name ?? "出发")
            Rectangle()
                .fill(SardineColors.hairline)
                .frame(width: 28, height: 1)
            StationPill(text: appState.selectedDestination?.name ?? "到达")
            Spacer()
            if let minutes = appState.currentRoute?.estimatedMinutes {
                Text("约 \(minutes) 分钟")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(SardineColors.mutedInk)
            }
        }
    }

    private var searchField: some View {
        TextField("站名", text: $query)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 17, weight: .regular, design: .serif))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(SardineColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(SardineColors.hairline, lineWidth: 1))
    }

    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(displayedStations) { station in
                    Button {
                        choose(station)
                    } label: {
                        HStack {
                            Text(station.name)
                                .font(.system(size: 17, weight: .regular, design: .serif))
                            Spacer()
                            if !selectingDestination, let nearby = nearbyStations.first(where: { $0.station.id == station.id }) {
                                Text(distanceText(nearby.distanceMeters))
                                    .font(.system(size: 13, design: .serif))
                                    .foregroundStyle(SardineColors.mutedInk)
                            }
                        }
                        .foregroundStyle(SardineColors.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(SardineColors.paperRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SardineColors.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showDistanceWarning {
                Text("你还没到站")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(SardineColors.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(SardineColors.paperRaised)
                    .clipShape(Capsule())
                    .shadow(color: SardineColors.softShadow, radius: 10, y: 4)
                    .padding(.bottom, 8)
            }
        }
    }

    private var enterButton: some View {
        Button("进入车厢") {
            appState.enterCabin()
        }
        .buttonStyle(PrimaryPaperButtonStyle())
        .disabled(appState.currentRoute == nil)
        .opacity(appState.currentRoute == nil ? 0.35 : 1)
    }

    private func choose(_ station: MetroStation) {
        if selectingDestination {
            appState.selectDestination(station)
        } else if nearbyStations.contains(where: { $0.station.id == station.id }) {
            appState.selectStart(station)
            selectingDestination = true
        } else {
            showDistanceWarning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showDistanceWarning = false
            }
        }
        query = ""
    }

    private func distanceText(_ meters: Double) -> String {
        meters < 1_000
            ? "\(Int(meters))m"
            : String(format: "%.1fkm", meters / 1_000)
    }
}

private struct StationPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium, design: .serif))
            .foregroundStyle(SardineColors.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(SardineColors.paperRaised)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(SardineColors.hairline, lineWidth: 1))
    }
}
