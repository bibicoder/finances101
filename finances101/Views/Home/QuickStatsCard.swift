import SwiftUI

struct QuickStatsCard: View {
    let title: String
    let amount: Decimal
    let symbol: String
    let color: Color
    let icon: String
    var isWide: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("\(symbol)\(amount.formatted())")
                .font(AppFonts.cardAmount())
                .fontWeight(.bold)
                .foregroundStyle(amount < 0 ? AppColors.expense : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            QuickStatsCard(
                title: "Safe to Spend",
                amount: 8200,
                symbol: "$",
                color: AppColors.income,
                icon: "checkmark.shield.fill"
            )
            
            QuickStatsCard(
                title: "Incoming",
                amount: 5000,
                symbol: "$",
                color: AppColors.income,
                icon: "arrow.down.circle.fill"
            )
        }
        
        HStack(spacing: 12) {
            QuickStatsCard(
                title: "Outflow",
                amount: 2500,
                symbol: "$",
                color: AppColors.expense,
                icon: "arrow.up.circle.fill"
            )
            
            QuickStatsCard(
                title: "Charity",
                amount: 375,
                symbol: "$",
                color: AppColors.charity,
                icon: "heart.fill"
            )
        }
    }
    .padding()
    .background(AppColors.background)
}
