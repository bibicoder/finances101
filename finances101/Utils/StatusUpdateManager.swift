import Foundation
import SwiftData

final class StatusUpdateManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func updateOverdueStatuses() {
        let today = Calendar.current.startOfDay(for: Date())

        let incomeDescriptor = FetchDescriptor<IncomeEntry>()
        if let incomes = try? modelContext.fetch(incomeDescriptor) {
            for income in incomes {
                let payoutDay = Calendar.current.startOfDay(for: income.payoutDate)
                // Only auto-mark as paid if actively expected (not if manually set to delayed/cancelled)
                if income.status == .planned || income.status == .earned {
                    if payoutDay <= today {
                        income.status = .paid
                        CharityManager.createAccrualIfNeeded(for: income, in: modelContext)
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

        modelContext.saveWithLogging()
    }
}
