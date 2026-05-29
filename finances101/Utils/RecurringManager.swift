import Foundation
import SwiftData

final class RecurringManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func generateUpcomingRecurring(horizonDays: Int = 90) {
        let descriptor = FetchDescriptor<RecurringTemplate>()
        guard let templates = try? modelContext.fetch(descriptor) else { return }
        
        let activeTemplates = templates.filter { $0.isActive }
        let endDate = Calendar.current.date(byAdding: .day, value: horizonDays, to: Date()) ?? Date()
        
        for template in activeTemplates {
            generateFromTemplate(template, until: endDate)
        }
        
        try? modelContext.save()
    }
    
    private func generateFromTemplate(_ template: RecurringTemplate, until endDate: Date) {
        let calendar = Calendar.current
        var currentDate = template.lastGeneratedDate ?? template.startDate
        
        if currentDate < template.startDate {
            currentDate = template.startDate
        }
        
        while currentDate <= endDate {
            if let templateEndDate = template.endDate, currentDate > templateEndDate {
                break
            }
            
            if !entryExistsForDate(template: template, date: currentDate) {
                createEntry(from: template, on: currentDate)
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: template.intervalDays, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        template.lastGeneratedDate = currentDate
    }
    
    private func entryExistsForDate(template: RecurringTemplate, date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        switch template.type {
        case .income:
            let descriptor = FetchDescriptor<IncomeEntry>()
            guard let incomes = try? modelContext.fetch(descriptor) else { return false }
            return incomes.contains { income in
                income.recurringTemplateId == template.id &&
                income.payoutDate >= startOfDay &&
                income.payoutDate < endOfDay
            }
            
        case .expense:
            let descriptor = FetchDescriptor<ExpenseEntry>()
            guard let expenses = try? modelContext.fetch(descriptor) else { return false }
            return expenses.contains { expense in
                expense.recurringTemplateId == template.id &&
                expense.dueDate >= startOfDay &&
                expense.dueDate < endOfDay
            }
        }
    }
    
    private func createEntry(from template: RecurringTemplate, on date: Date) {
        switch template.type {
        case .income:
            let income = IncomeEntry(
                title: template.title,
                amount: template.amount,
                earnedDate: date,
                payoutDate: date,
                status: .planned,
                category: template.category,
                note: template.note,
                isRecurring: true,
                recurringTemplateId: template.id
            )
            modelContext.insert(income)
            
        case .expense:
            let expense = ExpenseEntry(
                title: template.title,
                amount: template.amount,
                dueDate: date,
                category: template.category,
                type: .recurring,
                status: .planned,
                note: template.note,
                isRecurring: true,
                recurringTemplateId: template.id
            )
            modelContext.insert(expense)
        }
    }
}
