import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserRoleManager.self) private var roleManager
    @Query private var settings: [AppSettings]
    @Query(sort: \IncomeEntry.payoutDate) private var incomes: [IncomeEntry]
    @Query(sort: \ExpenseEntry.dueDate) private var expenses: [ExpenseEntry]
    @Query private var debts: [Debt]
    @Query(sort: \CategoryBudget.category) private var budgets: [CategoryBudget]
    @Query private var subscriptions: [Subscription]
    @Query private var charityAccruals: [CharityAccrual]
    @Query private var charityPayments: [CharityPayment]
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]
    @Query private var walletTransfers: [WalletTransfer]
    @State private var plaidManager = PlaidManager.shared

    @State private var showAddIncome = false
    @State private var showAddExpense = false
    @State private var showAddCharityPayment = false
    @State private var showBreakdown = false
    @State private var showHealthScore = false
    @State private var balanceData: BalanceData?
    @State private var healthScore: HealthScore?
    @State private var insights: [FinancialInsight] = []
    @State private var confettiTrigger = 0

    private var currencySymbol: String { settings.first?.currencySymbol ?? "$" }
    private var charityEnabled: Bool { settings.first?.isCharityActive ?? false }

    // Includes amount/status sums so edits (not just inserts/deletes) trigger a refresh
    private var collectionVersion: String {
        let incomeSig  = incomes.reduce(into: Decimal(0))  { $0 += $1.amount }
        let expenseSig = expenses.reduce(into: Decimal(0)) { $0 += $1.amount }
        let paidCount  = incomes.filter { $0.status == .paid }.count + expenses.filter { $0.status == .paid }.count
        let walletSig  = wallets.reduce(into: Decimal(0)) { $0 += $1.initialBalance + ($1.cryptoBalanceUSD ?? 0) }
        let transferSig = walletTransfers.reduce(into: Decimal(0)) { $0 += $1.amount }
        let plaidSig = "\(settings.first?.plaidCashBalance ?? 0),\(settings.first?.plaidSyncedAt?.timeIntervalSince1970 ?? 0)"
        return "\(incomes.count),\(expenses.count),\(debts.count),\(budgets.count),\(subscriptions.count),\(charityAccruals.count),\(charityPayments.count),\(incomeSig),\(expenseSig),\(paidCount),\(settings.first?.initialBalance ?? 0),\(wallets.count),\(walletSig),\(walletTransfers.count),\(transferSig),\(plaidSig)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    greetingHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    heroBalanceCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    VStack(spacing: 16) {
                        quickStatsGrid
                        healthScoreCard
                        insightsSection
                        budgetPreview
                        upcomingSection
                        if roleManager.canEdit { quickActionsSection }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .screenBackground()
            .navigationBarHidden(true)
            .refreshable {
                // Pull-to-refresh: bank sync + on-chain crypto refresh, then recompute
                await PlaidSyncService.syncAll(modelContext: modelContext)
                await CryptoService.refreshAll(wallets)
                modelContext.saveWithLogging()
                refreshBalances()
            }
            .onAppear { refreshBalances() }
            .onChange(of: collectionVersion)  { _, _ in refreshBalances() }
            .onChange(of: incomes.count)      { old, new in if new > old { confettiTrigger += 1 } }
            .sheet(isPresented: $showAddIncome)          { AddIncomeSheet() }
            .sheet(isPresented: $showAddExpense)         { AddExpenseSheet() }
            .sheet(isPresented: $showAddCharityPayment)  { AddCharityPaymentSheet() }
            .sheet(isPresented: $showBreakdown) {
                BalanceBreakdownSheet(
                    balanceData: balanceData ?? BalanceData.empty,
                    symbol: currencySymbol
                )
            }
            .sheet(isPresented: $showHealthScore) {
                if let score = healthScore {
                    HealthScoreView(score: score, symbol: currencySymbol)
                }
            }
            .overlay { ConfettiView(trigger: $confettiTrigger) }
        }
    }

    // MARK: - Greeting

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Circle()
                .fill(AppColors.primaryLight)
                .frame(width: 42, height: 42)
                .overlay(
                    Text("👋")
                        .font(.system(size: 20))
                )
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    // MARK: - Hero Balance Card

    private var heroBalanceCard: some View {
        let data = balanceData ?? BalanceData.empty

        return Button { showBreakdown = true } label: {
            ZStack(alignment: .topTrailing) {
                // Decorative circle
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .offset(x: 30, y: -40)

                VStack(spacing: 0) {
                    Text("Total Balance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.bottom, 6)

                    AnimatedNumber(
                        value: data.actualBalance,
                        symbol: currencySymbol,
                        font: .system(size: 40, weight: .heavy).monospacedDigit(),
                        color: .white
                    )
                    .padding(.bottom, walletChipsVisible ? 10 : 20)

                    if walletChipsVisible {
                        walletChipsRow
                            .padding(.bottom, 16)
                    }

                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 8)

                    HStack(spacing: 10) {
                        HeroStat(label: "Received", value: data.weekIncome, symbol: currencySymbol, isPositive: true)
                        Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 36)
                        HeroStat(label: "Spent", value: data.weekSpent, symbol: currencySymbol, isPositive: false)
                        Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 36)
                        HeroStat(label: "Saved", value: data.weekSaved, symbol: currencySymbol, isPositive: nil)
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
            .background(AppColors.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: AppColors.primaryDeep.opacity(0.35), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    // Where the money lies: one chip per linked bank + one chip per wallet, on the hero card
    private var walletChipsVisible: Bool { !wallets.isEmpty || plaidManager.hasSyncedBalances }

    private var walletChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(plaidManager.connections.filter { $0.syncedAt != nil }) { bank in
                    let cash = bank.cashBalance ?? 0
                    MoneyChip(
                        icon: "building.columns.fill",
                        name: bank.displayName,
                        amount: cash,
                        symbol: currencySymbol
                    )
                }
                ForEach(wallets) { wallet in
                    let balance = WalletBalanceCalculator.balance(
                        of: wallet, incomes: incomes, expenses: expenses, transfers: walletTransfers
                    )
                    MoneyChip(
                        icon: wallet.iconName,
                        name: wallet.name,
                        amount: balance,
                        symbol: currencySymbol
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Quick Stats (2x2 grid)

    private var quickStatsGrid: some View {
        let data = balanceData ?? BalanceData.empty

        return VStack(spacing: 10) {
            SafeToSpendBar(
                amount: data.safeToSpend,
                plannedOutflow: data.weekPlanned,
                symbol: currencySymbol
            )
            HStack(spacing: 10) {
                QuickStatsCard(title: "Incoming", amount: data.incomingSoon, symbol: currencySymbol,
                               color: AppColors.income, icon: "arrow.down.circle.fill")
                QuickStatsCard(title: "Outflow", amount: data.plannedOutflow, symbol: currencySymbol,
                               color: AppColors.expense, icon: "arrow.up.circle.fill")
            }
            if data.savingsSetAside > 0 {
                QuickStatsCard(title: "Set Aside (Savings)", amount: data.savingsSetAside, symbol: currencySymbol,
                               color: AppColors.savings, icon: "lock.fill")
            }
            if charityEnabled {
                QuickStatsCard(title: "Charity", amount: data.charityOwed, symbol: currencySymbol,
                               color: AppColors.charity, icon: "heart.fill")
            }
        }
    }

    // MARK: - Health Score

    @ViewBuilder
    private var healthScoreCard: some View {
        if let score = healthScore {
            Button { showHealthScore = true } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(AppColors.divider, lineWidth: 5)
                            .frame(width: 56, height: 56)
                        Circle()
                            .trim(from: 0, to: CGFloat(score.total) / 100)
                            .stroke(AppColors.primaryDeep, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(-90))
                        Text("\(score.total)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(AppColors.primaryDeep)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Financial Health")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(score.grade)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    AppBadge(text: score.grade.uppercased())

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(16)
                .appCard()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Insights

    @ViewBuilder
    private var insightsSection: some View {
        if !insights.isEmpty {
            InsightCard(insights: insights)
        }
    }

    // MARK: - Budget Preview

    @ViewBuilder
    private var budgetPreview: some View {
        let activeBudgets: [CategoryBudget] = Array(budgets.prefix(3))
        if !activeBudgets.isEmpty {
            VStack(spacing: 12) {
                SectionHeader(title: "Budget 📊")
                VStack(spacing: 0) {
                    ForEach(activeBudgets) { budget in
                        let spent = budgetSpent(for: budget.category)
                        let pct = total(spent, budget.monthlyLimit)
                        BudgetRowItem(category: budget.category, spent: spent, limit: budget.monthlyLimit, percent: pct, symbol: currencySymbol)
                        if budget.id != activeBudgets.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(16)
                .appCard()
            }
        }
    }

    private func budgetSpent(for category: String) -> Decimal {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? now
        return expenses
            .filter { $0.category == category && $0.dueDate >= start && $0.dueDate < end && $0.status == .paid }
            .reduce(0) { $0 + $1.amount }
    }

    private func total(_ spent: Decimal, _ limit: Decimal) -> Double {
        guard limit > 0 else { return 0 }
        return min(Double(truncating: (spent / limit) as NSDecimalNumber), 1.0)
    }

    // MARK: - Upcoming

    private var upcomingSection: some View {
        let upcomingIncomes  = incomes.filter  { $0.status != .paid && $0.payoutDate > Date() }.prefix(3)
        let upcomingExpenses = expenses.filter { $0.status == .planned && $0.dueDate > Date() }.prefix(3)
        let hasItems = !upcomingIncomes.isEmpty || !upcomingExpenses.isEmpty

        return VStack(spacing: 12) {
            SectionHeader(title: "Upcoming 📅")

            if !hasItems {
                VStack(spacing: 8) {
                    Text("🗓")
                        .font(.system(size: 32))
                    Text("Nothing upcoming")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .appCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingIncomes)) { income in
                        UpcomingItemRow(title: income.title, amount: income.amount,
                                        date: income.payoutDate, symbol: currencySymbol, isIncome: true)
                        Divider().padding(.leading, 54)
                    }
                    ForEach(Array(upcomingExpenses)) { expense in
                        UpcomingItemRow(title: expense.title, amount: expense.amount,
                                        date: expense.dueDate, symbol: currencySymbol, isIncome: false)
                        if expense.id != upcomingExpenses.last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .padding(4)
                .appCard()
            }
        }
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Quick Add")
            HStack(spacing: 10) {
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

    // MARK: - Data

    private func refreshBalances() {
        let calculator = BalanceCalculator(
            incomes: incomes, expenses: expenses,
            accruals: charityAccruals, payments: charityPayments,
            settings: settings.first,
            wallets: wallets, transfers: walletTransfers
        )
        let data = calculator.calculateAll()
        balanceData = data
        WidgetDataWriter.update(
            balance: data.actualBalance,
            safeToSpend: data.safeToSpend,
            currencySymbol: currencySymbol
        )
        healthScore = HealthScoreCalculator.calculate(
            incomes: incomes, expenses: expenses, debts: debts,
            accruals: charityAccruals, payments: charityPayments,
            settings: settings.first, actualBalance: data.actualBalance
        )
        insights = FinancialInsightEngine.generate(
            incomes: incomes, expenses: expenses, debts: debts,
            budgets: budgets, subscriptions: subscriptions,
            charityOwed: data.charityOwed, symbol: currencySymbol
        )
    }
}

// MARK: - Money chip (bank / wallet) on the hero card

private struct MoneyChip: View {
    let icon: String
    let name: String
    let amount: Decimal
    let symbol: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Text("\(amount < 0 ? "-" : "")\(symbol)\(abs(amount).formatted())")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.white.opacity(0.14))
        .clipShape(Capsule())
    }
}

// MARK: - Hero Stat chip

private struct HeroStat: View {
    let label: String
    let value: Decimal
    let symbol: String
    let isPositive: Bool?

    private var textColor: Color {
        guard let pos = isPositive else {
            // Neutral stat (Saved): white when non-negative, red when in the hole
            return value < 0 ? Color(hex: "FCA5A5") : .white
        }
        return pos ? Color(hex: "86EFAC") : Color(hex: "FCA5A5")
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Text(formatted)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var formatted: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.currencySymbol = symbol
        f.maximumFractionDigits = 0
        let prefix = (isPositive == nil && value < 0) ? "-" : ""
        return prefix + (f.string(from: NSDecimalNumber(decimal: abs(value))) ?? symbol + "0")
    }
}

// MARK: - Budget Row

private struct BudgetRowItem: View {
    let category: String
    let spent: Decimal
    let limit: Decimal
    let percent: Double
    let symbol: String

    private var isWarning: Bool { percent > 0.9 }
    private let cat = CategoryManager.self

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.categoryBg(category))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: CategoryManager.expenseCategory(for: category).icon)
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.primaryDeep)
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(category)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text("\(symbol)\(spent.formatted()) / \(symbol)\(limit.formatted())")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(isWarning ? AppColors.warning : AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                AppProgressBar(value: Double(truncating: spent as NSDecimalNumber),
                               total: Double(truncating: limit as NSDecimalNumber))
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Action Button

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
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upcoming Row

struct UpcomingItemRow: View {
    let title: String
    let amount: Decimal
    let date: Date
    let symbol: String
    let isIncome: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(isIncome ? Color(hex: "DCFCE7") : Color(hex: "FEE2E2"))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isIncome ? AppColors.income : AppColors.expense)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(date, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Text("\(isIncome ? "+" : "-")\(symbol)\(amount.formatted())")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(isIncome ? AppColors.income : AppColors.expense)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - AppColors extension for tertiary text

private extension AppColors {
    static let textTertiary = Color(hex: "9CA3AF")
}

#Preview {
    HomeView()
        .modelContainer(for: [
            IncomeEntry.self, ExpenseEntry.self, CharityAccrual.self,
            CharityPayment.self, AppSettings.self, CategoryBudget.self,
            Debt.self, Subscription.self, RecurringTemplate.self
        ], inMemory: true)
        .environment(UserRoleManager())
}
