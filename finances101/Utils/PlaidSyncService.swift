import Foundation
import SwiftData

/// Pulls balances + transactions from every linked institution.
/// Total Balance reads settings.plaidCashBalance directly (see BalanceCalculator),
/// so syncing the cached bank balance is what keeps the app anchored to reality.
/// Imported transactions are analytics-only — they don't move the balance.
///
/// Called automatically on app launch (throttled) and from pull-to-refresh.
@MainActor
enum PlaidSyncService {

    struct SyncResult {
        var importedCount = 0
        var bankCash: Decimal = 0
        var bankCredit: Decimal = 0
        var institutions = 0
    }

    private static let lastSyncKey = "plaidLastAutoSyncAt"
    private static let throttleHours: Double = 4

    /// Auto-sync if the last one was more than `throttleHours` ago.
    static func autoSyncIfNeeded(modelContext: ModelContext) async {
        guard PlaidManager.shared.isConnected else { return }
        let last = UserDefaults.standard.object(forKey: lastSyncKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > throttleHours * 3600 else { return }
        _ = await syncAll(modelContext: modelContext)
    }

    /// Full sync of all connections. Returns nil when nothing is connected or all requests failed.
    @discardableResult
    static func syncAll(modelContext: ModelContext, days: Int = 30) async -> SyncResult? {
        let connections = PlaidManager.shared.connections
        guard !connections.isEmpty else { return nil }

        var result = SyncResult()
        var anySucceeded = false

        let existingIds = existingExternalIds(modelContext: modelContext)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        for connection in connections {
            do {
                async let accountsTask = PlaidService.fetchAccounts(accessToken: connection.accessToken)
                async let txTask = PlaidService.fetchTransactions(accessToken: connection.accessToken, days: days)
                let (accounts, transactions) = try await (accountsTask, txTask)

                // Per-bank spendable cash + credit owed, so the dashboard can show each bank.
                let bankCash = spendableCash(of: accounts)
                let bankCredit = creditOwed(of: accounts)
                PlaidManager.shared.updateSyncedBalances(id: connection.id, cash: bankCash, credit: bankCredit)

                result.bankCash += bankCash
                result.bankCredit += bankCredit

                for tx in transactions where !tx.pending && !existingIds.contains(tx.transactionId) {
                    guard let date = fmt.date(from: tx.date) else { continue }
                    insertTransaction(tx, date: date, modelContext: modelContext)
                    result.importedCount += 1
                }

                result.institutions += 1
                anySucceeded = true
            } catch {
                print("[PlaidSync] \(connection.institutionName) failed: \(error.localizedDescription)")
            }
        }

        guard anySucceeded else { return nil }

        reanchorBalance(bankCash: result.bankCash, bankCredit: result.bankCredit, modelContext: modelContext)
        modelContext.saveWithLogging()
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        return result
    }

    /// Caches the synced aggregate bank balances on AppSettings (used by the widget
    /// and legacy back-compat). Per-bank balances live on PlaidManager; the live
    /// total is what BalanceCalculator reads.
    ///
    /// initialBalance is forced to 0 here: with a bank linked, the bank is the source
    /// of truth for cash, so any starting-balance seed would double-count. This also
    /// heals values corrupted by the old re-anchor formula. Off-bank cash should be
    /// tracked with a manual Cash wallet, not the starting balance.
    static func reanchorBalance(bankCash: Decimal, bankCredit: Decimal, modelContext: ModelContext) {
        guard let settings = ((try? modelContext.fetch(FetchDescriptor<AppSettings>())) ?? []).first else { return }
        settings.initialBalance = 0
        settings.plaidCashBalance = bankCash
        settings.plaidCreditBalance = bankCredit
        settings.plaidSyncedAt = Date()
        settings.updatedAt = Date()
    }

    // MARK: - Balance helpers

    /// Real spendable cash = `available` (what you can actually use), falling back to
    /// `current` when a bank doesn't report available. Summed over checking/savings.
    static func spendableCash(of accounts: [PlaidAccount]) -> Decimal {
        accounts
            .filter { $0.type == "depository" }
            .compactMap { $0.balances.available ?? $0.balances.current }
            .map { Decimal(money: $0) }
            .reduce(0, +)
    }

    /// Credit-card debt owed (current balance on credit accounts).
    static func creditOwed(of accounts: [PlaidAccount]) -> Decimal {
        accounts
            .filter { $0.type == "credit" }
            .compactMap { $0.balances.current }
            .map { Decimal(money: $0) }
            .reduce(0, +)
    }

    // MARK: - Helpers

    static func existingExternalIds(modelContext: ModelContext) -> Set<String> {
        let incomeIds = ((try? modelContext.fetch(FetchDescriptor<IncomeEntry>())) ?? [])
            .compactMap(\.externalId)
        let expenseIds = ((try? modelContext.fetch(FetchDescriptor<ExpenseEntry>())) ?? [])
            .compactMap(\.externalId)
        return Set(incomeIds + expenseIds)
    }

    private static func insertTransaction(_ tx: PlaidTransaction, date: Date, modelContext: ModelContext) {
        let name = tx.merchantName ?? tx.name
        let amount = Decimal(money: abs(tx.amount))
        let category = mapCategory(tx.category, name: name)

        if tx.amount > 0 {
            modelContext.insert(ExpenseEntry(
                title: name, amount: amount, dueDate: date,
                category: category, type: .optional, status: .paid,
                externalId: tx.transactionId
            ))
        } else {
            modelContext.insert(IncomeEntry(
                title: name, amount: amount,
                earnedDate: date, payoutDate: date,
                status: .paid, category: category,
                externalId: tx.transactionId
            ))
        }
    }

    static func mapCategory(_ categories: [String]?, name: String) -> String {
        switch categories?.first {
        case "Food and Drink": return "Food"
        case "Travel": return "Transport"
        case "Shops": return "Shopping"
        case "Recreation": return "Entertainment"
        case "Healthcare": return "Health"
        case "Payment", "Transfer": return "Transfer"
        case "Service": return "Services"
        default:
            // Fall back to the keyword matcher used by quick entry
            let matched = CategoryKeywordMatcher.category(for: name.lowercased())
            return matched == "General" ? "General" : matched
        }
    }
}
