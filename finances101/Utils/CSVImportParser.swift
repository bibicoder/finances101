import Foundation

enum CSVBankFormat {
    case chase       // Transaction Date,Post Date,Description,Category,Type,Amount,Memo
    case bankOfAmerica // Date,Description,Amount,Running Bal.
    case wellsFargo  // "Date","Amount","*","*","Description"
    case generic     // Date,Description,Amount (fallback)
}

struct CSVTransaction {
    let date: Date
    let description: String
    let amount: Decimal
    let isCredit: Bool   // true = income, false = expense
    let rawCategory: String
}

enum CSVImportParser {

    static func parse(csv: String) -> [CSVTransaction] {
        let lines = csv.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let header = lines.first else { return [] }

        let format = detectFormat(header: header.lowercased())
        let dataLines = lines.dropFirst().filter { !$0.isEmpty }
        return dataLines.compactMap { parseLine($0, format: format) }
    }

    private static func detectFormat(header: String) -> CSVBankFormat {
        if header.contains("transaction date") && header.contains("post date") {
            return .chase
        } else if header.contains("running bal") {
            return .bankOfAmerica
        } else if parseColumns(header).count >= 5 && parseColumns(header)[1].contains("amount") {
            return .wellsFargo
        }
        return .generic
    }

    private static func parseLine(_ line: String, format: CSVBankFormat) -> CSVTransaction? {
        let cols = parseColumns(line)
        let formatter = DateFormatter()

        switch format {
        case .chase:
            // Transaction Date,Post Date,Description,Category,Type,Amount,Memo
            guard cols.count >= 6 else { return nil }
            formatter.dateFormat = "MM/dd/yyyy"
            guard let date = formatter.date(from: cols[0]),
                  let amount = Decimal(string: cols[5].replacingOccurrences(of: ",", with: "")) else { return nil }
            let isCredit = amount > 0
            return CSVTransaction(date: date, description: cols[2], amount: abs(amount), isCredit: isCredit, rawCategory: cols[3])

        case .bankOfAmerica:
            // Date,Description,Amount,Running Bal.
            guard cols.count >= 3 else { return nil }
            formatter.dateFormat = "MM/dd/yyyy"
            guard let date = formatter.date(from: cols[0]),
                  let amount = Decimal(string: cols[2].replacingOccurrences(of: ",", with: "")) else { return nil }
            let isCredit = amount > 0
            return CSVTransaction(date: date, description: cols[1], amount: abs(amount), isCredit: isCredit, rawCategory: "")

        case .wellsFargo:
            // "Date","Amount","*","*","Description"
            guard cols.count >= 5 else { return nil }
            formatter.dateFormat = "MM/dd/yyyy"
            guard let date = formatter.date(from: cols[0]),
                  let amount = Decimal(string: cols[1].replacingOccurrences(of: ",", with: "")) else { return nil }
            let isCredit = amount > 0
            return CSVTransaction(date: date, description: cols[4], amount: abs(amount), isCredit: isCredit, rawCategory: "")

        case .generic:
            guard cols.count >= 3 else { return nil }
            let dateFormats = ["MM/dd/yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "dd/MM/yyyy"]
            var date: Date?
            for fmt in dateFormats {
                formatter.dateFormat = fmt
                if let d = formatter.date(from: cols[0]) { date = d; break }
            }
            guard let date,
                  let amount = Decimal(string: cols[2].replacingOccurrences(of: ",", with: "")) else { return nil }
            let isCredit = amount > 0
            return CSVTransaction(date: date, description: cols[1], amount: abs(amount), isCredit: isCredit, rawCategory: cols.count > 3 ? cols[3] : "")
        }
    }

    // Handles quoted CSV fields properly
    private static func parseColumns(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                columns.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current.trimmingCharacters(in: .whitespaces))
        return columns
    }

    static func autoCategory(for description: String) -> String {
        let desc = description.lowercased()
        let rules: [(keywords: [String], category: String)] = [
            (["gas", "fuel", "shell", "chevron", "bp ", "exxon", "mobil"], "Transport"),
            (["grocery", "whole foods", "trader joe", "safeway", "kroger", "walmart", "costco", "target"], "Food"),
            (["restaurant", "mcdonald", "starbucks", "chipotle", "doordash", "ubereats", "grubhub", "dining", "cafe"], "Food"),
            (["rent", "mortgage", "lease", "hoa"], "Housing"),
            (["netflix", "spotify", "hulu", "apple", "amazon prime", "disney", "subscription"], "Subscriptions"),
            (["insurance", "geico", "state farm", "allstate"], "Insurance"),
            (["gym", "planet fitness", "equinox"], "Health"),
            (["amazon", "ebay", "etsy", "shopping"], "Shopping"),
            (["doctor", "pharmacy", "cvs", "walgreens", "medical", "dental"], "Health"),
            (["school", "tuition", "university", "college"], "Education"),
            (["uber", "lyft", "transit", "metro", "parking"], "Transport"),
            (["electric", "water", "internet", "phone", "att", "verizon", "t-mobile", "utility"], "Utilities"),
        ]
        for rule in rules {
            if rule.keywords.contains(where: { desc.contains($0) }) {
                return rule.category
            }
        }
        return "Other"
    }
}
