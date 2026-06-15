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
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var initialBalance: Decimal = 0
    var charityPercentage: Double = 25.0
    var charityMode: CharityMode = CharityMode.percentage
    var charityFixedAmount: Decimal = 0
    var charityAccrualMode: CharityAccrualMode = CharityAccrualMode.onEarned
    var currency: String = "USD"
    var currencySymbol: String = "$"
    var defaultHorizonDays: Int = 30
    var plaidCashBalance: Decimal?        // sum of checking + savings from last Plaid sync
    var plaidCreditBalance: Decimal?     // sum of credit card balances from last Plaid sync
    var plaidSyncedAt: Date?             // timestamp of last successful Plaid balance sync
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// True when the current charity mode actually produces accruals.
    /// Gating UI on `charityPercentage > 0` alone hides charity for fixed-amount mode.
    var isCharityActive: Bool {
        switch charityMode {
        case .percentage:  return charityPercentage > 0
        case .fixedAmount: return charityFixedAmount > 0
        case .combined:    return charityPercentage > 0 || charityFixedAmount > 0
        }
    }

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
