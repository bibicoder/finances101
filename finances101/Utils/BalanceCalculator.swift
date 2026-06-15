import Foundation
import SwiftData

struct BalanceData {
    let actualBalance: Decimal
    let safeToSpend: Decimal
    let charityOwed: Decimal
    let incomingSoon: Decimal
    let plannedOutflow: Decimal
    var savingsSetAside: Decimal = 0   // money parked in savings/investment wallets
    var weekIncome: Decimal = 0        // paid income received this week
    var weekSpent: Decimal = 0         // paid expenses this week
    var weekPlanned: Decimal = 0       // still-unpaid plans due by end of this week (incl. overdue)

    var weekSaved: Decimal { weekIncome - weekSpent }

    static let empty = BalanceData(actualBalance: 0, safeToSpend: 0, charityOwed: 0, incomingSoon: 0, plannedOutflow: 0)
}

final class BalanceCalculator {
    private var cachedIncomes: [IncomeEntry]
    private var cachedExpenses: [ExpenseEntry]
    private var cachedAccruals: [CharityAccrual]
    private var cachedPayments: [CharityPayment]
    private var cachedSettings: AppSettings?
    private var cachedWallets: [Wallet]
    private var cachedTransfers: [WalletTransfer]

    // Live bank state, read once from PlaidManager so the math survives disconnects
    // (a stale settings.plaidCashBalance used to linger after "Disconnect All").
    private let bankCash: Decimal
    private let hasBank: Bool

    init(modelContext: ModelContext) {
        cachedIncomes  = (try? modelContext.fetch(FetchDescriptor<IncomeEntry>())) ?? []
        cachedExpenses = (try? modelContext.fetch(FetchDescriptor<ExpenseEntry>())) ?? []
        cachedAccruals = (try? modelContext.fetch(FetchDescriptor<CharityAccrual>())) ?? []
        cachedPayments = (try? modelContext.fetch(FetchDescriptor<CharityPayment>())) ?? []
        cachedSettings = (try? modelContext.fetch(FetchDescriptor<AppSettings>()))?.first
        cachedWallets   = (try? modelContext.fetch(FetchDescriptor<Wallet>())) ?? []
        cachedTransfers = (try? modelContext.fetch(FetchDescriptor<WalletTransfer>())) ?? []
        (self.bankCash, self.hasBank) = Self.resolveBank(settings: cachedSettings)
    }

    init(incomes: [IncomeEntry], expenses: [ExpenseEntry], accruals: [CharityAccrual], payments: [CharityPayment], settings: AppSettings?,
         wallets: [Wallet] = [], transfers: [WalletTransfer] = []) {
        self.cachedIncomes  = incomes
        self.cachedExpenses = expenses
        self.cachedAccruals = accruals
        self.cachedPayments = payments
        self.cachedSettings = settings
        self.cachedWallets   = wallets
        self.cachedTransfers = transfers
        (self.bankCash, self.hasBank) = Self.resolveBank(settings: settings)
    }

    /// Live bank cash from PlaidManager, with a fallback to the cached aggregate on
    /// settings — so existing Plaid users (connected before per-bank balances shipped)
    /// keep their bank money in the total until the next sync repopulates each bank.
    private static func resolveBank(settings: AppSettings?) -> (Decimal, Bool) {
        let pm = PlaidManager.shared
        if pm.hasSyncedBalances {
            return (pm.totalCash, true)
        }
        if pm.isConnected, settings?.plaidSyncedAt != nil, let cached = settings?.plaidCashBalance {
            return (cached, true)
        }
        return (0, false)
    }

    func calculateAll() -> BalanceData {
        BalanceData(
            actualBalance: actualBalance(),
            safeToSpend: safeToSpend(),
            charityOwed: charityOwed(),
            incomingSoon: incomingSoon(),
            plannedOutflow: plannedOutflow(),
            savingsSetAside: savingsSetAside(),
            weekIncome: weekIncome(),
            weekSpent: weekSpent(),
            weekPlanned: weekPlannedOutflow()
        )
    }

    /// What you actually have right now. One consistent equation in every mode:
    ///
    ///   bank cash (live, all linked banks) + manual wallets + crypto + loose cash
    ///
    /// "Loose cash" = manually-typed paid entries not assigned to any wallet
    /// (e.g. "Coffee 5" with no wallet). Plaid-imported entries (externalId != nil)
    /// are NEVER counted here — the bank balance already reflects them, so counting
    /// them would double up. When no bank is linked, the user's starting balance
    /// seeds loose cash; with a bank, the bank is the source of truth (no seed).
    func actualBalance() -> Decimal {
        let manualWallets = cachedWallets
            .filter { !$0.isCrypto }
            .reduce(Decimal(0)) {
                $0 + WalletBalanceCalculator.balance(of: $1, incomes: cachedIncomes,
                                                     expenses: cachedExpenses, transfers: cachedTransfers)
            }
        let cryptoValue = cachedWallets
            .filter(\.isCrypto)
            .reduce(Decimal(0)) { $0 + ($1.cryptoBalanceUSD ?? 0) }
        return (hasBank ? bankCash : 0) + manualWallets + cryptoValue + looseCash()
    }

    /// Manually-entered cash not tied to a wallet or a bank import.
    /// Charity paid is only subtracted in no-bank mode (with a bank, the cash
    /// movement is already in the bank balance).
    private func looseCash() -> Decimal {
        let seed = hasBank ? 0 : (cachedSettings?.initialBalance ?? 0)
        let income = cachedIncomes
            .filter { $0.status == .paid && $0.walletId == nil && $0.externalId == nil && $0.payoutDate <= Date() }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let expense = cachedExpenses
            .filter { $0.status == .paid && $0.walletId == nil && $0.externalId == nil && $0.dueDate <= Date() }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let charity = hasBank ? 0 : sumCharityPaid()
        return seed + income - expense - charity
    }

    func charityOwed() -> Decimal {
        sumCharityAccrued() - sumCharityPaid()
    }

    /// Money parked in savings/investment wallets — part of total balance,
    /// but excluded from safe-to-spend (set aside on purpose).
    func savingsSetAside() -> Decimal {
        WalletBalanceCalculator.savingsSetAside(
            wallets: cachedWallets, incomes: cachedIncomes,
            expenses: cachedExpenses, transfers: cachedTransfers
        )
    }

    /// Safe to spend = balance minus this week's plans. Nothing else.
    /// Overdue planned bills count too — they still have to be paid.
    func safeToSpend() -> Decimal {
        actualBalance() - weekPlannedOutflow()
    }

    // MARK: - This week (Mon/Sun per locale, via Calendar.startOfWeek)

    private var currentWeek: (start: Date, end: Date) {
        let start = Calendar.current.startOfWeek(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        return (start, end)
    }

    /// Paid income received this week.
    func weekIncome() -> Decimal {
        let week = currentWeek
        return cachedIncomes
            .filter { $0.status == .paid && $0.payoutDate >= week.start && $0.payoutDate < week.end }
            .reduce(0) { $0 + $1.amount }
    }

    /// Paid expenses this week.
    func weekSpent() -> Decimal {
        let week = currentWeek
        return cachedExpenses
            .filter { $0.status == .paid && $0.dueDate >= week.start && $0.dueDate < week.end }
            .reduce(0) { $0 + $1.amount }
    }

    /// Still-unpaid plans due by the end of this week, including overdue ones.
    func weekPlannedOutflow() -> Decimal {
        let week = currentWeek
        return cachedExpenses
            .filter { $0.status == .planned && $0.dueDate < week.end }
            .reduce(0) { $0 + $1.amount }
    }


    func incomingSoon(days: Int = 30) -> Decimal {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return sumIncomingIncome(from: Date(), to: futureDate)
    }
    
    func plannedOutflow(days: Int = 30) -> Decimal {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return sumPlannedExpenses(from: Date(), to: futureDate)
    }
    
    private func sumIncomingIncome(from startDate: Date, to endDate: Date) -> Decimal {
        cachedIncomes
            .filter { $0.status.isUpcoming && $0.payoutDate >= startDate && $0.payoutDate <= endDate }
            .reduce(0) { $0 + $1.amount }
    }

    private func sumPlannedExpenses(from startDate: Date, to endDate: Date) -> Decimal {
        cachedExpenses
            .filter { $0.status == .planned && $0.dueDate >= startDate && $0.dueDate <= endDate }
            .reduce(0) { $0 + $1.amount }
    }

    private func sumCharityAccrued() -> Decimal {
        cachedAccruals.reduce(0) { $0 + $1.accruedAmount }
    }

    private func sumCharityPaid() -> Decimal {
        cachedPayments.reduce(0) { $0 + $1.amount }
    }
}
