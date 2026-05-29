import SwiftUI

struct BalanceBreakdownSheet: View {
    @Environment(\.dismiss) private var dismiss
    let balanceData: BalanceData
    let symbol: String
    
    private var reservedAmount: Decimal {
        balanceData.charityOwed + balanceData.plannedOutflow
    }
    
    private var availableAmount: Decimal {
        balanceData.actualBalance - reservedAmount
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    totalSection
                    breakdownSection
                    projectionSection
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Balance Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private var totalSection: some View {
        VStack(spacing: 8) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("\(symbol)\(balanceData.actualBalance.formatted())")
                .font(AppFonts.amount())
                .foregroundStyle(balanceData.actualBalance >= 0 ? AppColors.primaryDeep : AppColors.expense)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColors.primaryLight.opacity(0.1))
        .appCard()
    }
    
    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breakdown")
                .font(.headline)
            
            BreakdownRow(
                title: "Available",
                subtitle: "Free to use",
                amount: availableAmount,
                symbol: symbol,
                icon: "wallet.pass.fill",
                color: AppColors.income
            )
            
            BreakdownRow(
                title: "Reserved",
                subtitle: "Planned expenses + Charity",
                amount: reservedAmount,
                symbol: symbol,
                icon: "lock.fill",
                color: AppColors.expense
            )
            
            Divider()
            
            BreakdownRow(
                title: "Safe to Spend",
                subtitle: "After obligations",
                amount: balanceData.safeToSpend,
                symbol: symbol,
                icon: "checkmark.shield.fill",
                color: balanceData.safeToSpend >= 0 ? AppColors.income : AppColors.expense,
                isHighlighted: true
            )
        }
        .padding()
        .appCard()
    }
    
    private var projectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("30-Day Projection")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Incoming", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("+\(symbol)\(balanceData.incomingSoon.formatted())")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.income)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Label("Outflow", systemImage: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("-\(symbol)\(balanceData.plannedOutflow.formatted())")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.expense)
                }
            }
            
            Divider()
            
            let netChange = balanceData.incomingSoon - balanceData.plannedOutflow
            let projectedBalance = balanceData.actualBalance + netChange
            
            HStack {
                Text("Projected Balance")
                    .font(.subheadline)
                Spacer()
                Text("\(symbol)\(projectedBalance.formatted())")
                    .font(.headline)
                    .foregroundStyle(projectedBalance >= 0 ? AppColors.primaryDeep : AppColors.expense)
            }
        }
        .padding()
        .appCard()
    }
}

struct BreakdownRow: View {
    let title: String
    let subtitle: String
    let amount: Decimal
    let symbol: String
    let icon: String
    let color: Color
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isHighlighted ? .headline : .subheadline)
                    .fontWeight(isHighlighted ? .bold : .medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(symbol)\(amount.formatted())")
                .font(isHighlighted ? .title3 : .subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    BalanceBreakdownSheet(
        balanceData: BalanceData(
            actualBalance: 12450,
            safeToSpend: 8200,
            charityOwed: 375,
            incomingSoon: 5000,
            plannedOutflow: 2500
        ),
        symbol: "$"
    )
}
