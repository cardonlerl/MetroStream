import SwiftUI

struct CabinView: View {
    @Bindable var appState: AppState
    @State private var cabinIndex = 0
    @State private var showingPublisher = false
    @State private var showingExitConfirm = false
    @State private var showingClosed = false
    @State private var remainingSeconds: Int

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(appState: AppState) {
        self.appState = appState
        let seconds = max(60, (appState.currentRoute?.estimatedMinutes ?? 1) * 60)
        _remainingSeconds = State(initialValue: seconds)
    }

    var body: some View {
        ZStack {
            SardineColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                cabinPager
                publishButton
            }
            .blur(radius: showingClosed ? 3 : 0)

            if showingClosed {
                Text("这节车厢关闭了。")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(SardineColors.ink)
                    .padding(24)
                    .background(SardineColors.paperRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(SardineColors.hairline, lineWidth: 1))
            }
        }
        .sheet(isPresented: $showingPublisher) {
            PublishSheet(routeKey: appState.currentRoute?.routeKey ?? "") { entry in
                try appState.publish(entry)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("提前离开这节车厢？", isPresented: $showingExitConfirm) {
            Button("留在车上", role: .cancel) {}
            Button("下车") {
                closeCabin()
            }
        } message: {
            Text("你发布的内容会留在这里。")
        }
        .onReceive(timer) { _ in
            guard !showingClosed else { return }
            remainingSeconds -= 1
            if remainingSeconds <= 0 {
                closeCabin()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentRoute?.lineName ?? "")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(SardineColors.ink)
                if let route = appState.currentRoute {
                    Text("\(route.start.name)→\(route.end.name)")
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(SardineColors.mutedInk)
                }
            }

            Spacer()

            Text(timeText)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(SardineColors.mutedInk)

            Button("下车") {
                showingExitConfirm = true
            }
            .font(.system(size: 13, design: .serif))
            .foregroundStyle(SardineColors.mutedInk.opacity(0.82))
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var cabinPager: some View {
        TabView(selection: $cabinIndex) {
            ForEach(0..<3, id: \.self) { index in
                CabinScene(
                    entries: entries(for: index),
                    index: index
                )
                .tag(index)
                .padding(.horizontal, 18)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var publishButton: some View {
        Button {
            showingPublisher = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .regular))
                .frame(width: 56, height: 56)
        }
        .foregroundStyle(SardineColors.paperRaised)
        .background(SardineColors.ink)
        .clipShape(Circle())
        .padding(.bottom, 28)
        .accessibilityLabel("发布")
    }

    private var timeText: String {
        let minutes = max(0, remainingSeconds) / 60
        let seconds = max(0, remainingSeconds) % 60
        return "\(minutes):" + String(format: "%02d", seconds)
    }

    private func entries(for index: Int) -> [CabinEntry] {
        guard let route = appState.currentRoute else { return [] }
        let mine = appState.currentRide?.publishedEntries ?? []
        return appState.repository.seedEntries(for: route, cabinIndex: index) + mine
    }

    private func closeCabin() {
        showingClosed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            appState.endRide()
        }
    }
}

private struct CabinScene: View {
    let entries: [CabinEntry]
    let index: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(SardineColors.paper.opacity(0.1))

                ForEach(0..<min(7, max(3, entries.count + 1)), id: \.self) { item in
                    PersonShape()
                        .stroke(SardineColors.ink.opacity(0.18 + Double(item % 3) * 0.08), lineWidth: 1.2)
                        .frame(width: 34 + CGFloat(item % 2) * 8, height: 92 + CGFloat(item % 3) * 12)
                        .position(personPosition(item: item, size: proxy.size))
                }

                ForEach(Array(entries.prefix(6).enumerated()), id: \.element.id) { offset, entry in
                    EntryBubble(entry: entry)
                        .frame(width: bubbleWidth(entry))
                        .position(bubblePosition(offset: offset, size: proxy.size))
                        .floating(delay: Double(offset) * 0.45)
                }
            }
        }
    }

    private func personPosition(item: Int, size: CGSize) -> CGPoint {
        let xSeeds: [CGFloat] = [0.16, 0.38, 0.72, 0.56, 0.84, 0.26, 0.66]
        let ySeeds: [CGFloat] = [0.72, 0.63, 0.76, 0.82, 0.58, 0.86, 0.68]
        return CGPoint(x: size.width * xSeeds[item % xSeeds.count], y: size.height * ySeeds[item % ySeeds.count])
    }

    private func bubblePosition(offset: Int, size: CGSize) -> CGPoint {
        let xSeeds: [CGFloat] = [0.35, 0.66, 0.24, 0.76, 0.50, 0.18]
        let ySeeds: [CGFloat] = [0.24, 0.34, 0.47, 0.55, 0.16, 0.64]
        return CGPoint(x: size.width * xSeeds[offset % xSeeds.count], y: size.height * ySeeds[offset % ySeeds.count])
    }

    private func bubbleWidth(_ entry: CabinEntry) -> CGFloat {
        switch entry.kind {
        case .text:
            return 150
        case .drawing:
            return 132
        case .music:
            return 148
        }
    }
}

private struct PersonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.addEllipse(in: CGRect(x: midX - 8, y: rect.minY, width: 16, height: 18))
        path.move(to: CGPoint(x: midX, y: rect.minY + 19))
        path.addQuadCurve(to: CGPoint(x: midX - 10, y: rect.maxY - 22), control: CGPoint(x: rect.minX + 3, y: rect.midY))
        path.move(to: CGPoint(x: midX, y: rect.minY + 19))
        path.addQuadCurve(to: CGPoint(x: midX + 12, y: rect.maxY - 25), control: CGPoint(x: rect.maxX - 3, y: rect.midY + 6))
        path.move(to: CGPoint(x: midX - 4, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.midY + 22))
        path.move(to: CGPoint(x: midX + 5, y: rect.midY + 4))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.midY + 24))
        return path
    }
}

private struct EntryBubble: View {
    let entry: CabinEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch entry.kind {
            case .text:
                Text(entry.text)
                    .font(.system(size: 14, design: .serif))
            case .drawing:
                MiniDrawing(strokes: entry.drawing)
                    .frame(height: 70)
            case .music:
                Text("《\(entry.songTitle ?? "")》")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                Text(entry.text)
                    .font(.system(size: 12, design: .serif))
            }
        }
        .foregroundStyle(entry.kind == .music ? SardineColors.paperRaised : SardineColors.ink)
        .padding(10)
        .background(entry.kind == .music ? SardineColors.ink.opacity(0.82) : SardineColors.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(SardineColors.hairline.opacity(entry.kind == .music ? 0 : 1), lineWidth: 1))
        .shadow(color: SardineColors.softShadow, radius: 8, y: 4)
    }
}

private struct MiniDrawing: View {
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
                context.stroke(path, with: .color(SardineColors.ink.opacity(0.75)), style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
            }
        }
        .background(SardineColors.paperRaised)
    }
}

private struct FloatingModifier: ViewModifier {
    let delay: Double
    @State private var floating = false

    func body(content: Content) -> some View {
        content
            .offset(y: floating ? -4 : 4)
            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(delay), value: floating)
            .onAppear {
                floating = true
            }
    }
}

private extension View {
    func floating(delay: Double) -> some View {
        modifier(FloatingModifier(delay: delay))
    }
}
