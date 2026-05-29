import Foundation
import SwiftData

struct BalanceData {
    let actualBalance: Decimal
    let safeToSpend: Decimal
    let charityOwed: Decimal
    let incomingSoon: Decimal
    let plannedOutflow: Decimal
}

final class BalanceCalculator {
    private let modelContext: ModelContext
    private var cachedIncomes: [IncomeEntry]?
    private var cachedExpenses: [ExpenseEntry]?
    private var cachedAccruals: [CharityAccrual]?
    private var cachedPayments: [CharityPayment]?
    private var cachedSettings: AppSettings?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadData()
    }
    
    private func loadData() {
        let incomeDescriptor = FetchDescriptor<IncomeEntry>()
        cachedIncomes = try? modelContext.fetch(incomeDescriptor)
        
        let expenseDescriptor = FetchDescriptor<ExpenseEntry>()
        cachedExpenses = try? modelContext.fetch(expenseDescriptor)
        
        let accrualDescriptor = FetchDescriptor<CharityAccrual>()
        cachedAccruals = try? modelContext.fetch(accrualDescriptor)
        
        let paymentDescriptor = FetchDescriptor<CharityPayment>()
        cachedPayments = try? modelContext.fetch(paymentDescriptor)
        
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        cachedSettings = (try? modelContext.fetch(settingsDescriptor))?.first
    }
    
    func calculateAll() -> BalanceData {
        BalanceData(
            actualBalance: actualBalance(),
            safeToSpend: safeToSpend(),
            charityOwed: charityOwed(),
            incomingSoon: incomingSoon(),
            plannedOutflow: plannedOutflow()
        )
    }
    
    func actualBalance() -> Decimal {
        let initialBalance = cachedSettings?.initialBalance ?? 0
        let paidIncome = sumPaidIncome()
        let paidExpenses = sumPaidExpenses()
        let charityPaid = sumCharityPaid()
        return initialBalance + paidIncome - paidExpenses - charityPaid
    }
    
    func charityOwed() -> Decimal {
        sumCharityAccrued() - sumCharityPaid()
    }
    
    func safeToSpend(on date: Date = Date()) -> Decimal {
        let projected = projectedBalance(on: date)
        let charity = charityOwed()
        let mandatory = sumUpcomingMandatoryExpenses(before: date)
        return projected - charity - mandatory
    }
    
    func incomingSoon(days: Int = 30) -> Decimal {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return sumIncomingIncome(from: Date(), to: futureDate)
    }
    
    func plannedOutflow(days: Int = 30) -> Decimal {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return sumPlannedExpenses(from: Date(), to: futureDate)
    }
    
    private func projectedBalance(on date: Date) -> Decimal {
        actualBalance() + sumIncomingIncome(before: date) - sumPlannedExpenses(before: date)
    }
    
    private func sumPaidIncome() -> Decimal {
        let now = Date()
        return (cachedIncomes ?? [])
            .filter { $0.status == .paid && $0.payoutDate <= now }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func sumIncomingIncome(before date: Date) -> Decimal {
        let now = Date()
        return (cachedIncomes ?? [])
            .filter { ($0.status == .earned || $0.status == .planned) && $0.payoutDate <= date && $0.payoutDate > now }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func sumIncomingIncome(from startDate: Date, to endDate: Date) -> Decimal {
        (cachedIncomes ?? [])
            .filter { ($0.status == .earned || $0.status == .planned) && $0.payoutDate >= startDate && $0.payoutDate <= endDate }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func sumPaidExpenses() -> Decimal {
        let now = Date()
        return (cachedExpenses ?? [])
            .filter { $0.status == .paid && $0.dueDate <= now }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func sumPlannedExpenses(before date: Date) -> Decimal {
        let now = Date()
        return (cachedExpenses ?? [])
            .filter { $0.status == .planned && $0.dueDate <= date && $0.dueDate > now }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func sumPlannedExpenses(from startDate: Date, to endDate: Date) -> Decimal {
        (cachedExpenses ?? [])
            .filter { $0.status == .planned && $0.dueDate >= startDate && $0.dueDate <= endDate }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func sumUpcomingMandatoryExpenses(before date: Date) -> Decimal {
        (cachedExpenses ?? [])
            .filter { $0.status == .planned && $0.type == .mandatory && $0.dueDate <= date }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func sumCharityAccrued() -> Decimal {
        (cachedAccruals ?? []).reduce(0) { $0 + $1.accruedAmount }
    }
    
    private func sumCharityPaid() -> Decimal {
        (cachedPayments ?? []).reduce(0) { $0 + $1.amount }
    }
}
