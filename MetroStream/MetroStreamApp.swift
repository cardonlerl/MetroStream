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
    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()
            Button("出发") {}
                .buttonStyle(PrimaryPaperButtonStyle())
                .padding(.horizontal, 36)
        }
    }
}
