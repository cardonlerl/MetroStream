import SwiftUI

enum DrawingPadMetrics {
    static let canvasHeight: CGFloat = 260
}

struct DrawingPad: View {
    @Binding var strokes: [DrawingStroke]
    @State private var currentStroke: DrawingStroke?
    @State private var erasing = false

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                Canvas { context, size in
                    let visibleStrokes = strokes + (currentStroke.map { [$0] } ?? [])
                    for stroke in visibleStrokes {
                        var path = Path()
                        for (index, point) in stroke.points.enumerated() {
                            let cgPoint = CGPoint(
                                x: size.width * point.x,
                                y: size.height * point.y
                            )
                            if index == 0 {
                                path.move(to: cgPoint)
                            } else {
                                path.addLine(to: cgPoint)
                            }
                        }
                        context.stroke(
                            path,
                            with: .color(stroke.isEraser ? SardineColors.paperRaised : SardineColors.ink.opacity(0.84)),
                            style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = MapPoint(
                                x: max(0, min(1, value.location.x / max(1, proxy.size.width))),
                                y: max(0, min(1, value.location.y / max(1, proxy.size.height)))
                            )
                            if currentStroke == nil {
                                currentStroke = DrawingStroke(points: [point], width: erasing ? 14 : 3, isEraser: erasing)
                            } else {
                                currentStroke?.points.append(point)
                            }
                        }
                        .onEnded { _ in
                            if let currentStroke {
                                strokes.append(currentStroke)
                            }
                            currentStroke = nil
                        }
                )
            }
            .frame(height: DrawingPadMetrics.canvasHeight)
            .background(SardineColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(SardineColors.hairline, lineWidth: 1))

            HStack {
                Button("笔") {
                    erasing = false
                }
                .buttonStyle(TextChipStyle(isSelected: !erasing))

                Button("擦") {
                    erasing = true
                }
                .buttonStyle(TextChipStyle(isSelected: erasing))

                Spacer()

                Button("清除") {
                    strokes.removeAll()
                }
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(SardineColors.mutedInk)
            }
        }
    }
}
