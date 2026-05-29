import Foundation
import SwiftData

enum IncomeStatus: String, Codable, CaseIterable {
    case planned = "Planned"
    case earned = "Earned"
    case paid = "Paid"
}

@Model
final class IncomeEntry: Identifiable {
    var id: UUID
    var title: String
    var amount: Decimal
    var earnedDate: Date
    var payoutDate: Date
    var status: IncomeStatus
    var category: String
    var note: String?
    var isRecurring: Bool
    var recurringTemplateId: UUID?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        earnedDate: Date = Date(),
        payoutDate: Date = Date(),
        status: IncomeStatus = .earned,
        category: String = "General",
        note: String? = nil,
        isRecurring: Bool = false,
        recurringTemplateId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.earnedDate = earnedDate
        self.payoutDate = payoutDate
        self.status = status
        self.category = category
        self.note = note
        self.isRecurring = isRecurring
        self.recurringTemplateId = recurringTemplateId
        self.createdAt = Date()
    }
}
