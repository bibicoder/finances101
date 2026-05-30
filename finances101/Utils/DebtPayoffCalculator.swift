import Foundation

enum PayoffStrategy: String, CaseIterable {
    case snowball = "Snowball"
    case avalanche = "Avalanche"

    var subtitle: String {
        switch self {
        case .snowball:  return "Smallest balance first"
        case .avalanche: return "Highest interest first"
        }
    }
    var icon: String {
        switch self {
        case .snowball:  return "snowflake"
        case .avalanche: return "flame.fill"
        }
    }
}

struct PayoffResult {
    let id: UUID
    let creditor: String
    let order: Int
    let monthsToPayoff: Int
    let payoffDate: Date
    let totalInterestPaid: Double
}

struct PayoffSummary {
    let results: [PayoffResult]
    let totalMonths: Int
    let totalInterestPaid: Double
    let debtFreeDate: Date
}

enum DebtPayoffCalculator {
    // Returns nil if no active debts or extraMonthly <= 0 and no minimums
    static func calculate(debts: [Debt], extraMonthly: Double, strategy: PayoffStrategy) -> PayoffSummary? {
        var items = debts
            .filter { $0.remainingAmount > 0 }
            .map { debt -> WorkItem in
                WorkItem(
                    id: debt.id,
                    creditor: debt.creditor,
                    balance: NSDecimalNumber(decimal: debt.remainingAmount).doubleValue,
                    apr: debt.interestRate ?? 0,
                    minimum: debt.minimumPayment.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0
                )
            }

        guard !items.isEmpty else { return nil }

        // Sort by strategy
        switch strategy {
        case .snowball:
            items.sort { $0.balance < $1.balance }
        case .avalanche:
            items.sort { $0.apr > $1.apr }
        }

        var balances    = items.map { $0.balance }
        var interest    = [Double](repeating: 0, count: items.count)
        var paidOffAt   = [Int?](repeating: nil, count: items.count)
        var order       = 1

        let maxMonths = 600
        var month = 0

        while balances.contains(where: { $0 > 0.005 }), month < maxMonths {
            month += 1
            var extra = extraMonthly

            // 1. Accrue monthly interest and apply minimums on each debt
            for i in items.indices {
                guard balances[i] > 0.005 else { continue }
                let monthlyRate = items[i].apr / 100 / 12
                let accrued = balances[i] * monthlyRate
                interest[i] += accrued
                balances[i] += accrued

                let minPay = items[i].minimum > 0
                    ? min(items[i].minimum, balances[i])
                    : 0
                balances[i] = max(0, balances[i] - minPay)

                if balances[i] <= 0.005 {
                    balances[i] = 0
                    if paidOffAt[i] == nil {
                        paidOffAt[i] = month
                        // freed minimum rolls into extra next target
                        extra += items[i].minimum
                    }
                }
            }

            // 2. Apply extra to the first unpaid debt (in strategy order)
            for i in items.indices {
                guard balances[i] > 0.005, extra > 0.005 else { continue }
                let payment = min(extra, balances[i])
                balances[i] = max(0, balances[i] - payment)
                extra -= payment
                if balances[i] <= 0.005 {
                    balances[i] = 0
                    if paidOffAt[i] == nil {
                        paidOffAt[i] = month
                        extra += items[i].minimum
                    }
                }
                break
            }
        }

        // Assign payoff order based on when each debt was paid off
        let sortedByPayoff = paidOffAt.indices
            .compactMap { i -> (Int, Int)? in
                guard let m = paidOffAt[i] else { return nil }
                return (i, m)
            }
            .sorted { $0.1 < $1.1 }

        var orderMap = [Int: Int]()
        for (rank, (i, _)) in sortedByPayoff.enumerated() {
            orderMap[i] = rank + 1
        }

        let now = Date()
        let cal = Calendar.current
        let results = items.indices.map { i -> PayoffResult in
            let months = paidOffAt[i] ?? maxMonths
            let date = cal.date(byAdding: .month, value: months, to: now) ?? now
            return PayoffResult(
                id: items[i].id,
                creditor: items[i].creditor,
                order: orderMap[i] ?? i + 1,
                monthsToPayoff: months,
                payoffDate: date,
                totalInterestPaid: interest[i]
            )
        }.sorted { $0.order < $1.order }

        let totalMonths = paidOffAt.compactMap { $0 }.max() ?? maxMonths
        let debtFreeDate = cal.date(byAdding: .month, value: totalMonths, to: now) ?? now
        let totalInterest = interest.reduce(0, +)

        return PayoffSummary(
            results: results,
            totalMonths: totalMonths,
            totalInterestPaid: totalInterest,
            debtFreeDate: debtFreeDate
        )
    }

    private struct WorkItem {
        let id: UUID
        let creditor: String
        var balance: Double
        let apr: Double
        let minimum: Double
    }
}
