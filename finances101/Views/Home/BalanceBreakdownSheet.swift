import SwiftUI
import SwiftData

struct BalanceBreakdownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]
    @Query private var incomes: [IncomeEntry]
    @Query private var expenses: [ExpenseEntry]
    @Query private var transfers: [WalletTransfer]
    @State private var plaidManager = PlaidManager.shared
    let balanceData: BalanceData
    let symbol: String

    private var syncedBanks: [PlaidConnection] {
        plaidManager.connections.filter { $0.syncedAt != nil }
    }

    private var hasPlaidData: Bool { !syncedBanks.isEmpty }

    private var reservedAmount: Decimal {
        balanceData.weekPlanned
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    totalSection
                    if !wallets.isEmpty { walletsSection }
                    if hasPlaidData { bankAccountsSection }
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
    
    // Where the money lies — one row per wallet
    private var walletsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wallets")
                .font(.headline)

            ForEach(wallets) { wallet in
                let balance = WalletBalanceCalculator.balance(
                    of: wallet, incomes: incomes, expenses: expenses, transfers: transfers
                )
                let isSavings = wallet.type == .savings || wallet.type == .investment || wallet.type == .crypto
                BreakdownRow(
                    title: wallet.name,
                    subtitle: wallet.type.rawValue,
                    amount: balance,
                    symbol: symbol,
                    icon: wallet.iconName,
                    color: isSavings ? AppColors.savings : Color(hex: wallet.colorHex)
                )
            }
        }
        .padding()
        .appCard()
    }

    private var bankAccountsSection: some View {
        let totalCredit = plaidManager.totalCredit
        return VStack(alignment: .leading, spacing: 16) {
            Text("Banks")
                .font(.headline)

            // One row per linked bank, by its name/nickname
            ForEach(syncedBanks) { bank in
                BreakdownRow(
                    title: bank.displayName,
                    subtitle: bank.syncedAt.map { "Available · synced \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Available",
                    amount: bank.cashBalance ?? 0,
                    symbol: symbol,
                    icon: "building.columns.fill",
                    color: AppColors.income
                )
            }

            if totalCredit > 0 {
                Divider()
                BreakdownRow(
                    title: "Credit Card Debt",
                    subtitle: "Owed across all banks — not part of cash",
                    amount: totalCredit,
                    symbol: symbol,
                    icon: "creditcard.fill",
                    color: AppColors.expense
                )
            }
        }
        .padding()
        .appCard()
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breakdown")
                .font(.headline)
            
            BreakdownRow(
                title: "Planned This Week",
                subtitle: "Unpaid plans due by end of week",
                amount: reservedAmount,
                symbol: symbol,
                icon: "lock.fill",
                color: AppColors.expense
            )

            if balanceData.savingsSetAside > 0 {
                BreakdownRow(
                    title: "Set Aside",
                    subtitle: "Savings & investment wallets",
                    amount: balanceData.savingsSetAside,
                    symbol: symbol,
                    icon: "banknote.fill",
                    color: AppColors.savings
                )
            }

            Divider()
            
            BreakdownRow(
                title: "Safe to Spend",
                subtitle: "Balance − this week's plans",
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
