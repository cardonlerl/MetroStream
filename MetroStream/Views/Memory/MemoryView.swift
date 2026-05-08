import SwiftUI

struct MemoryView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                MetroMapView(
                    repository: appState.repository,
                    highlightedRoutes: appState.memories.map(\.route)
                )
                .frame(height: 270)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 14)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(appState.memories) { memory in
                            MemoryRideSection(memory: memory)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
                }
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
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }
}

private struct MemoryRideSection: View {
    let memory: UserMemory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(memory.route.lineName)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(SardineColors.ink)

                Text("\(memory.route.start.name)→\(memory.route.end.name)")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(SardineColors.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            ForEach(memory.entries) { entry in
                MemoryEntryCard(entry: entry)
            }
        }
    }
}

private struct MemoryEntryCard: View {
    let entry: CabinEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch entry.kind {
            case .text:
                Text(entry.text)
                    .font(.system(size: 15, design: .serif))
            case .drawing:
                MemoryDrawing(strokes: entry.drawing)
                    .frame(height: 118)
            case .music:
                Text("《\(entry.songTitle ?? "")》")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                Text(entry.text)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(SardineColors.mutedInk)
            }
        }
        .foregroundStyle(SardineColors.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SardineColors.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SardineColors.hairline, lineWidth: 1))
    }
}

private struct MemoryDrawing: View {
    let strokes: [DrawingStroke]

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                var path = Path()
                for (index, point) in stroke.points.enumerated() {
                    let cgPoint = CGPoint(x: size.width * point.x, y: size.height * point.y)
                    if index == 0 {
                        path.move(to: cgPoint)
                    } else {
                        path.addLine(to: cgPoint)
                    }
                }
                let color = stroke.isEraser ? SardineColors.paperRaised : SardineColors.ink.opacity(0.78)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
            }
        }
        .background(SardineColors.paperRaised)
    }
}
