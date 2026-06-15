import Foundation
import SwiftData

enum RecurringFrequency: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case custom = "Custom"
    
    var days: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .custom: return 0
        }
    }
}

enum RecurringType: String, Codable, CaseIterable {
    case income = "Income"
    case expense = "Expense"
}

@Model
final class RecurringTemplate {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var title: String = ""
    var amount: Decimal = 0
    var type: RecurringType = RecurringType.expense
    var frequency: RecurringFrequency = RecurringFrequency.monthly
    var customDays: Int?
    var category: String = "General"
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var lastGeneratedDate: Date?
    var note: String?
    var createdAt: Date = Date()
    
    var intervalDays: Int {
        if frequency == .custom {
            return customDays ?? 30
        }
        return frequency.days
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        type: RecurringType,
        frequency: RecurringFrequency = .monthly,
        customDays: Int? = nil,
        category: String = "General",
        startDate: Date = Date(),
        endDate: Date? = nil,
        isActive: Bool = true,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.type = type
        self.frequency = frequency
        self.customDays = customDays
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.lastGeneratedDate = nil
        self.note = note
        self.createdAt = Date()
    }
}
