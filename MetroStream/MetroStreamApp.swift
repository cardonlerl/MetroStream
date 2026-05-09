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
            HomeView(appState: appState, locationService: locationService)
        case .stationSelection:
            StationSelectionView(appState: appState, locationService: locationService)
        case .cabin:
            CabinView(appState: appState)
        case .memories:
            MemoryView(appState: appState)
        }
    }
}
