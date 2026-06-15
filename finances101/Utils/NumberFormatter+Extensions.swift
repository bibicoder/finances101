import Foundation

extension Decimal {
    /// Parses user-typed amounts. `Decimal(string:)` only understands "." as the
    /// decimal separator, but iOS decimal pads insert "," in many locales (ru/tr/eu),
    /// silently truncating "12,50" to 12. Also strips currency symbols and spaces.
    init?(userInput: String) {
        var cleaned = userInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")

        if cleaned.contains(",") && cleaned.contains(".") {
            // "1,234.56" — comma is a thousands separator
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        } else {
            // "12,50" — comma is the decimal separator
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }

        guard !cleaned.isEmpty, let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US")) else { return nil }
        self = value
    }

    /// Converts API doubles (e.g. Plaid amounts) to money-safe Decimal rounded to 2 dp,
    /// avoiding binary-float artifacts like 12.300000000000001.
    init(money double: Double) {
        var raw = Decimal(double)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .bankers)
        self = rounded
    }
    func formatted(compact: Bool = true) -> String {
        let number = NSDecimalNumber(decimal: self)
        let doubleValue = number.doubleValue
        let absValue = abs(doubleValue)
        
        if compact && absValue >= 1_000_000 {
            let millions = doubleValue / 1_000_000
            if millions == floor(millions) {
                return String(format: "%.0fM", millions)
            }
            return String(format: "%.1fM", millions)
        } else if compact && absValue >= 10_000 {
            let thousands = doubleValue / 1_000
            if thousands == floor(thousands) {
                return String(format: "%.0fK", thousands)
            }
            return String(format: "%.1fK", thousands)
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter.string(from: number) ?? "0"
        }
    }
    
    func formattedFull() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0.00"
    }
}
