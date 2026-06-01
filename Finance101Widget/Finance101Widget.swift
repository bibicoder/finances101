import WidgetKit
import SwiftUI

// MARK: - Shared keys (must match WidgetDataWriter in main app)
enum WidgetKeys {
    static let appGroupID = "group.com.finances101"
    static let balance = "widget_balance"
    static let safeToSpend = "widget_safe_to_spend"
    static let currencySymbol = "widget_currency_symbol"
    static let updatedAt = "widget_updated_at"
}

// MARK: - Entry

struct Finance101Entry: TimelineEntry {
    let date: Date
    let balance: Double
    let safeToSpend: Double
    let currencySymbol: String
}

// MARK: - Provider

struct Finance101Provider: TimelineProvider {
    func placeholder(in context: Context) -> Finance101Entry {
        Finance101Entry(date: Date(), balance: 2500, safeToSpend: 1800, currencySymbol: "$")
    }

    func getSnapshot(in context: Context, completion: @escaping (Finance101Entry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Finance101Entry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> Finance101Entry {
        let defaults = UserDefaults(suiteName: WidgetKeys.appGroupID)
        return Finance101Entry(
            date: Date(),
            balance: defaults?.double(forKey: WidgetKeys.balance) ?? 0,
            safeToSpend: defaults?.double(forKey: WidgetKeys.safeToSpend) ?? 0,
            currencySymbol: defaults?.string(forKey: WidgetKeys.currencySymbol) ?? "$"
        )
    }
}

// MARK: - Widget

@main
struct Finance101Widget: Widget {
    let kind = "Finance101Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Finance101Provider()) { entry in
            Finance101WidgetView(entry: entry)
        }
        .configurationDisplayName("Finance 101")
        .description("Balance and safe-to-spend at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
