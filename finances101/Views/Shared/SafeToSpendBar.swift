import SwiftUI

/// HP-bar card for Safe to Spend.
/// ratio = safeToSpend / (safeToSpend + plannedOutflow), clamped 0…1.
struct SafeToSpendBar: View {
    let amount: Decimal
    let plannedOutflow: Decimal
    let symbol: String

    @State private var animatedRatio: Double = 0

    private var targetRatio: Double {
        let a = NSDecimalNumber(decimal: amount).doubleValue
        let o = NSDecimalNumber(decimal: plannedOutflow).doubleValue
        let total = a + o
        guard total > 0 else { return 0 }
        return max(0, min(1, a / total))
    }

    private var barColor: Color {
        if amount < 0 { return AppColors.expense }
        switch animatedRatio {
        case 0.5...: return AppColors.accent
        case 0.2...: return AppColors.warning
        default:     return AppColors.expense
        }
    }

    private var statusLabel: String {
        if amount < 0 { return "Overspent" }
        switch animatedRatio {
        case 0.5...: return "Looking good"
        case 0.2...: return "Getting tight"
        default:     return "Almost out"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(barColor.opacity(0.14))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(barColor)
                        )
                    Text("Safe to Spend")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(barColor.opacity(0.12))
                    .foregroundStyle(barColor)
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.3), value: statusLabel)
            }

            Text(formattedAmount)
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundStyle(amount < 0 ? AppColors.expense : AppColors.textPrimary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.divider)
                        .frame(height: 8)
                    if animatedRatio > 0 {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [barColor, barColor.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(6, geo.size.width * animatedRatio), height: 8)
                    }
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .appCard()
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.15).delay(0.2)) {
                animatedRatio = targetRatio
            }
        }
        .onChange(of: amount) { _, _ in
            withAnimation(.spring(duration: 0.5)) {
                animatedRatio = targetRatio
            }
        }
    }

    private var formattedAmount: String {
        let d = NSDecimalNumber(decimal: amount).doubleValue
        return "\(d < 0 ? "-" : "")\(symbol)\(Int(abs(d)).formatted())"
    }
}

#Preview {
    VStack(spacing: 16) {
        SafeToSpendBar(amount: 1200, plannedOutflow: 800, symbol: "$")
        SafeToSpendBar(amount: 200, plannedOutflow: 1800, symbol: "$")
        SafeToSpendBar(amount: -50, plannedOutflow: 500, symbol: "$")
    }
    .padding()
    .background(AppColors.background)
}
