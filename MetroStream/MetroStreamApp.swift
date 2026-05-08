import SwiftUI

@main
struct MetroStreamApp: App {
    var body: some Scene {
        WindowGroup {
            ContentBootstrapView()
        }
    }
}

struct ContentBootstrapView: View {
    @State private var appState = AppState()
    @State private var locationService = LocationService()

    var body: some View {
        switch appState.screen {
        case .home:
            HomeView(appState: appState)
        case .stationSelection:
            StationSelectionView(appState: appState, locationService: locationService)
        case .cabin:
            CabinView(appState: appState)
        case .memories:
            MemoryPlaceholderView(appState: appState)
        }
    }
}

private struct MemoryPlaceholderView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()
            VStack {
                HStack {
                    Button {
                        appState.closeToHome()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(IconCircleButtonStyle())
                    Spacer()
                }
                .padding(24)

                MetroMapView(repository: appState.repository, highlightedRoutes: appState.memories.map(\.route))
                    .padding(30)
            }
        }
    }
}
