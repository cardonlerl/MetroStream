import CoreMotion
import SwiftUI
import UIKit

struct CabinView: View {
    @Bindable var appState: AppState
    @State private var showingPublisher = false
    @State private var showingExitConfirm = false
    @State private var showingClosed = false
    @State private var remainingSeconds: Int
    @StateObject private var motionSensor = CabinMotionSensor()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(appState: AppState) {
        self.appState = appState
        let seconds = max(60, (appState.currentRoute?.estimatedMinutes ?? 1) * 60)
        _remainingSeconds = State(initialValue: seconds)
    }

    var body: some View {
        ZStack {
            CabinScene(motionVector: motionSensor.motionVector)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
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
        .onAppear {
            motionSensor.start()
        }
        .onDisappear {
            motionSensor.stop()
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

    private func closeCabin() {
        showingClosed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            appState.endRide()
        }
    }
}

private struct CabinScene: View {
    let motionVector: CGSize
    private let backgroundImage = CabinBackgroundResource.image(in: .main)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let backgroundImage {
                    let imageAspectRatio = backgroundImage.size.width / max(backgroundImage.size.height, 1)
                    let motionOffset = CabinSceneMetrics.motionOffset(
                        forMotionVector: motionVector,
                        frameSize: proxy.size,
                        imageAspectRatio: imageAspectRatio
                    )

                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(CabinSceneMetrics.backgroundScale)
                        .offset(motionOffset)
                        .accessibilityHidden(true)
                } else {
                    SardineColors.paper
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .background(SardineColors.paper)
    }
}

enum CabinBackgroundResource {
    private static let name = "CabinBackground"

    static func image(in bundle: Bundle) -> UIImage? {
        guard let url = bundle.url(forResource: name, withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct CabinSceneMetrics {
    static let passengerCount = 0
    static let backgroundVisibleFraction: CGFloat = 0.95
    static let backgroundScale: CGFloat = 1 / backgroundVisibleFraction
    static let sceneCornerRadius: CGFloat = 0
    static let sceneHorizontalPadding: CGFloat = 0
    static let motionFullTravelRadians: CGFloat = 1

    static func visibleBubbleCount(forEntryCount _: Int) -> Int {
        0
    }

    static func motionVector(forRoll roll: Double, pitch: Double) -> CGSize {
        CGSize(
            width: clampUnit(CGFloat(roll) / motionFullTravelRadians),
            height: clampUnit(CGFloat(-pitch) / motionFullTravelRadians)
        )
    }

    static func motionOffset(
        forRoll roll: Double,
        pitch: Double,
        frameSize: CGSize,
        imageAspectRatio: CGFloat
    ) -> CGSize {
        motionOffset(
            forMotionVector: motionVector(forRoll: roll, pitch: pitch),
            frameSize: frameSize,
            imageAspectRatio: imageAspectRatio
        )
    }

    static func motionOffset(
        forMotionVector motionVector: CGSize,
        frameSize: CGSize,
        imageAspectRatio: CGFloat
    ) -> CGSize {
        let limit = motionOffsetLimit(in: frameSize, imageAspectRatio: imageAspectRatio)
        return CGSize(
            width: clampUnit(motionVector.width) * limit.width,
            height: clampUnit(motionVector.height) * limit.height
        )
    }

    static func motionOffsetLimit(in frameSize: CGSize, imageAspectRatio: CGFloat) -> CGSize {
        let fillSize = scaledToFillSize(frameSize: frameSize, imageAspectRatio: imageAspectRatio)
        let scaledSize = CGSize(
            width: fillSize.width * backgroundScale,
            height: fillSize.height * backgroundScale
        )
        return CGSize(
            width: max(0, (scaledSize.width - frameSize.width) / 2),
            height: max(0, (scaledSize.height - frameSize.height) / 2)
        )
    }

    private static func scaledToFillSize(frameSize: CGSize, imageAspectRatio: CGFloat) -> CGSize {
        guard frameSize.width > 0, frameSize.height > 0, imageAspectRatio > 0 else {
            return .zero
        }

        let frameAspectRatio = frameSize.width / frameSize.height
        if imageAspectRatio > frameAspectRatio {
            return CGSize(width: frameSize.height * imageAspectRatio, height: frameSize.height)
        } else {
            return CGSize(width: frameSize.width, height: frameSize.width / imageAspectRatio)
        }
    }

    private static func clampUnit(_ value: CGFloat) -> CGFloat {
        min(max(value, -1), 1)
    }
}

@MainActor
private final class CabinMotionSensor: ObservableObject {
    @Published var motionVector: CGSize = .zero

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let motionVector = CabinSceneMetrics.motionVector(
                forRoll: motion.attitude.roll,
                pitch: motion.attitude.pitch
            )
            MainActor.assumeIsolated {
                self?.motionVector = motionVector
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        motionVector = .zero
    }
}
