import Foundation
import SwiftData

enum ExpenseType: String, Codable, CaseIterable {
    case mandatory = "Mandatory"
    case optional = "Optional"
    case recurring = "Recurring"
}

enum ExpenseStatus: String, Codable, CaseIterable {
    case planned = "Planned"
    case paid = "Paid"
}

@Model
final class ExpenseEntry: Identifiable {
    var id: UUID
    var title: String
    var amount: Decimal
    var dueDate: Date
    var category: String
    var type: ExpenseType
    var status: ExpenseStatus
    var note: String?
    var isRecurring: Bool
    var recurringTemplateId: UUID?
    var isDebtPayment: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        dueDate: Date = Date(),
        category: String = "General",
        type: ExpenseType = .optional,
        status: ExpenseStatus = .planned,
        note: String? = nil,
        isRecurring: Bool = false,
        recurringTemplateId: UUID? = nil,
        isDebtPayment: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.category = category
        self.type = type
        self.status = status
        self.note = note
        self.isRecurring = isRecurring
        self.recurringTemplateId = recurringTemplateId
        self.isDebtPayment = isDebtPayment
        self.createdAt = Date()
    }
}
