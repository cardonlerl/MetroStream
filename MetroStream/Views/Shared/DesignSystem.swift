import SwiftUI

enum SardineColors {
    static let paper = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let paperRaised = Color(red: 1.0, green: 0.98, blue: 0.93)
    static let ink = Color(red: 0.16, green: 0.14, blue: 0.12)
    static let mutedInk = Color(red: 0.48, green: 0.42, blue: 0.34)
    static let lineRed = Color(red: 0.77, green: 0.35, blue: 0.28)
    static let lineGreen = Color(red: 0.42, green: 0.58, blue: 0.36)
    static let lineBlue = Color(red: 0.36, green: 0.52, blue: 0.67)
    static let lineGold = Color(red: 0.72, green: 0.58, blue: 0.32)
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
