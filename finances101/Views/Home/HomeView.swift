import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserRoleManager.self) private var roleManager
    @Query private var settings: [AppSettings]
    @Query(sort: \IncomeEntry.payoutDate) private var incomes: [IncomeEntry]
    @Query(sort: \ExpenseEntry.dueDate) private var expenses: [ExpenseEntry]
    
    @State private var showAddIncome = false
    @State private var showAddExpense = false
    @State private var showAddCharityPayment = false
    @State private var showBreakdown = false
    @State private var balanceData: BalanceData?
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    private var charityEnabled: Bool {
        (settings.first?.charityPercentage ?? 0) > 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    totalBalanceCard
                    quickStatsGrid
                    quickActionsSection
                    upcomingSection
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Dashboard")
            .onAppear { refreshBalances() }
            .onChange(of: incomes.count) { _, _ in refreshBalances() }
            .onChange(of: expenses.count) { _, _ in refreshBalances() }
            .sheet(isPresented: $showAddIncome) {
                AddIncomeSheet()
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseSheet()
            }
            .sheet(isPresented: $showAddCharityPayment) {
                AddCharityPaymentSheet()
            }
            .sheet(isPresented: $showBreakdown) {
                BalanceBreakdownSheet(
                    balanceData: balanceData ?? BalanceData(actualBalance: 0, safeToSpend: 0, charityOwed: 0, incomingSoon: 0, plannedOutflow: 0),
                    symbol: currencySymbol
                )
            }
        }
    }
    
    private func refreshBalances() {
        let calculator = BalanceCalculator(modelContext: modelContext)
        balanceData = calculator.calculateAll()
    }
    
    private var totalBalanceCard: some View {
        let data = balanceData ?? BalanceData(actualBalance: 0, safeToSpend: 0, charityOwed: 0, incomingSoon: 0, plannedOutflow: 0)
        
        return Button {
            showBreakdown = true
        } label: {
            VStack(spacing: 8) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("\(currencySymbol)\(data.actualBalance.formatted())")
                    .font(AppFonts.amount())
                    .foregroundStyle(data.actualBalance >= 0 ? AppColors.primaryDeep : AppColors.expense)
                
                HStack(spacing: 4) {
                    Text("Available now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                LinearGradient(
                    colors: [AppColors.primaryLight.opacity(0.1), AppColors.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .appCard()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.primaryLight.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var quickStatsGrid: some View {
        let data = balanceData ?? BalanceData(actualBalance: 0, safeToSpend: 0, charityOwed: 0, incomingSoon: 0, plannedOutflow: 0)
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                QuickStatsCard(
                    title: "Safe to Spend",
                    amount: data.safeToSpend,
                    symbol: currencySymbol,
                    color: data.safeToSpend >= 0 ? AppColors.income : AppColors.expense,
                    icon: "checkmark.shield.fill"
                )
                
                QuickStatsCard(
                    title: "Incoming",
                    amount: data.incomingSoon,
                    symbol: currencySymbol,
                    color: AppColors.income,
                    icon: "arrow.down.circle.fill"
                )
            }
            
            HStack(spacing: 12) {
                QuickStatsCard(
                    title: "Outflow",
                    amount: data.plannedOutflow,
                    symbol: currencySymbol,
                    color: AppColors.expense,
                    icon: "arrow.up.circle.fill"
                )
                
                if charityEnabled {
                    QuickStatsCard(
                        title: "Charity",
                        amount: data.charityOwed,
                        symbol: currencySymbol,
                        color: AppColors.charity,
                        icon: "heart.fill"
                    )
                } else {
                    QuickStatsCard(
                        title: "Net 30d",
                        amount: data.incomingSoon - data.plannedOutflow,
                        symbol: currencySymbol,
                        color: data.incomingSoon >= data.plannedOutflow ? AppColors.income : AppColors.expense,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        if roleManager.canEdit {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ActionButton(title: "Income", icon: "plus.circle.fill", color: AppColors.income) {
                        showAddIncome = true
                    }

                    ActionButton(title: "Expense", icon: "minus.circle.fill", color: AppColors.expense) {
                        showAddExpense = true
                    }

                    if charityEnabled {
                        ActionButton(title: "Charity", icon: "heart.circle.fill", color: AppColors.charity) {
                            showAddCharityPayment = true
                        }
                    }
                }
            }
        }
    }
    
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            let upcomingIncomes = incomes.filter { 
                $0.status != .paid && $0.payoutDate > Date() 
            }.prefix(3)
            
            let upcomingExpenses = expenses.filter { 
                $0.status == .planned && $0.dueDate > Date() 
            }.prefix(3)
            
            if upcomingIncomes.isEmpty && upcomingExpenses.isEmpty {
                ContentUnavailableView(
                    "No upcoming items",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("Add income or expenses to see them here")
                )
                .frame(height: 150)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(upcomingIncomes)) { income in
                        UpcomingItemRow(
                            title: income.title,
                            amount: income.amount,
                            date: income.payoutDate,
                            symbol: currencySymbol,
                            isIncome: true
                        )
                    }
                    
                    ForEach(Array(upcomingExpenses)) { expense in
                        UpcomingItemRow(
                            title: expense.title,
                            amount: expense.amount,
                            date: expense.dueDate,
                            symbol: currencySymbol,
                            isIncome: false
                        )
                    }
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct UpcomingItemRow: View {
    let title: String
    let amount: Decimal
    let date: Date
    let symbol: String
    let isIncome: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(isIncome ? AppColors.income : AppColors.expense)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(isIncome ? "+" : "-")\(symbol)\(amount.formatted())")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isIncome ? AppColors.income : AppColors.expense)
        }
        .padding()
        .appCard()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [
            IncomeEntry.self,
            ExpenseEntry.self,
            CharityAccrual.self,
            CharityPayment.self,
            AppSettings.self
        ], inMemory: true)
}
