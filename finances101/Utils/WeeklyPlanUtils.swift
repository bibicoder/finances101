import Foundation

// MARK: - Calendar Helpers

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

extension Date {
    var endOfDay: Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self) ?? self
    }
}

// MARK: - Plan Week

struct PlanWeek: Identifiable {
    let startDate: Date
    let endDate: Date

    // Stable identity: `weeks` is recomputed on every body evaluation, so a
    // random UUID here changes every render — SwiftUI then re-creates all week
    // cards on any tap and saved week ids never match (quick add breaks).
    var id: Date { startDate }

    var label: String {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        if startDate <= startOfToday && endDate >= startOfToday {
            return "This Week"
        }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        return "\(df.string(from: startDate)) – \(df.string(from: end))"
    }

    var shortLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: startDate)
    }

    var dateRangeLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        return "\(df.string(from: startDate)) – \(df.string(from: end))"
    }

    static func next6Weeks() -> [PlanWeek] {
        let cal = Calendar.current
        var result: [PlanWeek] = []
        var start = cal.startOfWeek(for: Date())
        for _ in 0..<6 {
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            result.append(PlanWeek(startDate: start, endDate: end))
            start = end
        }
        return result
    }

    func midpoint() -> Date {
        Calendar.current.date(byAdding: .day, value: 3, to: startDate) ?? startDate
    }
}

// MARK: - Quick Entry Parser (6.2)

enum QuickEntryResult {
    case expense(title: String, amount: Decimal, category: String)
    case income(title: String, amount: Decimal)
    case invalid
}

struct QuickEntryParser {
    private static let incomeKeywords = [
        "paycheck", "salary", "payroll", "freelance", "invoice",
        "deposit", "revenue", "bonus", "refund", "reimburs"
    ]

    static func parse(_ text: String) -> QuickEntryResult {
        let parts = text.trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return .invalid }

        var amountIndex: Int?
        var amount: Decimal?
        for (i, part) in parts.enumerated() {
            if let d = Decimal(userInput: part), d > 0 {
                amountIndex = i
                amount = d
                break
            }
        }

        guard let amt = amount, let idx = amountIndex else { return .invalid }

        let titleWords = idx == 0 ? Array(parts.dropFirst()) : Array(parts.prefix(idx))
        let title = titleWords.joined(separator: " ")
        guard !title.isEmpty else { return .invalid }

        let lower = title.lowercased()
        if incomeKeywords.contains(where: { lower.contains($0) }) {
            return .income(title: title, amount: amt)
        }
        return .expense(title: title, amount: amt, category: CategoryKeywordMatcher.category(for: lower))
    }
}

// MARK: - Custom Keyword Store

final class CustomKeywordStore {
    static let shared = CustomKeywordStore()
    private let key = "customCategoryRules"

    struct Rule: Codable, Identifiable {
        var id: UUID = UUID()
        var keyword: String       // lowercased for matching
        var category: String
    }

    private init() {}

    func load() -> [Rule] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rules = try? JSONDecoder().decode([Rule].self, from: data) else {
            return []
        }
        return rules
    }

    func save(_ rules: [Rule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(keyword: String, category: String) {
        var rules = load()
        let lower = keyword.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lower.isEmpty else { return }
        rules.removeAll { $0.keyword == lower }  // overwrite if same keyword
        rules.append(Rule(keyword: lower, category: category))
        save(rules)
    }

    func remove(id: UUID) {
        var rules = load()
        rules.removeAll { $0.id == id }
        save(rules)
    }
}

// MARK: - Category Keyword Matcher (6.3)

struct CategoryKeywordMatcher {
    private static let builtInRules: [(keywords: [String], category: String)] = [
        (["gas", "fuel", "shell", "bp", "chevron", "texaco", "exxon", "mobil", "speedway"], "Transport"),
        (["uber", "lyft", "taxi", "transit", "bus", "train", "metro", "parking", "toll"], "Transport"),
        (["grocery", "groceries", "whole foods", "trader joe", "kroger", "safeway",
          "aldi", "costco", "publix", "heb", "wegmans"], "Food"),
        (["restaurant", "coffee", "starbucks", "mcdonald", "pizza", "chipotle",
          "doordash", "grubhub", "ubereats", "diner", "cafe", "sushi", "burger"], "Food"),
        (["rent", "mortgage", "lease", "hoa", "home insurance"], "Housing"),
        (["netflix", "spotify", "hulu", "disney", "apple tv", "youtube premium",
          "subscription", "amazon prime", "peacock", "paramount"], "Subscriptions"),
        (["insurance", "geico", "state farm", "allstate", "aetna", "cigna", "premiu"], "Insurance"),
        (["gym", "planet fitness", "24 hour fitness", "equinox", "ymca", "crossfit"], "Health"),
        (["amazon", "target", "bestbuy", "ikea", "walmart", "costco",
          "shopping", "ebay", "etsy"], "Shopping"),
        (["doctor", "dentist", "pharmacy", "cvs", "walgreens", "rite aid",
          "medical", "hospital", "urgent care", "copay", "prescri"], "Health"),
        (["school", "tuition", "college", "udemy", "coursera", "education", "books"], "Education"),
        (["electric", "water", "internet", "comcast", "at&t", "verizon",
          "utility", "utilities", "spectrum", "xfinity", "cox"], "Utilities"),
        (["charity", "donation", "donate", "tithe", "church"], "Charity"),
    ]

    // Custom rules are checked first and override built-in ones
    static func category(for lowerText: String) -> String {
        let custom = CustomKeywordStore.shared.load()
        for rule in custom {
            if lowerText.contains(rule.keyword) {
                return rule.category
            }
        }
        for rule in builtInRules {
            if rule.keywords.contains(where: { lowerText.contains($0) }) {
                return rule.category
            }
        }
        return "General"
    }
}
