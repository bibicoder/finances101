import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query(sort: \ExpenseEntry.dueDate, order: .reverse) private var expenses: [ExpenseEntry]
    @Query(sort: \IncomeEntry.payoutDate, order: .reverse) private var incomes: [IncomeEntry]
    @Query private var debts: [Debt]
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    netWorthSection
                    savingsRateSection
                    savingsForecastSection
                    yearOverYearSection
                    TrendChartView(data: generateMonthlyTrends(), symbol: currencySymbol)
                    incomeVsSpendingSection
                    topCategoriesSection
                    futureProjectionSection
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Analytics")
        }
    }
    
    // MARK: Net Worth

    private var totalDebt: Decimal {
        debts.reduce(Decimal(0)) { $0 + $1.remainingAmount }
    }

    private var currentBalance: Decimal {
        let initial = settings.first?.initialBalance ?? 0
        let paidIncome = incomes.filter { $0.status == .paid }.reduce(Decimal(0)) { $0 + $1.amount }
        let paidExpense = expenses.filter { $0.status == .paid }.reduce(Decimal(0)) { $0 + $1.amount }
        return initial + paidIncome - paidExpense
    }

    private var netWorth: Decimal { currentBalance - totalDebt }

    private var netWorthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Net Worth")
                .font(.headline)

            // Big number
            VStack(spacing: 4) {
                Text("\(netWorth >= 0 ? "" : "-")\(currencySymbol)\(abs(netWorth).formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(netWorth >= 0 ? AppColors.income : AppColors.expense)
                Text("Assets minus Liabilities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Assets vs Liabilities
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Assets", systemImage: "building.columns.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(max(currentBalance, 0).formatted(.number.precision(.fractionLength(0))))")
                        .font(.title3).fontWeight(.bold)
                        .foregroundStyle(AppColors.income)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Label("Liabilities", systemImage: "creditcard.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(totalDebt.formatted(.number.precision(.fractionLength(0))))")
                        .font(.title3).fontWeight(.bold)
                        .foregroundStyle(totalDebt > 0 ? AppColors.expense : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Split bar
            if currentBalance > 0 || totalDebt > 0 {
                let total = Double(truncating: (max(currentBalance, 0) + totalDebt) as NSDecimalNumber)
                let assetRatio = total > 0
                    ? Double(truncating: max(currentBalance, 0) as NSDecimalNumber) / total
                    : 0
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.income)
                            .frame(width: max(geo.size.width * assetRatio - 1, 0), height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.expense.opacity(0.7))
                            .frame(width: max(geo.size.width * (1 - assetRatio) - 1, 0), height: 10)
                    }
                }
                .frame(height: 10)
            }

            // 6-month chart
            if !netWorthHistory().isEmpty {
                Divider()
                Text("6-Month Trend")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(netWorthHistory()) { point in
                    LineMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Net Worth", Double(truncating: point.value as NSDecimalNumber))
                    )
                    .foregroundStyle(netWorth >= 0 ? AppColors.income : AppColors.expense)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Month", point.month, unit: .month),
                        y: .value("Net Worth", Double(truncating: point.value as NSDecimalNumber))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (netWorth >= 0 ? AppColors.income : AppColors.expense).opacity(0.25),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text("\(currencySymbol)\(Int(d / 1000))k")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .appCard()
    }

    private struct NetWorthPoint: Identifiable {
        let id = UUID()
        let month: Date
        let value: Decimal
    }

    private func netWorthHistory() -> [NetWorthPoint] {
        let calendar = Calendar.current
        let today = Date()
        var points: [NetWorthPoint] = []
        let initial = settings.first?.initialBalance ?? 0

        for offset in -5...0 {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: today),
                  let monthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate)
            else { continue }

            let cumulativeIncome = incomes
                .filter { $0.status == .paid && $0.payoutDate < nextMonth }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let cumulativeExpense = expenses
                .filter { $0.status == .paid && $0.dueDate < nextMonth }
                .reduce(Decimal(0)) { $0 + $1.amount }

            let balanceAtMonth = initial + cumulativeIncome - cumulativeExpense
            let nwAtMonth = balanceAtMonth - totalDebt
            points.append(NetWorthPoint(month: monthDate, value: nwAtMonth))
        }
        return points
    }

    private func generateMonthlyTrends() -> [MonthlyTrendData] {
        let calendar = Calendar.current
        let today = Date()
        var result: [MonthlyTrendData] = []
        
        for monthOffset in -5...0 {
            guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: today),
                  let monthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)) else {
                continue
            }
            
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate) ?? monthDate
            
            let monthIncome = incomes
                .filter { $0.payoutDate >= monthDate && $0.payoutDate < nextMonth && $0.status == .paid }
                .reduce(Decimal(0)) { $0 + $1.amount }
            
            let monthExpense = expenses
                .filter { $0.dueDate >= monthDate && $0.dueDate < nextMonth && $0.status == .paid && !$0.isDebtPayment }
                .reduce(Decimal(0)) { $0 + $1.amount }
            
            result.append(MonthlyTrendData(month: monthDate, income: monthIncome, expense: monthExpense))
        }
        
        return result
    }
    
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Spending Categories")
                .font(.headline)
            
            let categoryTotals = calculateCategoryTotals()
            
            if categoryTotals.isEmpty {
                Text("No spending data yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(categoryTotals.prefix(5), id: \.category) { item in
                    CategorySpendingRow(
                        category: item.category,
                        amount: item.amount,
                        percentage: item.percentage,
                        symbol: currencySymbol
                    )
                }
            }
        }
        .padding()
        .appCard()
    }
    
    private var incomeVsSpendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Spending")
                .font(.headline)
            
            let (totalIncome, totalExpense) = calculateTotals()
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(totalIncome.formatted())")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.income)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Spending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(totalExpense.formatted())")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.expense)
                }
            }
            
            let ratio = totalIncome > 0 ? Double(truncating: (totalExpense / totalIncome) as NSDecimalNumber) : 0
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.income.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.expense)
                        .frame(width: geometry.size.width * min(ratio, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .appCard()
    }
    
    private var savingsRateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Savings Rate")
                .font(.headline)
            
            let (totalIncome, totalExpense) = calculateTotals()
            let savings = totalIncome - totalExpense
            let rate = totalIncome > 0 ? Double(truncating: (savings / totalIncome * 100) as NSDecimalNumber) : 0
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're saving")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(rate))%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(rate >= 20 ? AppColors.income : AppColors.expense)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Saved Amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(currencySymbol)\(savings.formatted())")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(savings >= 0 ? AppColors.income : AppColors.expense)
                }
            }
        }
        .padding()
        .appCard()
    }
    
    private var futureProjectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("30-Day Projection")
                .font(.headline)
            
            let projection = calculateProjection()
            
            VStack(spacing: 16) {
                HStack {
                    Label("Expected Income", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("+\(currencySymbol)\(projection.income.formatted())")
                        .foregroundStyle(AppColors.income)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Label("Planned Expenses", systemImage: "arrow.up.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("-\(currencySymbol)\(projection.expenses.formatted())")
                        .foregroundStyle(AppColors.expense)
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                HStack {
                    Text("Projected Change")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    let change = projection.income - projection.expenses
                    Text("\(change >= 0 ? "+" : "")\(currencySymbol)\(change.formatted())")
                        .font(.headline)
                        .foregroundStyle(change >= 0 ? AppColors.income : AppColors.expense)
                }
            }
        }
        .padding()
        .appCard()
    }
    
    private func calculateCategoryTotals() -> [(category: String, amount: Decimal, percentage: Double)] {
        let paidExpenses = expenses.filter { $0.status == .paid && !$0.isDebtPayment }
        let total = paidExpenses.reduce(Decimal(0)) { $0 + $1.amount }
        
        guard total > 0 else { return [] }
        
        var categoryDict: [String: Decimal] = [:]
        for expense in paidExpenses {
            categoryDict[expense.category, default: 0] += expense.amount
        }
        
        return categoryDict
            .map { (category: $0.key, amount: $0.value, percentage: Double(truncating: ($0.value / total * 100) as NSDecimalNumber)) }
            .sorted { $0.amount > $1.amount }
    }
    
    private func calculateTotals() -> (income: Decimal, expense: Decimal) {
        let totalIncome = incomes
            .filter { $0.status == .paid }
            .reduce(Decimal(0)) { $0 + $1.amount }
        
        let totalExpense = expenses
            .filter { $0.status == .paid && !$0.isDebtPayment }
            .reduce(Decimal(0)) { $0 + $1.amount }
        
        return (totalIncome, totalExpense)
    }
    
    private func calculateProjection() -> (income: Decimal, expenses: Decimal) {
        let today = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today

        let projectedIncome = incomes
            .filter { $0.status != .paid && $0.payoutDate >= today && $0.payoutDate <= futureDate }
            .reduce(Decimal(0)) { $0 + $1.amount }

        let projectedExpenses = expenses
            .filter { $0.status == .planned && $0.dueDate >= today && $0.dueDate <= futureDate && !$0.isDebtPayment }
            .reduce(Decimal(0)) { $0 + $1.amount }

        return (projectedIncome, projectedExpenses)
    }

    // MARK: Year-over-Year

    private struct YoYMonth: Identifiable {
        let id = UUID()
        let month: Date
        let label: String
        let thisYear: Decimal
        let lastYear: Decimal
    }

    private func yoyData() -> [YoYMonth] {
        let calendar = Calendar.current
        let today = Date()
        var result: [YoYMonth] = []
        let df = DateFormatter()
        df.dateFormat = "MMM"

        for offset in 0..<6 {
            guard let thisMonthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: -offset, to: today) ?? today)
            ),
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMonthStart),
            let lastYearMonthStart = calendar.date(byAdding: .year, value: -1, to: thisMonthStart),
            let lastYearNextMonth = calendar.date(byAdding: .month, value: 1, to: lastYearMonthStart)
            else { continue }

            let thisExp = expenses
                .filter { $0.status == .paid && $0.dueDate >= thisMonthStart && $0.dueDate < nextMonth && !$0.isDebtPayment }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let lastExp = expenses
                .filter { $0.status == .paid && $0.dueDate >= lastYearMonthStart && $0.dueDate < lastYearNextMonth && !$0.isDebtPayment }
                .reduce(Decimal(0)) { $0 + $1.amount }

            result.append(YoYMonth(month: thisMonthStart, label: df.string(from: thisMonthStart), thisYear: thisExp, lastYear: lastExp))
        }
        return result.reversed()
    }

    private var yearOverYearSection: some View {
        let data = yoyData()
        let currentYear = Calendar.current.component(.year, from: Date())
        let hasData = data.contains { $0.thisYear > 0 || $0.lastYear > 0 }

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Year-over-Year")
                    .font(.headline)
                Spacer()
                Text("Spending comparison")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if !hasData {
                Text("Not enough data for year-over-year comparison yet.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(AppColors.primaryDeep).frame(width: 8, height: 8)
                        Text("\(currentYear)").font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(AppColors.primaryDeep.opacity(0.3)).frame(width: 8, height: 8)
                        Text("\(currentYear - 1)").font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                }

                let maxVal = data.flatMap { [$0.thisYear, $0.lastYear] }.max() ?? 1
                VStack(spacing: 8) {
                    ForEach(data) { item in
                        HStack(spacing: 8) {
                            Text(item.label)
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(width: 28, alignment: .leading)

                            GeometryReader { geo in
                                VStack(spacing: 3) {
                                    let thisRatio = maxVal > 0
                                        ? CGFloat(truncating: (item.thisYear / maxVal) as NSDecimalNumber)
                                        : 0
                                    let lastRatio = maxVal > 0
                                        ? CGFloat(truncating: (item.lastYear / maxVal) as NSDecimalNumber)
                                        : 0

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.primaryDeep)
                                        .frame(width: geo.size.width * thisRatio, height: 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.primaryDeep.opacity(0.3))
                                        .frame(width: geo.size.width * lastRatio, height: 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(height: 23)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(currencySymbol)\(item.thisYear.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(AppColors.textPrimary)
                                let delta = item.thisYear - item.lastYear
                                if item.lastYear > 0 {
                                    Text("\(delta > 0 ? "+" : "")\(Int(Double(truncating: (delta / item.lastYear * 100) as NSDecimalNumber)))%")
                                        .font(.caption2)
                                        .foregroundStyle(delta > 0 ? AppColors.expense : AppColors.income)
                                }
                            }
                            .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .appCard()
    }

    // MARK: Savings Forecast

    private struct ForecastPoint: Identifiable {
        let id = UUID()
        let label: String
        let months: Int
        let amount: Decimal
    }

    private func averageMonthlySavings() -> Decimal {
        let calendar = Calendar.current
        let today = Date()
        var totalSavings = Decimal(0)
        var monthsWithData = 0

        for offset in -2...0 {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: today),
                  let monthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthDate)
            else { continue }

            let monthIncome = incomes
                .filter { $0.status == .paid && $0.payoutDate >= monthDate && $0.payoutDate < nextMonth }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let monthExpense = expenses
                .filter { $0.status == .paid && $0.dueDate >= monthDate && $0.dueDate < nextMonth && !$0.isDebtPayment }
                .reduce(Decimal(0)) { $0 + $1.amount }

            if monthIncome > 0 || monthExpense > 0 {
                totalSavings += monthIncome - monthExpense
                monthsWithData += 1
            }
        }

        guard monthsWithData > 0 else { return 0 }
        return totalSavings / Decimal(monthsWithData)
    }

    private func forecastPoints() -> [ForecastPoint] {
        let avgMonthly = averageMonthlySavings()
        let base = currentBalance
        return [
            ForecastPoint(label: "3 mo", months: 3, amount: base + avgMonthly * 3),
            ForecastPoint(label: "6 mo", months: 6, amount: base + avgMonthly * 6),
            ForecastPoint(label: "12 mo", months: 12, amount: base + avgMonthly * 12),
        ]
    }

    private var savingsForecastSection: some View {
        let avgMonthly = averageMonthlySavings()
        let points = forecastPoints()
        let isPositive = avgMonthly >= 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Savings Forecast")
                    .font(.headline)
                Spacer()
                Label(
                    "\(isPositive ? "+" : "")\(currencySymbol)\(abs(avgMonthly).formatted(.number.precision(.fractionLength(0))))/mo",
                    systemImage: isPositive ? "arrow.up.right" : "arrow.down.right"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(isPositive ? AppColors.income : AppColors.expense)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isPositive ? AppColors.income : AppColors.expense).opacity(0.12))
                .clipShape(Capsule())
            }

            Text("Based on your avg. monthly savings over the last 3 months")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 12) {
                ForEach(points) { point in
                    VStack(spacing: 6) {
                        Text(point.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)

                        Text("\(point.amount >= 0 ? "" : "-")\(currencySymbol)\(abs(point.amount).formatted(.number.precision(.fractionLength(0))))")
                            .font(.system(size: 15, weight: .bold).monospacedDigit())
                            .foregroundStyle(point.amount >= 0 ? AppColors.textPrimary : AppColors.expense)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Capsule()
                            .fill(point.amount >= 0 ? AppColors.accent.opacity(0.25) : AppColors.expense.opacity(0.2))
                            .frame(height: 4)
                            .overlay(
                                GeometryReader { geo in
                                    let maxVal = points.map { abs($0.amount) }.max() ?? 1
                                    let ratio = maxVal > 0
                                        ? CGFloat(truncating: (abs(point.amount) / maxVal) as NSDecimalNumber)
                                        : 0
                                    Capsule()
                                        .fill(point.amount >= 0 ? AppColors.accent : AppColors.expense)
                                        .frame(width: geo.size.width * ratio)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(AppColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if avgMonthly == 0 {
                Text("Not enough paid transactions to generate a forecast yet.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .padding()
        .appCard()
    }
}

struct CategorySpendingRow: View {
    let category: String
    let amount: Decimal
    let percentage: Double
    let symbol: String

    var body: some View {
        let cat = CategoryManager.expenseCategory(for: category)

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.categoryBg(category))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: cat.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.primaryDeep)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.divider).frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(colors: [AppColors.primaryDeep, Color(hex: "A78BFA")],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * (percentage / 100), height: 5)
                    }
                }
                .frame(height: 5)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(symbol)\(amount.formatted())")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(Int(percentage))%")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [
            ExpenseEntry.self,
            IncomeEntry.self,
            AppSettings.self
        ], inMemory: true)
}
