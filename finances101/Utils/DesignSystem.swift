import SwiftUI

// MARK: - Colors

enum AppColors {
    // Primary brand — Bold & Colorful
    static let primaryDeep    = Color(hex: "7C3AED")  // purple
    static let primaryLight   = Color(hex: "EDE9FE")  // light purple bg
    static let accent         = Color(hex: "84CC16")  // lime green

    // Semantic
    static let income         = Color(hex: "16A34A")
    static let expense        = Color(hex: "EF4444")
    static let charity        = Color(hex: "9333EA")
    static let savings        = Color(hex: "84CC16")
    static let warning        = Color(hex: "F59E0B")

    // Surfaces
    static let background     = Color(hex: "F8F7FF")
    static let surface        = Color.white
    static let cardBackground = Color.white

    // Text
    static let textPrimary    = Color(hex: "1F2937")
    static let textSecondary  = Color(hex: "6B7280")
    static let divider        = Color(hex: "F3F4F6")

    // Shadow
    static let cardShadow     = Color(hex: "7C3AED").opacity(0.08)

    // Gradients
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "7C3AED"), Color(hex: "5B21B6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let greenGradient = LinearGradient(
        colors: [Color(hex: "84CC16"), Color(hex: "65A30D")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func categoryBg(_ category: String) -> Color {
        switch category {
        case "Food", "Groceries", "Dining": return Color(hex: "FFF3E0")
        case "Transport", "Gas":            return Color(hex: "E0F2FE")
        case "Shopping", "Clothing":        return Color(hex: "FCE7F3")
        case "Health", "Medical":           return Color(hex: "DCFCE7")
        case "Entertainment":               return Color(hex: "EDE9FE")
        case "Income", "Salary":            return Color(hex: "DCFCE7")
        case "Charity":                     return Color(hex: "FEF9C3")
        case "Debt":                        return Color(hex: "FEE2E2")
        default:                            return Color(hex: "EDE9FE")
        }
    }
}

// MARK: - Typography

enum AppFonts {
    static func largeTitle() -> Font { .system(size: 34, weight: .heavy) }
    static func title() -> Font      { .system(size: 28, weight: .bold) }
    static func headline() -> Font   { .system(size: 17, weight: .semibold) }
    static func body() -> Font       { .system(size: 17, weight: .regular) }
    static func caption() -> Font    { .system(size: 12, weight: .regular) }
    static func amount() -> Font     { .system(size: 40, weight: .heavy).monospacedDigit() }
    static func cardAmount() -> Font { .system(size: 22, weight: .bold).monospacedDigit() }
}

// MARK: - Card modifier

struct AppCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: AppColors.cardShadow, radius: 14, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color(hex: "DDD6FE").opacity(0.7), lineWidth: 1)
            )
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.primaryDeep)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

extension View {
    func appCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(AppCardStyle(cornerRadius: cornerRadius))
    }

    func screenBackground() -> some View {
        background(AppColors.background.ignoresSafeArea())
    }
}

// MARK: - Reusable components

struct AppBadge: View {
    let text: String
    var color: Color = AppColors.primaryDeep
    var bgColor: Color = AppColors.primaryLight

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(bgColor)
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct AppProgressBar: View {
    let value: Double
    let total: Double
    var height: CGFloat = 8

    private var percent: Double { min(value / max(total, 1), 1.0) }
    private var isWarning: Bool { percent > 0.9 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "E4DAFF"))  // visible track on white
                Capsule()
                    .fill(isWarning
                        ? LinearGradient(colors: [AppColors.warning, AppColors.expense], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [AppColors.primaryDeep, Color(hex: "A78BFA")], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * percent)
            }
        }
        .frame(height: height)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
