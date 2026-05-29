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
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    private var initialBalance: Decimal {
        settings.first?.initialBalance ?? 0
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
                    
                    BalanceChartView(
                        dataPoints: generateBalanceData(),
                        symbol: currencySymbol
                    )
                    
                    CategoryPieChart(
                        data: generateCategoryData(),
                        symbol: currencySymbol
                    )
                    
                    transactionsSection
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Spending")
        }
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
        let periodData = calculatePeriodData()
        
        return VStack(spacing: 12) {
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
            Text("Recent Transactions")
                .font(.headline)
            
            let filteredExpenses = filterExpenses()
            
            if filteredExpenses.isEmpty {
                Text("No transactions for this period")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(filteredExpenses.prefix(10)) { expense in
                    TransactionRow(expense: expense, symbol: currencySymbol)
                }
            }
        }
        .padding()
        .appCard()
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
        let today = Date()
        var dataPoints: [BalanceDataPoint] = []
        var runningBalance = initialBalance
        
        let allTransactions = getAllTransactionsSorted()
        
        let (periodStart, periodEnd) = getDateRange()
        let chartStart = calendar.date(byAdding: .day, value: -14, to: periodStart) ?? periodStart
        let chartEnd = calendar.date(byAdding: .day, value: 14, to: periodEnd) ?? periodEnd
        
        var currentDate = chartStart
        while currentDate <= chartEnd {
            let dayTransactions = allTransactions.filter {
                calendar.isDate($0.date, inSameDayAs: currentDate)
            }
            
            for transaction in dayTransactions {
                runningBalance += transaction.amount
            }
            
            let isPredicted = currentDate > today
            dataPoints.append(BalanceDataPoint(
                date: currentDate,
                balance: runningBalance,
                isPredicted: isPredicted
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dataPoints
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(symbol)\(amount.formatted())")
                .font(AppFonts.cardAmount())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCard()
    }
}

struct TransactionRow: View {
    let expense: ExpenseEntry
    let symbol: String
    
    var body: some View {
        HStack(spacing: 12) {
            let category = CategoryManager.expenseCategory(for: expense.category)
            
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(category.color)
                .frame(width: 36, height: 36)
                .background(category.color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(expense.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("-\(symbol)\(expense.amount.formatted())")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.expense)
        }
        .padding(.vertical, 4)
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
