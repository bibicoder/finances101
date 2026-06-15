import SwiftUI
import SwiftData
import Charts

enum TimePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct SpendingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query(sort: \ExpenseEntry.dueDate, order: .reverse) private var expenses: [ExpenseEntry]
    @Query(sort: \IncomeEntry.payoutDate, order: .reverse) private var incomes: [IncomeEntry]
    
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedMonth = Date()
    @State private var showBudget = false
    @State private var expandedWeeks: Set<Date> = [Calendar.current.startOfWeek(for: Date())]

    // Derived data is computed once into @State (on appear / data or period change),
    // not on every render — the daily balance loop + 7 SwiftData fetches were re-running
    // on every scroll frame.
    @State private var balancePoints: [BalanceDataPoint] = []
    @State private var categoryData: [CategoryData] = []
    @State private var periodData: (earnings: Decimal, spending: Decimal) = (0, 0)
    @State private var weeks: [WeekSpendingGroup] = []

    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }

    private var dataVersion: String {
        let paid = incomes.filter { $0.status == .paid }.count + expenses.filter { $0.status == .paid }.count
        let amt = expenses.reduce(into: Decimal(0)) { $0 += $1.amount }
        return "\(incomes.count),\(expenses.count),\(paid),\(amt),\(settings.first?.plaidCashBalance ?? 0)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodSelector

                    if selectedPeriod == .month {
                        monthSelector
                    }

                    metricsSection

                    BalanceChartView(dataPoints: balancePoints, symbol: currencySymbol)

                    CategoryPieChart(data: categoryData, symbol: currencySymbol)

                    transactionsSection
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Spending")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showBudget = true
                    } label: {
                        Label("Budget", systemImage: "chart.bar.fill")
                            .font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showBudget) {
                BudgetView()
            }
            .onAppear { recompute() }
            .onChange(of: dataVersion) { _, _ in recompute() }
            .onChange(of: selectedPeriod) { _, _ in recompute() }
            .onChange(of: selectedMonth) { _, _ in recompute() }
        }
    }

    private func recompute() {
        periodData = calculatePeriodData()
        balancePoints = generateBalanceData()
        categoryData = generateCategoryData()
        weeks = weekGroups()
    }
    
    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var monthSelector: some View {
        HStack {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(AppColors.primaryDeep)
            }
            
            Spacer()
            
            Text(selectedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
            
            Spacer()
            
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(AppColors.primaryDeep)
            }
        }
        .padding(.horizontal)
    }
    
    private var metricsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MetricCard(
                    title: "Earnings",
                    amount: periodData.earnings,
                    symbol: currencySymbol,
                    color: AppColors.income
                )
                
                MetricCard(
                    title: "Spending",
                    amount: periodData.spending,
                    symbol: currencySymbol,
                    color: AppColors.expense
                )
            }
            
            MetricCard(
                title: "Net Income",
                amount: periodData.earnings - periodData.spending,
                symbol: currencySymbol,
                color: periodData.earnings >= periodData.spending ? AppColors.income : AppColors.expense,
                isWide: true
            )
        }
    }
    
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transactions")
                .font(.headline)

            let groups = weeks

            if groups.isEmpty {
                Text("No transactions for this period")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(groups) { group in
                        weekRow(group)
                        if group.id != groups.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .appCard()
    }

    // MARK: - Week grouping

    private struct WeekSpendingGroup: Identifiable {
        let weekStart: Date
        let label: String
        let expenses: [ExpenseEntry]
        var id: Date { weekStart }
        var total: Decimal { expenses.reduce(0) { $0 + $1.amount } }
    }

    /// Past + current weeks of the selected period, newest first.
    private func weekGroups() -> [WeekSpendingGroup] {
        let cal = Calendar.current
        let currentWeekStart = cal.startOfWeek(for: Date())
        let byWeek = Dictionary(grouping: filterExpenses().filter { $0.dueDate <= Date() }) {
            cal.startOfWeek(for: $0.dueDate)
        }
        return byWeek.keys
            .filter { $0 <= currentWeekStart }
            .sorted(by: >)
            .map { start in
                let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
                return WeekSpendingGroup(
                    weekStart: start,
                    label: PlanWeek(startDate: start, endDate: end).label,
                    expenses: (byWeek[start] ?? []).sorted { $0.dueDate > $1.dueDate }
                )
            }
    }

    @ViewBuilder
    private func weekRow(_ group: WeekSpendingGroup) -> some View {
        let isExpanded = expandedWeeks.contains(group.weekStart)

        Button {
            HapticManager.selection()
            withAnimation(.snappy(duration: 0.25)) {
                if isExpanded {
                    expandedWeeks.remove(group.weekStart)
                } else {
                    expandedWeeks.insert(group.weekStart)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Text(group.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(group.expenses.count)")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(AppColors.divider.opacity(0.6))
                    .clipShape(Capsule())

                Spacer()

                Text("-\(currencySymbol)\(group.total.formatted())")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppColors.expense)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isExpanded {
            VStack(spacing: 0) {
                ForEach(group.expenses) { expense in
                    TransactionRow(expense: expense, symbol: currencySymbol)
                        .padding(.leading, 22)
                }
            }
            .padding(.bottom, 8)
            .transition(.opacity)
        }
    }


    private func calculatePeriodData() -> (earnings: Decimal, spending: Decimal) {
        let (startDate, endDate) = getDateRange()
        
        let earnings = incomes
            .filter { $0.payoutDate >= startDate && $0.payoutDate <= endDate && $0.status == .paid }
            .reduce(Decimal(0)) { $0 + $1.amount }
        
        let spending = expenses
            .filter { $0.dueDate >= startDate && $0.dueDate <= endDate && $0.status == .paid && !$0.isDebtPayment }
            .reduce(Decimal(0)) { $0 + $1.amount }
        
        return (earnings, spending)
    }
    
    private func filterExpenses() -> [ExpenseEntry] {
        let (startDate, endDate) = getDateRange()
        return expenses.filter { $0.dueDate >= startDate && $0.dueDate <= endDate && !$0.isDebtPayment }
    }
    
    private func getDateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let now = selectedMonth
        
        switch selectedPeriod {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? now
            return (start, end)
        case .year:
            let start = calendar.date(from: DateComponents(year: calendar.component(.year, from: now))) ?? now
            let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start) ?? now
            return (start, end)
        }
    }
    
    private func generateBalanceData() -> [BalanceDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let (periodStart, periodEnd) = getDateRange()
        let chartStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -14, to: periodStart) ?? periodStart)
        let chartEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 14, to: periodEnd) ?? periodEnd)

        // Bucket every transaction into its day once — O(n) — instead of scanning all
        // transactions for each day in the range (which was O(days × transactions)).
        var dailyDelta: [Date: Decimal] = [:]
        for tx in getAllTransactionsSorted() {
            let day = calendar.startOfDay(for: tx.date)
            dailyDelta[day, default: 0] += tx.amount
        }

        var dataPoints: [BalanceDataPoint] = []
        var runningBalance = Decimal(0)
        var todayBalance: Decimal = 0
        var currentDate = chartStart
        while currentDate <= chartEnd {
            runningBalance += dailyDelta[currentDate] ?? 0
            if currentDate == today { todayBalance = runningBalance }
            dataPoints.append(BalanceDataPoint(date: currentDate, balance: runningBalance, isPredicted: currentDate > today))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Anchor the curve so today equals the real balance (bank + wallets + crypto + cash),
        // instead of a ledger sum that starts from an arbitrary zero and drifts negative.
        let realToday = BalanceCalculator(modelContext: modelContext).actualBalance()
        let offset = realToday - todayBalance
        let anchored = dataPoints.map {
            BalanceDataPoint(date: $0.date, balance: $0.balance + offset, isPredicted: $0.isPredicted)
        }
        return downsample(anchored, maxPoints: 90)
    }

    /// Keep charts smooth on long ranges (Year ≈ 390 daily points) by thinning to
    /// at most `maxPoints`, always keeping the first and last point.
    private func downsample(_ points: [BalanceDataPoint], maxPoints: Int) -> [BalanceDataPoint] {
        guard points.count > maxPoints else { return points }
        let stride = Int((Double(points.count) / Double(maxPoints)).rounded(.up))
        var result = points.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
        if let last = points.last, result.last?.id != last.id { result.append(last) }
        return result
    }

    private func getAllTransactionsSorted() -> [(date: Date, amount: Decimal)] {
        var transactions: [(date: Date, amount: Decimal)] = []
        
        for income in incomes {
            transactions.append((date: income.payoutDate, amount: income.amount))
        }
        
        for expense in expenses {
            transactions.append((date: expense.dueDate, amount: -expense.amount))
        }
        
        return transactions.sorted { $0.date < $1.date }
    }
    
    private func generateCategoryData() -> [CategoryData] {
        let (startDate, endDate) = getDateRange()
        let periodExpenses = expenses.filter {
            $0.dueDate >= startDate && $0.dueDate <= endDate && $0.status == .paid
        }
        
        var categoryTotals: [String: Decimal] = [:]
        for expense in periodExpenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }
        
        return categoryTotals
            .sorted { $0.value > $1.value }
            .map { category, amount in
                let cat = CategoryManager.expenseCategory(for: category)
                return CategoryData(
                    category: category,
                    amount: amount,
                    color: cat.color,
                    icon: cat.icon
                )
            }
    }
}

struct MetricCard: View {
    let title: String
    let amount: Decimal
    let symbol: String
    let color: Color
    var isWide: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            Text("\(symbol)\(amount.formatted())")
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appCard()
    }
}

struct TransactionRow: View {
    let expense: ExpenseEntry
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            let category = CategoryManager.expenseCategory(for: expense.category)

            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.categoryBg(expense.category))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: category.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.primaryDeep)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(expense.dueDate, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Text("-\(symbol)\(expense.amount.formatted())")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(AppColors.expense)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    SpendingView()
        .modelContainer(for: [
            ExpenseEntry.self,
            IncomeEntry.self,
            AppSettings.self
        ], inMemory: true)
}
