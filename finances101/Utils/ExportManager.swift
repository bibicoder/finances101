import Foundation
import SwiftData
import UIKit

struct ExportData: Codable {
    let exportDate: Date
    let version: String
    let settings: SettingsExport
    let incomes: [IncomeExport]
    let expenses: [ExpenseExport]
    let charityAccruals: [CharityAccrualExport]
    let charityPayments: [CharityPaymentExport]
    let debts: [DebtExport]
    let wishlistItems: [WishlistExport]
    let recurringTemplates: [RecurringExport]
}

struct SettingsExport: Codable {
    let initialBalance: Decimal
    let charityPercentage: Double
    let charityAccrualMode: String
    let currency: String
    let currencySymbol: String
}

struct IncomeExport: Codable {
    let id: String
    let title: String
    let amount: Decimal
    let earnedDate: Date
    let payoutDate: Date
    let status: String
    let category: String
    let note: String?
    let isRecurring: Bool
}

struct ExpenseExport: Codable {
    let id: String
    let title: String
    let amount: Decimal
    let dueDate: Date
    let category: String
    let type: String
    let status: String
    let note: String?
    let isRecurring: Bool
}

struct CharityAccrualExport: Codable {
    let id: String
    let date: Date
    let baseAmount: Decimal
    let percentage: Double
    let accruedAmount: Decimal
    let note: String?
}

struct CharityPaymentExport: Codable {
    let id: String
    let date: Date
    let amount: Decimal
    let note: String?
}

struct DebtExport: Codable {
    let id: String
    let creditor: String
    let totalAmount: Decimal
    let paidAmount: Decimal
    let priority: Int
    let targetDate: Date?
    let note: String?
}

struct WishlistExport: Codable {
    let id: String
    let title: String
    let amount: Decimal
    let priority: String
    let status: String
    let scheduledDate: Date?
    let category: String
    let note: String?
}

struct RecurringExport: Codable {
    let id: String
    let title: String
    let amount: Decimal
    let type: String
    let frequency: String
    let category: String
    let startDate: Date
    let isActive: Bool
    let note: String?
}

final class ExportManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func exportToJSON() -> URL? {
        let exportData = gatherExportData()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(exportData)
            let fileName = "CashFlowBackup_\(formatDate(Date())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            print("Export JSON failed: \(error)")
            return nil
        }
    }
    
    func exportToCSV() -> URL? {
        var csv = "Date,Type,Title,Amount,Category,Status,Note\n"
        
        let incomes = fetchAll(IncomeEntry.self)
        for income in incomes {
            csv += "\(formatDate(income.payoutDate)),Income,\"\(income.title)\",\(income.amount),\(income.category),\(income.status.rawValue),\"\(income.note ?? "")\"\n"
        }
        
        let expenses = fetchAll(ExpenseEntry.self)
        for expense in expenses {
            csv += "\(formatDate(expense.dueDate)),Expense,\"\(expense.title)\",\(expense.amount),\(expense.category),\(expense.status.rawValue),\"\(expense.note ?? "")\"\n"
        }
        
        let accruals = fetchAll(CharityAccrual.self)
        for accrual in accruals {
            csv += "\(formatDate(accrual.date)),Charity Accrual,\"From \(accrual.baseAmount) @ \(Int(accrual.percentage))%\",\(accrual.accruedAmount),Charity,Accrued,\"\(accrual.note ?? "")\"\n"
        }
        
        let payments = fetchAll(CharityPayment.self)
        for payment in payments {
            csv += "\(formatDate(payment.date)),Charity Payment,\"Payment\",\(payment.amount),Charity,Sent,\"\(payment.note ?? "")\"\n"
        }
        
        let fileName = "CashFlowExport_\(formatDate(Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Export CSV failed: \(error)")
            return nil
        }
    }
    
    private func gatherExportData() -> ExportData {
        let settings = fetchAll(AppSettings.self).first ?? AppSettings()
        let incomes = fetchAll(IncomeEntry.self)
        let expenses = fetchAll(ExpenseEntry.self)
        let accruals = fetchAll(CharityAccrual.self)
        let payments = fetchAll(CharityPayment.self)
        let debts = fetchAll(Debt.self)
        let wishlist = fetchAll(WishlistItem.self)
        let templates = fetchAll(RecurringTemplate.self)
        
        return ExportData(
            exportDate: Date(),
            version: "1.0.0",
            settings: SettingsExport(
                initialBalance: settings.initialBalance,
                charityPercentage: settings.charityPercentage,
                charityAccrualMode: settings.charityAccrualMode.rawValue,
                currency: settings.currency,
                currencySymbol: settings.currencySymbol
            ),
            incomes: incomes.map { income in
                IncomeExport(
                    id: income.id.uuidString,
                    title: income.title,
                    amount: income.amount,
                    earnedDate: income.earnedDate,
                    payoutDate: income.payoutDate,
                    status: income.status.rawValue,
                    category: income.category,
                    note: income.note,
                    isRecurring: income.isRecurring
                )
            },
            expenses: expenses.map { expense in
                ExpenseExport(
                    id: expense.id.uuidString,
                    title: expense.title,
                    amount: expense.amount,
                    dueDate: expense.dueDate,
                    category: expense.category,
                    type: expense.type.rawValue,
                    status: expense.status.rawValue,
                    note: expense.note,
                    isRecurring: expense.isRecurring
                )
            },
            charityAccruals: accruals.map { accrual in
                CharityAccrualExport(
                    id: accrual.id.uuidString,
                    date: accrual.date,
                    baseAmount: accrual.baseAmount,
                    percentage: accrual.percentage,
                    accruedAmount: accrual.accruedAmount,
                    note: accrual.note
                )
            },
            charityPayments: payments.map { payment in
                CharityPaymentExport(
                    id: payment.id.uuidString,
                    date: payment.date,
                    amount: payment.amount,
                    note: payment.note
                )
            },
            debts: debts.map { debt in
                DebtExport(
                    id: debt.id.uuidString,
                    creditor: debt.creditor,
                    totalAmount: debt.totalAmount,
                    paidAmount: debt.paidAmount,
                    priority: debt.priority,
                    targetDate: debt.targetDate,
                    note: debt.note
                )
            },
            wishlistItems: wishlist.map { item in
                WishlistExport(
                    id: item.id.uuidString,
                    title: item.title,
                    amount: item.amount,
                    priority: item.priority.rawValue,
                    status: item.status.rawValue,
                    scheduledDate: item.scheduledDate,
                    category: item.category,
                    note: item.note
                )
            },
            recurringTemplates: templates.map { template in
                RecurringExport(
                    id: template.id.uuidString,
                    title: template.title,
                    amount: template.amount,
                    type: template.type.rawValue,
                    frequency: template.frequency.rawValue,
                    category: template.category,
                    startDate: template.startDate,
                    isActive: template.isActive,
                    note: template.note
                )
            }
        )
    }
    
    // MARK: PDF Export

    func exportToPDF(startDate: Date, endDate: Date) -> URL? {
        let settings = fetchAll(AppSettings.self).first ?? AppSettings()
        let symbol = settings.currencySymbol

        let allIncomes = fetchAll(IncomeEntry.self)
            .filter { $0.status == .paid && $0.payoutDate >= startDate && $0.payoutDate <= endDate }
        let allExpenses = fetchAll(ExpenseEntry.self)
            .filter { $0.status == .paid && $0.dueDate >= startDate && $0.dueDate <= endDate && !$0.isDebtPayment }
        let charityPayments = fetchAll(CharityPayment.self)
            .filter { $0.date >= startDate && $0.date <= endDate }
        let debts = fetchAll(Debt.self)

        let totalIncome = allIncomes.reduce(Decimal(0)) { $0 + $1.amount }
        let totalExpenses = allExpenses.reduce(Decimal(0)) { $0 + $1.amount }
        let totalCharity = charityPayments.reduce(Decimal(0)) { $0 + $1.amount }
        let savings = totalIncome - totalExpenses - totalCharity
        let savingsRate = totalIncome > 0
            ? Double(truncating: (savings / totalIncome * 100) as NSDecimalNumber)
            : 0

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let dateStr = formatDate(Date())
        let fileName = "Finance101_Report_\(dateStr).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let df = DateFormatter()
        df.dateStyle = .medium

        do { try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            var y: CGFloat = 40

            // Title
            y = drawText("Finance 101 — Financial Report", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 22), color: UIColor(red: 0.49, green: 0.23, blue: 0.93, alpha: 1), maxWidth: 532)
            y += 6
            y = drawText("\(df.string(from: startDate)) – \(df.string(from: endDate))", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12), color: .gray, maxWidth: 532)
            y += 20

            // Summary box
            let summaryItems: [(String, String)] = [
                ("Total Income", "\(symbol)\(totalIncome.formatted(.number.precision(.fractionLength(2))))"),
                ("Total Expenses", "\(symbol)\(totalExpenses.formatted(.number.precision(.fractionLength(2))))"),
                ("Charity Paid", "\(symbol)\(totalCharity.formatted(.number.precision(.fractionLength(2))))"),
                ("Net Savings", "\(symbol)\(savings.formatted(.number.precision(.fractionLength(2))))"),
                ("Savings Rate", "\(Int(savingsRate))%"),
            ]
            y = drawSection("Summary", items: summaryItems, startY: y, symbol: symbol, pageRect: pageRect, ctx: ctx)
            y += 12

            // Income by category
            var incomeByCategory: [String: Decimal] = [:]
            for inc in allIncomes { incomeByCategory[inc.category, default: 0] += inc.amount }
            let incomeItems = incomeByCategory.sorted { $0.value > $1.value }
                .map { ("\($0.key)", "\(symbol)\($0.value.formatted(.number.precision(.fractionLength(2))))") }
            y = drawSection("Income by Category", items: incomeItems, startY: y, symbol: symbol, pageRect: pageRect, ctx: ctx)
            y += 12

            // Expense by category
            var expByCategory: [String: Decimal] = [:]
            for exp in allExpenses { expByCategory[exp.category, default: 0] += exp.amount }
            let expItems = expByCategory.sorted { $0.value > $1.value }
                .map { ("\($0.key)", "\(symbol)\($0.value.formatted(.number.precision(.fractionLength(2))))") }
            y = drawSection("Expenses by Category", items: expItems, startY: y, symbol: symbol, pageRect: pageRect, ctx: ctx)

            if !debts.isEmpty {
                y += 12
                if y > 680 { ctx.beginPage(); y = 40 }
                let debtItems = debts.map { ("\($0.creditor)", "\(symbol)\($0.remainingAmount.formatted(.number.precision(.fractionLength(2)))) remaining") }
                y = drawSection("Debts", items: debtItems, startY: y, symbol: symbol, pageRect: pageRect, ctx: ctx)
            }

            // Footer
            let footerY = pageRect.height - 30
            drawText("Generated by Finance 101 · \(dateStr)", at: CGPoint(x: 40, y: footerY), font: .systemFont(ofSize: 9), color: .lightGray, maxWidth: 532)
        } } catch { return nil }

        return url
    }

    @discardableResult
    private func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor, maxWidth: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let boundingRect = str.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                            options: .usesLineFragmentOrigin, context: nil)
        str.draw(in: CGRect(origin: point, size: boundingRect.size))
        return point.y + boundingRect.height
    }

    private func drawSection(_ title: String, items: [(String, String)], startY: CGFloat,
                              symbol: String, pageRect: CGRect, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = startY
        if y > 700 { ctx.beginPage(); y = 40 }

        // Section header
        y = drawText(title, at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 13),
                     color: UIColor(red: 0.49, green: 0.23, blue: 0.93, alpha: 1), maxWidth: 532)
        y += 4

        UIColor(red: 0.49, green: 0.23, blue: 0.93, alpha: 0.3).setFill()
        UIBezierPath(rect: CGRect(x: 40, y: y, width: 532, height: 1)).fill()
        y += 6

        if items.isEmpty {
            y = drawText("No data for this period.", at: CGPoint(x: 40, y: y), font: .italicSystemFont(ofSize: 11), color: .gray, maxWidth: 532)
            y += 4
        }

        for (label, value) in items {
            if y > 740 { ctx.beginPage(); y = 40 }
            drawText(label, at: CGPoint(x: 44, y: y), font: .systemFont(ofSize: 11), color: .black, maxWidth: 380)
            let valueWidth: CGFloat = 130
            let valueX = pageRect.width - 40 - valueWidth
            drawText(value, at: CGPoint(x: valueX, y: y), font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                     color: .darkGray, maxWidth: valueWidth)
            y += 18
        }
        return y
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
        let descriptor = FetchDescriptor<T>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
