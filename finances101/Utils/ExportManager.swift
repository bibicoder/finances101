import Foundation
import SwiftData

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
