import SwiftUI

enum AppColors {
    static let primaryDeep = Color(hex: "1C3D5A")
    static let primaryLight = Color(hex: "3FA7F5")
    static let accent = Color(hex: "6DD3CE")
    
    static let income = Color(hex: "34C759")
    static let expense = Color(hex: "FF6B6B")
    static let charity = Color(hex: "AF52DE")
    static let savings = Color(hex: "5AC8FA")
    static let investment = Color(hex: "FFD60A")
    
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let background = Color(.systemGroupedBackground)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum AppFonts {
    static func largeTitle() -> Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }
    
    static func title() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    
    static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .rounded)
    }
    
    static func body() -> Font {
        .system(size: 17, weight: .regular, design: .default)
    }
    
    static func caption() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }
    
    static func amount() -> Font {
        .system(size: 44, weight: .bold, design: .rounded)
    }
    
    static func cardAmount() -> Font {
        .system(size: 24, weight: .bold, design: .rounded)
    }
}

struct AppCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.primaryDeep)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension View {
    func appCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(AppCardStyle(cornerRadius: cornerRadius))
    }
}
