import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @Query(sort: \ExpenseEntry.dueDate, order: .reverse) private var expenses: [ExpenseEntry]
    @Query(sort: \IncomeEntry.payoutDate, order: .reverse) private var incomes: [IncomeEntry]
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    savingsRateSection
                    TrendChartView(data: generateMonthlyTrends(), symbol: currencySymbol)
                    incomeVsSpendingSection
                    topCategoriesSection
                    futureProjectionSection
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Analytics")
        }
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
}

struct CategorySpendingRow: View {
    let category: String
    let amount: Decimal
    let percentage: Double
    let symbol: String
    
    var body: some View {
        let cat = CategoryManager.expenseCategory(for: category)
        
        HStack(spacing: 12) {
            Image(systemName: cat.icon)
                .font(.title3)
                .foregroundStyle(cat.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cat.color.opacity(0.3))
                        .frame(width: geometry.size.width * (percentage / 100), height: 4)
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(symbol)\(amount.formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(Int(percentage))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
