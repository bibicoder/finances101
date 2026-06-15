import Foundation
import SwiftData

@Model
final class CharityPayment {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Decimal = 0
    var note: String?
    var createdAt: Date = Date()
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Decimal,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.note = note
        self.createdAt = Date()
    }
}
