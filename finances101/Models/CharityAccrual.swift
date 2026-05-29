import Foundation
import SwiftData

@Model
final class CharityAccrual {
    var id: UUID
    var date: Date
    var baseAmount: Decimal
    var percentage: Double
    var accruedAmount: Decimal
    var linkedIncomeId: UUID?
    var note: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        baseAmount: Decimal,
        percentage: Double,
        linkedIncomeId: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.baseAmount = baseAmount
        self.percentage = percentage
        self.accruedAmount = baseAmount * Decimal(percentage / 100.0)
        self.linkedIncomeId = linkedIncomeId
        self.note = note
        self.createdAt = Date()
    }
}
