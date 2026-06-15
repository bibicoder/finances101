import Foundation
import SwiftData

enum IncomeStatus: String, Codable, CaseIterable {
    case planned = "Planned"    // Expected, not yet received
    case earned = "Earned"      // Earned but not yet in bank
    case paid = "Paid"          // Received
    case delayed = "Delayed"    // Was expected, hasn't arrived yet
    case cancelled = "Cancelled" // Will not arrive

    var isCountedInBalance: Bool {
        self == .paid
    }

    var isUpcoming: Bool {
        self == .planned || self == .earned || self == .delayed
    }

    var statusColor: (bg: String, fg: String) {
        switch self {
        case .planned:   return ("DBEAFE", "1D4ED8")   // blue
        case .earned:    return ("D1FAE5", "065F46")   // green-light
        case .paid:      return ("BBF7D0", "14532D")   // green
        case .delayed:   return ("FEF9C3", "854D0E")   // yellow
        case .cancelled: return ("FEE2E2", "991B1B")   // red
        }
    }
}

@Model
final class IncomeEntry: Identifiable {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var title: String = ""
    var amount: Decimal = 0
    var earnedDate: Date = Date()
    var payoutDate: Date = Date()
    var status: IncomeStatus = IncomeStatus.earned
    var category: String = "General"
    var note: String?
    var isRecurring: Bool = false
    var recurringTemplateId: UUID?
    var walletId: UUID?
    var externalId: String?   // e.g. Plaid transaction_id — used to skip duplicate imports
    var createdAt: Date = Date()

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
        recurringTemplateId: UUID? = nil,
        walletId: UUID? = nil,
        externalId: String? = nil
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
        self.walletId = walletId
        self.externalId = externalId
        self.createdAt = Date()
    }
}
