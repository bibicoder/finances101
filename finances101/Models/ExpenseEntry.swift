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
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var title: String = ""
    var amount: Decimal = 0
    var dueDate: Date = Date()
    var category: String = "General"
    var type: ExpenseType = ExpenseType.optional
    var status: ExpenseStatus = ExpenseStatus.planned
    var note: String?
    var isRecurring: Bool = false
    var recurringTemplateId: UUID?
    var isDebtPayment: Bool = false
    var walletId: UUID?
    var externalId: String?   // e.g. Plaid transaction_id — used to skip duplicate imports
    var createdAt: Date = Date()

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
        isDebtPayment: Bool = false,
        walletId: UUID? = nil,
        externalId: String? = nil
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
        self.walletId = walletId
        self.externalId = externalId
        self.createdAt = Date()
    }
}
