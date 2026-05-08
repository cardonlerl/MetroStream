import SwiftUI

struct HomeView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        appState.openMemories()
                    } label: {
                        Image(systemName: "circle.grid.2x2")
                    }
                    .buttonStyle(IconCircleButtonStyle())
                    .accessibilityLabel("我的记录")
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                MetroMapView(repository: appState.repository)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 28)

                Button("出发") {
                    appState.openSelection()
                }
                .buttonStyle(PrimaryPaperButtonStyle())
                .padding(.horizontal, 34)
                .padding(.bottom, 30)
            }
        }
    }
}
