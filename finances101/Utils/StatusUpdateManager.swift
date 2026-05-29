import Foundation
import SwiftData

final class StatusUpdateManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func updateOverdueStatuses() {
        let today = Calendar.current.startOfDay(for: Date())
        
        let accrualDescriptor = FetchDescriptor<CharityAccrual>()
        let existingAccruals = (try? modelContext.fetch(accrualDescriptor)) ?? []
        let existingIncomeIds = Set(existingAccruals.compactMap { $0.linkedIncomeId })
        
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = try? modelContext.fetch(settingsDescriptor)
        let charityPercentage = settings?.first?.charityPercentage ?? 25.0
        
        let incomeDescriptor = FetchDescriptor<IncomeEntry>()
        if let incomes = try? modelContext.fetch(incomeDescriptor) {
            for income in incomes {
                let payoutDay = Calendar.current.startOfDay(for: income.payoutDate)
                if income.status != .paid && payoutDay <= today {
                    income.status = .paid
                    
                    if !existingIncomeIds.contains(income.id) {
                        let accrual = CharityAccrual(
                            date: income.payoutDate,
                            baseAmount: income.amount,
                            percentage: charityPercentage,
                            linkedIncomeId: income.id,
                            note: "From: \(income.title)"
                        )
                        modelContext.insert(accrual)
                    }
                }
            }
        }
        
        let expenseDescriptor = FetchDescriptor<ExpenseEntry>()
        if let expenses = try? modelContext.fetch(expenseDescriptor) {
            for expense in expenses {
                let dueDay = Calendar.current.startOfDay(for: expense.dueDate)
                if expense.status == .planned && dueDay <= today {
                    expense.status = .paid
                }
            }
        }
        
        try? modelContext.save()
    }
}
