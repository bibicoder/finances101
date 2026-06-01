import Foundation
import SwiftData

enum CharityAccrualMode: String, Codable, CaseIterable {
    case onEarned = "On Earned"
    case onPaid = "On Paid"
}

enum CharityMode: String, Codable, CaseIterable {
    case percentage = "Percentage"
    case fixedAmount = "Fixed Amount"
    case combined = "Combined"

    var displayName: String {
        switch self {
        case .percentage: return "% of Income"
        case .fixedAmount: return "Fixed Amount"
        case .combined: return "Combined (max)"
        }
    }
}

@Model
final class AppSettings {
    var id: UUID
    var initialBalance: Decimal
    var charityPercentage: Double
    var charityMode: CharityMode
    var charityFixedAmount: Decimal
    var charityAccrualMode: CharityAccrualMode
    var currency: String
    var currencySymbol: String
    var defaultHorizonDays: Int
    var plaidCashBalance: Decimal?        // sum of checking + savings from last Plaid sync
    var plaidCreditBalance: Decimal?     // sum of credit card balances from last Plaid sync
    var plaidSyncedAt: Date?             // timestamp of last successful Plaid balance sync
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        initialBalance: Decimal = 0,
        charityPercentage: Double = 25.0,
        charityMode: CharityMode = .percentage,
        charityFixedAmount: Decimal = 0,
        charityAccrualMode: CharityAccrualMode = .onEarned,
        currency: String = "USD",
        currencySymbol: String = "$",
        defaultHorizonDays: Int = 30
    ) {
        self.id = id
        self.initialBalance = initialBalance
        self.charityPercentage = charityPercentage
        self.charityMode = charityMode
        self.charityFixedAmount = charityFixedAmount
        self.charityAccrualMode = charityAccrualMode
        self.currency = currency
        self.currencySymbol = currencySymbol
        self.defaultHorizonDays = defaultHorizonDays
        self.plaidCashBalance = nil
        self.plaidCreditBalance = nil
        self.plaidSyncedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
