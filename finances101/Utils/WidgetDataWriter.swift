import WidgetKit
import Foundation

enum WidgetDataWriter {
    static let appGroupID = "group.com.finances101"

    static func update(balance: Decimal, safeToSpend: Decimal, currencySymbol: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(Double(truncating: balance as NSDecimalNumber), forKey: "widget_balance")
        defaults.set(Double(truncating: safeToSpend as NSDecimalNumber), forKey: "widget_safe_to_spend")
        defaults.set(currencySymbol, forKey: "widget_currency_symbol")
        defaults.set(Date(), forKey: "widget_updated_at")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
