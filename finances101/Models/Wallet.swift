import Foundation
import SwiftData
import SwiftUI

enum WalletType: String, Codable, CaseIterable {
    case cash = "Cash"
    case card = "Card"
    case savings = "Savings"
    case investment = "Investment"
    case other = "Other"

    var icon: String {
        switch self {
        case .cash:       return "banknote.fill"
        case .card:       return "creditcard.fill"
        case .savings:    return "building.columns.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .other:      return "wallet.pass.fill"
        }
    }
}

@Model
final class Wallet {
    var id: UUID
    var name: String
    var type: WalletType
    var initialBalance: Decimal
    var colorHex: String
    var isDefault: Bool
    var sortOrder: Int
    var createdAt: Date

    var iconName: String { type.icon }

    init(
        id: UUID = UUID(),
        name: String,
        type: WalletType = .card,
        initialBalance: Decimal = 0,
        colorHex: String = "7C3AED",
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.initialBalance = initialBalance
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

@Model
final class WalletTransfer {
    var id: UUID
    var fromWalletId: UUID
    var toWalletId: UUID
    var amount: Decimal
    var date: Date
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fromWalletId: UUID,
        toWalletId: UUID,
        amount: Decimal,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.fromWalletId = fromWalletId
        self.toWalletId = toWalletId
        self.amount = amount
        self.date = date
        self.note = note
        self.createdAt = Date()
    }
}
