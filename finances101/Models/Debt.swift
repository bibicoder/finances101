import Foundation
import SwiftData

@Model
final class Debt {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var creditor: String = ""
    var totalAmount: Decimal = 0
    var paidAmount: Decimal = 0
    var priority: Int = 1
    var targetDate: Date?
    var note: String?
    var createdAt: Date = Date()
    var interestRate: Double?    // APR %, e.g. 18.5 means 18.5%
    var minimumPayment: Decimal? // monthly minimum payment
    
    var remainingAmount: Decimal {
        totalAmount - paidAmount
    }
    
    var progressPercentage: Double {
        guard totalAmount > 0 else { return 0 }
        return Double(truncating: (paidAmount / totalAmount) as NSNumber) * 100
    }
    
    init(
        id: UUID = UUID(),
        creditor: String,
        totalAmount: Decimal,
        paidAmount: Decimal = 0,
        priority: Int = 1,
        targetDate: Date? = nil,
        note: String? = nil,
        interestRate: Double? = nil,
        minimumPayment: Decimal? = nil
    ) {
        self.id = id
        self.creditor = creditor
        self.totalAmount = totalAmount
        self.paidAmount = paidAmount
        self.priority = priority
        self.targetDate = targetDate
        self.note = note
        self.createdAt = Date()
        self.interestRate = interestRate
        self.minimumPayment = minimumPayment
    }
}
