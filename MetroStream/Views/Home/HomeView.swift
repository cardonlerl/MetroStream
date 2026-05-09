import SwiftUI

enum HomeTab: CaseIterable, Hashable {
    case departure
    case history
}

struct HomeView: View {
    @Bindable var appState: AppState
    @Bindable var locationService: LocationService
    @State private var selectedHomeTab: HomeTab = .departure
    @State private var baseMap = OverpassMap.empty()
    @State private var selectedLineID: String? = "line1"

    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()

            TabView(selection: $selectedHomeTab) {
                StationSelectionView(appState: appState, locationService: locationService, showsBackButton: false)
                    .tabItem {
                        Label("出发", systemImage: "tram.fill")
                    }
                    .tag(HomeTab.departure)

                historyMapTab
                    .tabItem {
                        Label("历史记录", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(HomeTab.history)
            }
            .tint(SardineColors.lineRed)
            .toolbarBackground(selectedHomeTab == .history ? SardineColors.historyBackground : SardineColors.paper, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        }
    }

    private var historyMapTab: some View {
        ZStack(alignment: .bottom) {
            SardineColors.historyBackground.ignoresSafeArea()

            MetroMapView(
                repository: appState.repository,
                backgroundColor: SardineColors.historyBackground,
                baseMap: baseMap,
                lineMemories: selectedLineMemories,
                selectedLineID: selectedLineID
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            LineWheelPicker(lines: appState.repository.lines, selectedLineID: $selectedLineID)
                .frame(height: 58)
                .padding(.bottom, 14)
        }
        .task {
            await loadBaseMap()
        }
    }

    private var selectedLineMemories: [UserMemory] {
        guard let selectedLineID else { return [] }
        return appState.memories.filter { $0.route.lineID == selectedLineID }
    }

    private func loadBaseMap() async {
        let bounds = GeoBounds(stations: appState.repository.stations)
        do {
            baseMap = try await OverpassMapClient.live.fetch(bounds: bounds)
        } catch {
            baseMap = .empty(bounds: bounds)
        }
    }
}

private struct LineWheelPicker: View {
    let lines: [MetroLine]
    @Binding var selectedLineID: String?
    @State private var scrollPosition: String?
    private let itemWidth: CGFloat = 82

    var body: some View {
        GeometryReader { proxy in
            let sidePadding = max(0, (proxy.size.width - itemWidth) / 2)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 6) {
                    ForEach(lines) { line in
                        let isSelected = selectedLineID == line.id
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                selectedLineID = isSelected ? nil : line.id
                                scrollPosition = line.id
                            }
                        } label: {
                            Text(line.name)
                        }
                        .buttonStyle(LineWheelButtonStyle(color: Color(hex: line.colorHex), isSelected: isSelected))
                        .frame(width: itemWidth)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.58)
                                .offset(y: phase.isIdentity ? 0 : 4)
                        }
                        .id(line.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.horizontal, sidePadding)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .onChange(of: scrollPosition) { _, newValue in
                if selectedLineID != newValue {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedLineID = newValue
                    }
                }
            }
            .onChange(of: selectedLineID) { _, newValue in
                if scrollPosition != newValue {
                    scrollPosition = newValue
                }
            }
        }
    }
}

private struct LineWheelButtonStyle: ButtonStyle {
    let color: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isSelected ? 15 : 13, weight: isSelected ? .medium : .regular, design: .serif))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(isSelected ? color : SardineColors.ink.opacity(0.64))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(SardineColors.paperRaised.opacity(isSelected ? 0.72 : 0.34))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.68) : SardineColors.hairline.opacity(0.42), lineWidth: isSelected ? 1 : 0.7)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
