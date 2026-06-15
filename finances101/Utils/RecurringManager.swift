import Foundation
import SwiftData

final class RecurringManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func generateUpcomingRecurring(horizonDays: Int = 90) {
        guard let templates = try? modelContext.fetch(FetchDescriptor<RecurringTemplate>()) else { return }
        let activeTemplates = templates.filter { $0.isActive }
        guard !activeTemplates.isEmpty else { return }

        let endDate = Calendar.current.date(byAdding: .day, value: horizonDays, to: Date()) ?? Date()
        let allIncomes  = (try? modelContext.fetch(FetchDescriptor<IncomeEntry>())) ?? []
        let allExpenses = (try? modelContext.fetch(FetchDescriptor<ExpenseEntry>())) ?? []

        for template in activeTemplates {
            generateFromTemplate(template, until: endDate, allIncomes: allIncomes, allExpenses: allExpenses)
        }

        modelContext.saveWithLogging()
    }

    private func generateFromTemplate(_ template: RecurringTemplate, until endDate: Date, allIncomes: [IncomeEntry], allExpenses: [ExpenseEntry]) {
        let calendar = Calendar.current
        var currentDate = template.lastGeneratedDate ?? template.startDate

        if currentDate < template.startDate {
            currentDate = template.startDate
        }

        while currentDate <= endDate {
            if let templateEndDate = template.endDate, currentDate > templateEndDate { break }

            if !entryExistsForDate(template: template, date: currentDate, allIncomes: allIncomes, allExpenses: allExpenses) {
                createEntry(from: template, on: currentDate)
            }

            guard let nextDate = nextOccurrence(after: currentDate, template: template, calendar: calendar) else { break }
            currentDate = nextDate
        }

        template.lastGeneratedDate = currentDate
    }

    // Calendar-correct stepping: "monthly" means same day next month (Jan 1 → Feb 1),
    // not +30 days which drifts (Jan 1 → Jan 31 → Mar 2...).
    private func nextOccurrence(after date: Date, template: RecurringTemplate, calendar: Calendar) -> Date? {
        switch template.frequency {
        case .weekly:   return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly: return calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly:  return calendar.date(byAdding: .month, value: 1, to: date)
        case .custom:   return calendar.date(byAdding: .day, value: max(1, template.customDays ?? 30), to: date)
        }
    }

    private func entryExistsForDate(template: RecurringTemplate, date: Date, allIncomes: [IncomeEntry], allExpenses: [ExpenseEntry]) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay   = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        switch template.type {
        case .income:
            return allIncomes.contains {
                $0.recurringTemplateId == template.id &&
                $0.payoutDate >= startOfDay &&
                $0.payoutDate < endOfDay
            }
        case .expense:
            return allExpenses.contains {
                $0.recurringTemplateId == template.id &&
                $0.dueDate >= startOfDay &&
                $0.dueDate < endOfDay
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
