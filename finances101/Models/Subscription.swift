import Foundation
import SwiftData

enum BillingCycle: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    var monthlyMultiplier: Decimal {
        switch self {
        case .weekly:    return Decimal(string: "4.33")!
        case .monthly:   return 1
        case .quarterly: return Decimal(string: "0.3333")!
        case .yearly:    return Decimal(string: "0.0833")!
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly:           return .weekOfYear
        case .monthly:          return .month
        case .quarterly, .yearly: return .month
        }
    }

    var calendarValue: Int {
        switch self {
        case .weekly:    return 1
        case .monthly:   return 1
        case .quarterly: return 3
        case .yearly:    return 12
        }
    }
}

@Model
final class Subscription {
    var id: UUID
    var name: String
    var amount: Decimal
    var billingCycle: BillingCycle
    var nextBillingDate: Date
    var category: String
    var icon: String
    var colorHex: String
    var isActive: Bool
    var notifyDaysBefore: Int
    var note: String?
    var createdAt: Date

    var monthlyAmount: Decimal {
        amount * billingCycle.monthlyMultiplier
    }

    var daysUntilBilling: Int {
        max(0, Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: nextBillingDate)
        ).day ?? 0)
    }

    func advanceBillingDate() {
        guard let next = Calendar.current.date(
            byAdding: billingCycle.calendarComponent,
            value: billingCycle.calendarValue,
            to: nextBillingDate
        ) else { return }
        nextBillingDate = next
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        billingCycle: BillingCycle = .monthly,
        nextBillingDate: Date = Date(),
        category: String = "Subscriptions",
        icon: String = "play.rectangle.fill",
        colorHex: String = "3FA7F5",
        isActive: Bool = true,
        notifyDaysBefore: Int = 3,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.billingCycle = billingCycle
        self.nextBillingDate = nextBillingDate
        self.category = category
        self.icon = icon
        self.colorHex = colorHex
        self.isActive = isActive
        self.notifyDaysBefore = notifyDaysBefore
        self.note = note
        self.createdAt = Date()
    }
}
