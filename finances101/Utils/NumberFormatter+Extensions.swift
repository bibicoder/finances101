import Foundation

extension Decimal {
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
