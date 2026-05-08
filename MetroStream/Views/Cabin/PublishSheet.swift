import SwiftUI

enum PublishMode: String, CaseIterable, Identifiable {
    case text = "字"
    case drawing = "画"
    case music = "歌"

    var id: String { rawValue }
}

struct PublishSheet: View {
    let routeKey: String
    let onPublish: (CabinEntry) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: PublishMode = .text
    @State private var text = ""
    @State private var songTitle = ""
    @State private var strokes: [DrawingStroke] = []
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 16) {
            modePicker

            Group {
                switch mode {
                case .text:
                    textEditor(placeholder: "此刻。")
                case .drawing:
                    DrawingPad(strokes: $strokes)
                case .music:
                    VStack(spacing: 10) {
                        TextField("歌名", text: $songTitle)
                            .textFieldStyle(PaperFieldStyle())
                        textEditor(placeholder: "一句话")
                    }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(SardineColors.mutedInk)
            }

            Button("投入") {
                publish()
            }
            .buttonStyle(PrimaryPaperButtonStyle())
        }
        .padding(18)
        .background(SardineColors.paper)
    }

    private var modePicker: some View {
        HStack(spacing: 10) {
            ForEach(PublishMode.allCases) { item in
                Button(item.rawValue) {
                    mode = item
                    errorText = nil
                }
                .buttonStyle(TextChipStyle(isSelected: mode == item))
            }
            Spacer()
        }
    }

    private func textEditor(placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(SardineColors.mutedInk.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }

            TextEditor(text: $text)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(SardineColors.ink)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 120)
                .background(Color.clear)
        }
        .background(SardineColors.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SardineColors.hairline, lineWidth: 1))
    }

    private func publish() {
        let trimmedText = String(text.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSong = songTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry: CabinEntry

        switch mode {
        case .text:
            guard !trimmedText.isEmpty else {
                errorText = "空的"
                return
            }
            entry = CabinEntry(kind: .text, text: trimmedText, routeKey: routeKey)
        case .drawing:
            guard !strokes.isEmpty else {
                errorText = "空的"
                return
            }
            entry = CabinEntry(kind: .drawing, text: "画", drawing: strokes, routeKey: routeKey)
        case .music:
            guard !trimmedSong.isEmpty, !trimmedText.isEmpty else {
                errorText = "空的"
                return
            }
            entry = CabinEntry(kind: .music, text: trimmedText, songTitle: trimmedSong, routeKey: routeKey)
        }

        do {
            try onPublish(entry)
            dismiss()
        } catch PublishError.limitReached {
            errorText = "最多三条"
        } catch {
            errorText = "空的"
        }
    }
}

private struct PaperFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16, design: .serif))
            .foregroundStyle(SardineColors.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(SardineColors.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(SardineColors.hairline, lineWidth: 1))
    }
}
