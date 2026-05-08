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
            CabinPlaceholderView(appState: appState)
        case .memories:
            MemoryPlaceholderView(appState: appState)
        }
    }
}

private struct CabinPlaceholderView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()
            VStack {
                HStack {
                    Text(appState.currentRoute?.lineName ?? "")
                        .font(.system(size: 15, design: .serif))
                    Spacer()
                    Button("下车") {
                        appState.endRide()
                    }
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(SardineColors.mutedInk)
                }
                .padding(24)
                Spacer()
            }
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
