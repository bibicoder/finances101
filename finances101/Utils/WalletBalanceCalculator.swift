import Foundation

/// Single source of truth for per-wallet balances.
/// Used by WalletsView, BalanceCalculator and the dashboard breakdown.
enum WalletBalanceCalculator {

    static func balance(of wallet: Wallet, incomes: [IncomeEntry], expenses: [ExpenseEntry], transfers: [WalletTransfer]) -> Decimal {
        // Crypto wallets are valued by their on-chain balance (USD), not by ledger entries
        if wallet.isCrypto {
            return wallet.cryptoBalanceUSD ?? 0
        }
        let income = incomes
            .filter { $0.walletId == wallet.id && $0.status == .paid }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let expense = expenses
            .filter { $0.walletId == wallet.id && $0.status == .paid }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let transfersIn = transfers
            .filter { $0.toWalletId == wallet.id }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let transfersOut = transfers
            .filter { $0.fromWalletId == wallet.id }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return wallet.initialBalance + income - expense + transfersIn - transfersOut
    }

    /// Sum of savings + investment + crypto wallet balances (never negative).
    /// This money stays in the total balance but is excluded from safe-to-spend.
    static func savingsSetAside(wallets: [Wallet], incomes: [IncomeEntry], expenses: [ExpenseEntry], transfers: [WalletTransfer]) -> Decimal {
        let total = wallets
            .filter { $0.type == .savings || $0.type == .investment || $0.type == .crypto }
            .reduce(Decimal(0)) { $0 + balance(of: $1, incomes: incomes, expenses: expenses, transfers: transfers) }
        return max(0, total)
    }
}
