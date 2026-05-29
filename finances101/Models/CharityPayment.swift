import Foundation
import SwiftData

@Model
final class CharityPayment {
    var id: UUID
    var date: Date
    var amount: Decimal
    var note: String?
    var createdAt: Date
    
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
