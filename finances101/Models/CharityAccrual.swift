import Foundation
import SwiftData

@Model
final class CharityAccrual {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var date: Date = Date()
    var baseAmount: Decimal = 0
    var percentage: Double = 0
    var accruedAmount: Decimal = 0
    var linkedIncomeId: UUID?
    var note: String?
    var createdAt: Date = Date()
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        baseAmount: Decimal,
        percentage: Double,
        accruedAmount: Decimal? = nil,
        linkedIncomeId: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.baseAmount = baseAmount
        self.percentage = percentage
        self.accruedAmount = accruedAmount ?? (baseAmount * Decimal(percentage) / 100)
        self.linkedIncomeId = linkedIncomeId
        self.note = note
        self.createdAt = Date()
    }
}
