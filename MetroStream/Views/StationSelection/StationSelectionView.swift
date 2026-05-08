import SwiftUI

struct StationSelectionView: View {
    @Bindable var appState: AppState
    @Bindable var locationService: LocationService
    @State private var selectedLineID = ""
    @State private var selectedStationID = ""
    @State private var selectingDestination = false
    @State private var showDistanceWarning = false

    private var nearbyStations: [LocatedStation] {
        locationService.nearbyStations(repository: appState.repository)
    }

    private var nearbyStationIDs: Set<String> {
        Set(nearbyStations.map(\.station.id))
    }

    private var lineOptions: [MetroLine] {
        if selectingDestination {
            return appState.repository.lines
        }
        let nearbyIDs = nearbyStationIDs
        let nearbyLines = appState.repository.lines(containingAnyStationIDs: nearbyIDs)
        return nearbyLines.isEmpty ? appState.repository.lines : nearbyLines
    }

    private var stationOptions: [MetroStation] {
        let activeLineID = selectedLineID.isEmpty ? lineOptions.first?.id : selectedLineID
        guard let activeLineID else { return [] }
        return appState.repository.stations(onLineID: activeLineID)
    }

    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                topBar
                selectedStrip
                wheelSelector
                enterButton
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .task {
            locationService.requestAuthorization()
            synchronizeWheelSelection()
        }
        .onChange(of: selectingDestination) { _, _ in
            synchronizeWheelSelection()
        }
        .onChange(of: nearbyStations) { _, _ in
            if !selectingDestination {
                synchronizeWheelSelection()
            }
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
                synchronizeWheelSelection()
            }
            .buttonStyle(TextChipStyle(isSelected: !selectingDestination))

            Button("到达站") {
                selectingDestination = true
                synchronizeWheelSelection()
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

    private var wheelSelector: some View {
        WheelStationSelector(
            lineOptions: lineOptions,
            stationOptions: stationOptions,
            selectedLineID: Binding(
                get: { selectedLineID },
                set: { selectLine($0) }
            ),
            selectedStationID: Binding(
                get: { selectedStationID },
                set: { selectStationID($0) }
            ),
            stationIsEnabled: { station in
                selectingDestination || nearbyStationIDs.contains(station.id)
            }
        )
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
                    .padding(.bottom, 10)
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

    private func synchronizeWheelSelection() {
        let currentStation = selectingDestination ? appState.selectedDestination : appState.selectedStart
        let options = lineOptions
        let candidateLine = currentStation.flatMap(appState.repository.firstLine(containing:))
        let fallbackLine = candidateLine.flatMap { candidate in
            options.contains(where: { $0.id == candidate.id }) ? candidate : nil
        } ?? options.first

        selectedLineID = fallbackLine?.id ?? ""

        let fallbackStation = currentStation.flatMap { station in
            station.lineIDs.contains(selectedLineID) ? station : nil
        } ?? stationOptions.first { station in
            selectingDestination || nearbyStationIDs.contains(station.id)
        } ?? stationOptions.first

        selectedStationID = fallbackStation?.id ?? ""
    }

    private func selectLine(_ lineID: String) {
        selectedLineID = lineID
        let stations = appState.repository.stations(onLineID: lineID)
        guard let station = stations.first(where: { station in
            selectingDestination || nearbyStationIDs.contains(station.id)
        }) ?? stations.first else {
            selectedStationID = ""
            return
        }
        selectStation(station)
    }

    private func selectStationID(_ stationID: String) {
        guard let station = appState.repository.station(id: stationID) else { return }
        selectStation(station)
    }

    private func selectStation(_ station: MetroStation) {
        if selectingDestination {
            appState.selectDestination(station)
        } else if nearbyStationIDs.contains(station.id) {
            appState.selectStart(station)
            selectingDestination = true
        } else {
            showDistanceWarning = true
            let currentOptionIDs = Set(stationOptions.map(\.id))
            let committedStartID = appState.selectedStart?.id
            selectedStationID = committedStartID.flatMap { currentOptionIDs.contains($0) ? $0 : nil }
                ?? stationOptions.first(where: { nearbyStationIDs.contains($0.id) })?.id
                ?? stationOptions.first?.id
                ?? selectedStationID
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showDistanceWarning = false
            }
            return
        }

        selectedStationID = station.id
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

private struct WheelStationSelector: View {
    let lineOptions: [MetroLine]
    let stationOptions: [MetroStation]
    @Binding var selectedLineID: String
    @Binding var selectedStationID: String
    var stationIsEnabled: (MetroStation) -> Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(SardineColors.paperRaised)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(SardineColors.hairline, lineWidth: 1))

            Rectangle()
                .fill(SardineColors.ink.opacity(0.07))
                .frame(height: 52)
                .overlay(Rectangle().stroke(SardineColors.hairline.opacity(0.65), lineWidth: 1))

            HStack(spacing: 0) {
                Picker("线路", selection: $selectedLineID) {
                    ForEach(lineOptions) { line in
                        Text(line.name)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .tag(line.id)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Rectangle()
                    .fill(SardineColors.hairline)
                    .frame(width: 1, height: 170)

                Picker("站点", selection: $selectedStationID) {
                    ForEach(stationOptions) { station in
                        Text(station.name)
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundStyle(stationIsEnabled(station) ? SardineColors.ink : SardineColors.mutedInk.opacity(0.48))
                            .tag(station.id)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 252)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.18),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
