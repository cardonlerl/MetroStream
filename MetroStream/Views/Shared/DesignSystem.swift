import SwiftUI

enum SardineColors {
    static let paper = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let historyBackground = Color(red: 246 / 255, green: 243 / 255, blue: 238 / 255)
    static let paperRaised = Color(red: 1.0, green: 0.98, blue: 0.93)
    static let ink = Color(red: 0.16, green: 0.14, blue: 0.12)
    static let mutedInk = Color(red: 0.48, green: 0.42, blue: 0.34)
    static let lineRed = Color(red: 0.77, green: 0.35, blue: 0.28)
    static let lineGreen = Color(red: 0.42, green: 0.58, blue: 0.36)
    static let lineBlue = Color(red: 0.36, green: 0.52, blue: 0.67)
    static let lineGold = Color(red: 0.72, green: 0.58, blue: 0.32)
    static let hairline = Color(red: 0.82, green: 0.76, blue: 0.66)
    static let softShadow = Color(red: 0.34, green: 0.26, blue: 0.16).opacity(0.12)
}

struct PrimaryPaperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium, design: .serif))
            .foregroundStyle(SardineColors.paperRaised)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(SardineColors.ink.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(Capsule())
    }
}

struct IconCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(SardineColors.ink)
            .frame(width: 42, height: 42)
            .background(SardineColors.paperRaised.opacity(configuration.isPressed ? 0.65 : 0.95))
            .clipShape(Circle())
            .overlay(Circle().stroke(SardineColors.hairline, lineWidth: 1))
    }
}

struct TextChipStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .serif))
            .foregroundStyle(isSelected ? SardineColors.paperRaised : SardineColors.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? SardineColors.ink : SardineColors.paperRaised)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(SardineColors.hairline, lineWidth: isSelected ? 0 : 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = Int(cleaned, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
