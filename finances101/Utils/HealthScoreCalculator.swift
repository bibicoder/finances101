import Foundation
import SwiftUI
import SwiftData

struct HealthScore {
    let total: Int          // 0–100
    let savingsScore: Int   // 0–25
    let debtScore: Int      // 0–25
    let bufferScore: Int    // 0–25
    let charityScore: Int   // 0–25

    let savingsRate: Double
    let monthlyIncome: Decimal
    let monthlyExpenses: Decimal
    let totalDebt: Decimal
    let bufferMonths: Double
    let charityOwed: Decimal
    let charityEnabled: Bool

    var grade: String {
        switch total {
        case 85...100: return "Excellent"
        case 70..<85:  return "Good"
        case 50..<70:  return "Fair"
        case 30..<50:  return "Needs Work"
        default:       return "Critical"
        }
    }

    var gradeColor: Color {
        switch total {
        case 85...100: return AppColors.income
        case 70..<85:  return Color(hex: "5AC8FA")
        case 50..<70:  return Color.yellow
        case 30..<50:  return Color.orange
        default:       return AppColors.expense
        }
    }

    var tip: String {
        if savingsScore == min(savingsScore, debtScore, bufferScore, charityScore) {
            if savingsRate < 0 {
                return "You're spending more than you earn. Look for expenses to cut or sources of income to add."
            }
            return "Try to save at least 10% of income each month. Even small reductions in optional spending add up fast."
        }
        if debtScore == min(savingsScore, debtScore, bufferScore, charityScore) {
            return "High debt load is your biggest risk. Focus extra payments on your highest-interest debt first."
        }
        if bufferScore == min(savingsScore, debtScore, bufferScore, charityScore) {
            return "Build a 3-month emergency fund. This is your financial safety net against unexpected events."
        }
        if charityScore < 20 && charityEnabled {
            return "You have unpaid charity. Clearing it builds financial discipline and peace of mind."
        }
        return "Great shape! Keep your savings rate above 20% and maintain your emergency buffer."
    }
}

enum HealthScoreCalculator {
    static func calculate(modelContext: ModelContext) -> HealthScore {
        let incomeDesc   = FetchDescriptor<IncomeEntry>()
        let expenseDesc  = FetchDescriptor<ExpenseEntry>()
        let debtDesc     = FetchDescriptor<Debt>()
        let accrualDesc  = FetchDescriptor<CharityAccrual>()
        let paymentDesc  = FetchDescriptor<CharityPayment>()
        let settingsDesc = FetchDescriptor<AppSettings>()

        let incomes  = (try? modelContext.fetch(incomeDesc))   ?? []
        let expenses = (try? modelContext.fetch(expenseDesc))  ?? []
        let debts    = (try? modelContext.fetch(debtDesc))     ?? []
        let accruals = (try? modelContext.fetch(accrualDesc))  ?? []
        let payments = (try? modelContext.fetch(paymentDesc))  ?? []
        let settings = (try? modelContext.fetch(settingsDesc))?.first

        let now      = Date()
        let thirtyAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now

        // Monthly income (paid in last 30 days)
        let monthlyIncome = incomes
            .filter { $0.status == .paid && $0.payoutDate >= thirtyAgo && $0.payoutDate <= now }
            .reduce(Decimal(0)) { $0 + $1.amount }

        // Monthly expenses (paid in last 30 days, excluding debt payments)
        let monthlyExpenses = expenses
            .filter { $0.status == .paid && $0.dueDate >= thirtyAgo && $0.dueDate <= now && !$0.isDebtPayment }
            .reduce(Decimal(0)) { $0 + $1.amount }

        // Actual balance
        let initialBalance = settings?.initialBalance ?? 0
        let totalPaidIncome = incomes.filter { $0.status == .paid }.reduce(Decimal(0)) { $0 + $1.amount }
        let totalPaidExpenses = expenses.filter { $0.status == .paid }.reduce(Decimal(0)) { $0 + $1.amount }
        let charityPaid = payments.reduce(Decimal(0)) { $0 + $1.amount }
        let actualBalance = initialBalance + totalPaidIncome - totalPaidExpenses - charityPaid

        // Charity owed
        let charityAccrued = accruals.reduce(Decimal(0)) { $0 + $1.accruedAmount }
        let charityOwed = max(Decimal(0), charityAccrued - charityPaid)
        let charityEnabled = (settings?.charityPercentage ?? 0) > 0 || (settings?.charityFixedAmount ?? 0) > 0

        // Total debt
        let totalDebt = debts.reduce(Decimal(0)) { $0 + $1.remainingAmount }

        // Buffer months
        let bufferMonths: Double
        if monthlyExpenses > 0 {
            bufferMonths = Double(truncating: (actualBalance / monthlyExpenses) as NSDecimalNumber)
        } else {
            bufferMonths = actualBalance > 0 ? 6.0 : 0
        }

        // Savings rate
        let savingsRate: Double
        if monthlyIncome > 0 {
            let saved = monthlyIncome - monthlyExpenses
            savingsRate = Double(truncating: (saved / monthlyIncome * 100) as NSDecimalNumber)
        } else {
            savingsRate = 0
        }

        // --- Score calculation ---

        let savingsScore: Int
        switch savingsRate {
        case 20...:     savingsScore = 25
        case 10..<20:   savingsScore = 20
        case 5..<10:    savingsScore = 13
        case 1..<5:     savingsScore = 7
        case 0..<1:     savingsScore = 3
        default:        savingsScore = 0
        }

        let debtToIncome: Double = monthlyIncome > 0
            ? Double(truncating: (totalDebt / monthlyIncome) as NSDecimalNumber)
            : (totalDebt > 0 ? 99 : 0)
        let debtScore: Int
        switch debtToIncome {
        case 0:         debtScore = 25
        case 0..<1:     debtScore = 20
        case 1..<3:     debtScore = 15
        case 3..<6:     debtScore = 10
        case 6..<12:    debtScore = 5
        default:        debtScore = 0
        }

        let bufferScore: Int
        switch bufferMonths {
        case 6...:      bufferScore = 25
        case 3..<6:     bufferScore = 20
        case 2..<3:     bufferScore = 15
        case 1..<2:     bufferScore = 10
        case 0.5..<1:   bufferScore = 5
        default:        bufferScore = 0
        }

        let charityScore: Int
        if !charityEnabled {
            charityScore = 15  // neutral if charity not configured
        } else if charityOwed == 0 {
            charityScore = 25
        } else {
            let ratio: Double = monthlyIncome > 0
                ? Double(truncating: (charityOwed / monthlyIncome) as NSDecimalNumber)
                : 99
            switch ratio {
            case 0..<0.25: charityScore = 20
            case 0.25..<0.5: charityScore = 15
            case 0.5..<1:  charityScore = 10
            default:       charityScore = 3
            }
        }

        let total = min(100, savingsScore + debtScore + bufferScore + charityScore)

        return HealthScore(
            total: total,
            savingsScore: savingsScore,
            debtScore: debtScore,
            bufferScore: bufferScore,
            charityScore: charityScore,
            savingsRate: savingsRate,
            monthlyIncome: monthlyIncome,
            monthlyExpenses: monthlyExpenses,
            totalDebt: totalDebt,
            bufferMonths: bufferMonths,
            charityOwed: charityOwed,
            charityEnabled: charityEnabled
        )
    }
}
