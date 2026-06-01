import SwiftUI

struct QuickStatsCard: View {
    let title: String
    let amount: Decimal
    let symbol: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(color)
                    )
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Text("\(symbol)\(amount.formatted())")
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundStyle(amount < 0 ? AppColors.expense : AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appCard()
    }
}

#Preview {
    VStack(spacing: 10) {
        HStack(spacing: 10) {
            QuickStatsCard(title: "Safe to Spend", amount: 8200, symbol: "$",
                           color: AppColors.income, icon: "checkmark.shield.fill")
            QuickStatsCard(title: "Incoming", amount: 5000, symbol: "$",
                           color: AppColors.income, icon: "arrow.down.circle.fill")
        }
        HStack(spacing: 10) {
            QuickStatsCard(title: "Outflow", amount: 2500, symbol: "$",
                           color: AppColors.expense, icon: "arrow.up.circle.fill")
            QuickStatsCard(title: "Charity", amount: 375, symbol: "$",
                           color: AppColors.charity, icon: "heart.fill")
        }
    }
    .padding()
    .screenBackground()
}
