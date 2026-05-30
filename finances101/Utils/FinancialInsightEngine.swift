import SwiftUI

struct FinancialInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let severity: Severity

    enum Severity: Int, Comparable {
        case info = 0, warning = 1, alert = 2

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

        var color: Color {
            switch self {
            case .info:    return AppColors.income
            case .warning: return .orange
            case .alert:   return AppColors.expense
            }
        }
    }
}

enum FinancialInsightEngine {

    static func generate(
        incomes: [IncomeEntry],
        expenses: [ExpenseEntry],
        debts: [Debt],
        budgets: [CategoryBudget],
        subscriptions: [Subscription],
        charityOwed: Decimal,
        symbol: String
    ) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        let calendar = Calendar.current
        let now = Date()

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth)
        else { return [] }

        let daysLeftInMonth = max(calendar.dateComponents([.day], from: now, to: monthEnd).day ?? 0, 0)

        let monthExpenses = expenses.filter {
            $0.status == .paid && !$0.isDebtPayment &&
            $0.dueDate >= monthStart && $0.dueDate < nextMonth
        }
        let monthIncomes = incomes.filter {
            $0.status == .paid &&
            $0.payoutDate >= monthStart && $0.payoutDate < nextMonth
        }

        let totalMonthExpense = monthExpenses.reduce(Decimal(0)) { $0 + $1.amount }
        let totalMonthIncome  = monthIncomes.reduce(Decimal(0)) { $0 + $1.amount }

        // MARK: Budget rules
        let spentByCategory: [String: Decimal] = monthExpenses.reduce(into: [:]) { dict, e in
            dict[e.category, default: 0] += e.amount
        }

        for budget in budgets.filter(\.isActive) {
            let spent = spentByCategory[budget.category] ?? 0
            guard budget.monthlyLimit > 0 else { continue }
            let pct = Double(truncating: (spent / budget.monthlyLimit * 100) as NSDecimalNumber)

            if spent > budget.monthlyLimit {
                insights.append(.init(
                    title: "\(budget.category) over budget",
                    message: "Spent \(symbol)\(spent.formatted(.number.precision(.fractionLength(0)))) vs \(symbol)\(budget.monthlyLimit.formatted(.number.precision(.fractionLength(0)))) limit.",
                    icon: "exclamationmark.triangle.fill",
                    severity: .alert
                ))
            } else if pct >= 80 && daysLeftInMonth > 5 {
                insights.append(.init(
                    title: "\(budget.category): \(Int(pct))% of budget used",
                    message: "\(daysLeftInMonth) days left — \(symbol)\(spent.formatted(.number.precision(.fractionLength(0)))) of \(symbol)\(budget.monthlyLimit.formatted(.number.precision(.fractionLength(0)))) spent.",
                    icon: "chart.bar.fill",
                    severity: .warning
                ))
            }
        }

        // MARK: Savings rate
        if totalMonthIncome > 0 {
            let savings = totalMonthIncome - totalMonthExpense
            let rate = Double(truncating: (savings / totalMonthIncome * 100) as NSDecimalNumber)

            if rate < 0 {
                insights.append(.init(
                    title: "Spending more than earning",
                    message: "You're \(symbol)\(abs(savings).formatted(.number.precision(.fractionLength(0)))) over income this month.",
                    icon: "exclamationmark.circle.fill",
                    severity: .alert
                ))
            } else if rate < 10 {
                insights.append(.init(
                    title: "Low savings rate: \(Int(rate))%",
                    message: "Aim for 20%+ of income saved. Review discretionary spending.",
                    icon: "chart.line.downtrend.xyaxis",
                    severity: .warning
                ))
            } else if rate >= 25 {
                insights.append(.init(
                    title: "Solid savings rate: \(Int(rate))%",
                    message: "You've saved \(symbol)\(savings.formatted(.number.precision(.fractionLength(0)))) this month. Keep it up!",
                    icon: "star.fill",
                    severity: .info
                ))
            }
        } else if calendar.component(.day, from: now) > 10 {
            insights.append(.init(
                title: "No income logged this month",
                message: "Mark income as received to keep your balance accurate.",
                icon: "calendar.badge.exclamationmark",
                severity: .info
            ))
        }

        // MARK: High APR debt
        let highAPRDebts = debts.filter { ($0.interestRate ?? 0) > 20 }
        if let worst = highAPRDebts.max(by: { ($0.interestRate ?? 0) < ($1.interestRate ?? 0) }) {
            let apr = String(format: "%.1f", worst.interestRate ?? 0)
            insights.append(.init(
                title: "High-interest debt: \(worst.creditor)",
                message: "\(apr)% APR is costing you money. Use the avalanche strategy to pay it first.",
                icon: "creditcard.trianglebadge.exclamationmark.fill",
                severity: .alert
            ))
        }

        // MARK: Subscriptions vs income
        let activeSubTotal = subscriptions.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.monthlyAmount }
        if activeSubTotal > 0 && totalMonthIncome > 0 {
            let subPct = Double(truncating: (activeSubTotal / totalMonthIncome * 100) as NSDecimalNumber)
            if subPct > 15 {
                insights.append(.init(
                    title: "Subscriptions: \(Int(subPct))% of income",
                    message: "\(symbol)\(activeSubTotal.formatted(.number.precision(.fractionLength(0))))/month in subscriptions. Review which ones you still use.",
                    icon: "repeat.circle.fill",
                    severity: .warning
                ))
            }
        }

        // MARK: Charity owed
        if charityOwed > 0 {
            insights.append(.init(
                title: "Charity pending: \(symbol)\(charityOwed.formatted(.number.precision(.fractionLength(0))))",
                message: "You have unpaid charity accrued. Head to the Charity tab to pay.",
                icon: "heart.circle.fill",
                severity: .info
            ))
        }

        // MARK: Weekly spending spike vs 3-week average
        let weekAgo      = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: now) ?? now

        let thisWeekSpend = expenses.filter {
            $0.status == .paid && !$0.isDebtPayment &&
            $0.dueDate >= weekAgo && $0.dueDate <= now
        }.reduce(Decimal(0)) { $0 + $1.amount }

        let priorThreeWeeksSpend = expenses.filter {
            $0.status == .paid && !$0.isDebtPayment &&
            $0.dueDate >= fourWeeksAgo && $0.dueDate < weekAgo
        }.reduce(Decimal(0)) { $0 + $1.amount }

        if priorThreeWeeksSpend > 0 {
            let avgWeekly = priorThreeWeeksSpend / 3
            if avgWeekly > 0 && thisWeekSpend > avgWeekly * 2 {
                let multiplier = Double(truncating: (thisWeekSpend / avgWeekly) as NSDecimalNumber)
                insights.append(.init(
                    title: "Spending spike this week",
                    message: "Spent \(symbol)\(thisWeekSpend.formatted(.number.precision(.fractionLength(0)))) — \(String(format: "%.1f", multiplier))x your weekly average.",
                    icon: "flame.fill",
                    severity: .warning
                ))
            }
        }

        return insights.sorted { $0.severity > $1.severity }
    }
}
