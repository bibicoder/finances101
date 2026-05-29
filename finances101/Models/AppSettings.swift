import Foundation
import SwiftData

enum CharityAccrualMode: String, Codable, CaseIterable {
    case onEarned = "On Earned"
    case onPaid = "On Paid"
}

@Model
final class AppSettings {
    var id: UUID
    var initialBalance: Decimal
    var charityPercentage: Double
    var charityAccrualMode: CharityAccrualMode
    var currency: String
    var currencySymbol: String
    var defaultHorizonDays: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        initialBalance: Decimal = 0,
        charityPercentage: Double = 25.0,
        charityAccrualMode: CharityAccrualMode = .onEarned,
        currency: String = "USD",
        currencySymbol: String = "$",
        defaultHorizonDays: Int = 30
    ) {
        self.id = id
        self.initialBalance = initialBalance
        self.charityPercentage = charityPercentage
        self.charityAccrualMode = charityAccrualMode
        self.currency = currency
        self.currencySymbol = currencySymbol
        self.defaultHorizonDays = defaultHorizonDays
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
