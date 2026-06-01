import SwiftUI
import SwiftData

struct ImportTransaction: Identifiable {
    let id = UUID()
    let plaidId: String
    let date: Date
    let name: String
    let amount: Decimal
    let isExpense: Bool
    var isSelected: Bool = true
    var category: String
}

struct PlaidImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]

    @State private var transactions: [ImportTransaction] = []
    @State private var accounts: [PlaidAccount] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDays = 30
    @State private var showDoneAlert = false
    @State private var importedCount = 0
    @State private var syncedBalance: Decimal? = nil

    private var symbol: String { settings.first?.currencySymbol ?? "$" }
    private var selectedCount: Int { transactions.filter(\.isSelected).count }
    private var allSelected: Bool { selectedCount == transactions.count }

    // Depository accounts (checking/savings) → real cash
    private var depositoryAccounts: [PlaidAccount] {
        accounts.filter { $0.type == "depository" }
    }

    // Credit accounts → debt, not cash
    private var creditAccounts: [PlaidAccount] {
        accounts.filter { $0.type == "credit" }
    }

    private var totalDepositoryBalance: Decimal {
        depositoryAccounts.compactMap { $0.balances.current.map { Decimal($0) } }.reduce(0, +)
    }

    private var totalCreditOwed: Decimal {
        creditAccounts.compactMap { $0.balances.current.map { Decimal($0) } }.reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Fetching from bank...")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if transactions.isEmpty && accounts.isEmpty {
                    ContentUnavailableView(
                        "No transactions",
                        systemImage: "list.bullet.rectangle",
                        description: Text("No transactions found in the last \(selectedDays) days")
                    )
                } else {
                    transactionList
                }
            }
            .navigationTitle("Import Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if !transactions.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Import (\(selectedCount))") { importSelected() }
                            .fontWeight(.semibold)
                            .disabled(selectedCount == 0)
                    }
                }
            }
        }
        .task { await load() }
        .alert("Import Complete", isPresented: $showDoneAlert) {
            Button("Done") { dismiss() }
        } message: {
            if let balance = syncedBalance {
                Text("\(importedCount) transactions added. Balance synced to \(symbol)\(balance.formatted()) from your bank.")
            } else {
                Text("\(importedCount) transactions added.")
            }
        }
    }

    private var transactionList: some View {
        List {
            // Account balances section — shows real money vs debt
            if !accounts.isEmpty {
                Section("Your Accounts") {
                    ForEach(depositoryAccounts, id: \.accountId) { account in
                        AccountBalanceRow(account: account, symbol: symbol, isDebt: false)
                    }
                    ForEach(creditAccounts, id: \.accountId) { account in
                        AccountBalanceRow(account: account, symbol: symbol, isDebt: true)
                    }
                }
            }

            Section {
                Picker("Period", selection: $selectedDays) {
                    Text("Last 30 days").tag(30)
                    Text("Last 60 days").tag(60)
                    Text("Last 90 days").tag(90)
                }
                .onChange(of: selectedDays) { _, _ in Task { await load() } }

                if !transactions.isEmpty {
                    Button(allSelected ? "Deselect All" : "Select All") {
                        let newValue = !allSelected
                        for i in transactions.indices { transactions[i].isSelected = newValue }
                    }
                    .font(.subheadline)
                }
            }

            if !transactions.isEmpty {
                Section("\(transactions.count) transactions • \(selectedCount) selected") {
                    ForEach($transactions) { $tx in
                        ImportRow(transaction: $tx, symbol: symbol)
                    }
                }
            }
        }
    }

    private func load() async {
        guard let token = PlaidManager.shared.accessToken() else {
            errorMessage = "No bank connected"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let fetchedAccounts = PlaidService.fetchAccounts(accessToken: token)
            async let fetchedTxs = PlaidService.fetchTransactions(accessToken: token, days: selectedDays)

            let (accs, plaidTxs) = try await (fetchedAccounts, fetchedTxs)
            accounts = accs

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"

            transactions = plaidTxs
                .filter { !$0.pending }
                .compactMap { tx -> ImportTransaction? in
                    guard let date = fmt.date(from: tx.date) else { return nil }
                    return ImportTransaction(
                        plaidId: tx.transactionId,
                        date: date,
                        name: tx.merchantName ?? tx.name,
                        amount: Decimal(abs(tx.amount)),
                        isExpense: tx.amount > 0,
                        category: mapCategory(tx.category)
                    )
                }
                .sorted { $0.date > $1.date }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func importSelected() {
        let selected = transactions.filter(\.isSelected)
        importedCount = selected.count

        for tx in selected {
            if tx.isExpense {
                let entry = ExpenseEntry(
                    title: tx.name,
                    amount: tx.amount,
                    dueDate: tx.date,
                    category: tx.category,
                    type: .optional,
                    status: .paid
                )
                modelContext.insert(entry)
            } else {
                let entry = IncomeEntry(
                    title: tx.name,
                    amount: tx.amount,
                    earnedDate: tx.date,
                    payoutDate: tx.date,
                    status: .paid,
                    category: tx.category
                )
                modelContext.insert(entry)
            }
        }

        // Sync balance using ALL paid transactions (including just-inserted ones).
        // BalanceCalculator: actualBalance = initialBalance + sumPaidIncome - sumPaidExpenses - charityPaid
        // We want actualBalance = bankCashBalance (sum of ALL checking + savings accounts)
        // So: initialBalance = bankCashBalance - sumPaidIncome + sumPaidExpenses
        // (charity is excluded since Plaid doesn't track it)
        if !depositoryAccounts.isEmpty, let appSettings = settings.first {
            let bankCashBalance = totalDepositoryBalance
            let allPaidIncome = (try? modelContext.fetch(FetchDescriptor<IncomeEntry>()))?
                .filter { $0.status == .paid }
                .reduce(0) { $0 + $1.amount } ?? 0
            let allPaidExpenses = (try? modelContext.fetch(FetchDescriptor<ExpenseEntry>()))?
                .filter { $0.status == .paid }
                .reduce(0) { $0 + $1.amount } ?? 0
            appSettings.initialBalance = bankCashBalance - allPaidIncome + allPaidExpenses
            appSettings.plaidCashBalance = bankCashBalance
            appSettings.plaidCreditBalance = totalCreditOwed
            appSettings.plaidSyncedAt = Date()
            appSettings.updatedAt = Date()
            syncedBalance = bankCashBalance
        }

        modelContext.saveWithLogging()
        HapticManager.success()
        showDoneAlert = true
    }

    private func mapCategory(_ categories: [String]?) -> String {
        switch categories?.first {
        case "Food and Drink": return "Food"
        case "Travel": return "Transport"
        case "Shops": return "Shopping"
        case "Recreation": return "Entertainment"
        case "Healthcare": return "Health"
        case "Payment", "Transfer": return "Transfer"
        case "Service": return "Services"
        default: return "General"
        }
    }
}

// MARK: - Account Balance Row

private struct AccountBalanceRow: View {
    let account: PlaidAccount
    let symbol: String
    let isDebt: Bool

    private var balance: Decimal {
        account.balances.current.map { Decimal($0) } ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isDebt ? "creditcard.fill" : "building.columns.fill")
                .font(.subheadline)
                .foregroundStyle(isDebt ? AppColors.expense : AppColors.income)
                .frame(width: 32, height: 32)
                .background((isDebt ? AppColors.expense : AppColors.income).opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(isDebt ? "Credit card — balance owed" : "Checking / Savings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(isDebt ? "-" : "")\(symbol)\(balance.formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isDebt ? AppColors.expense : AppColors.income)
                if let available = account.balances.available {
                    Text("avail: \(symbol)\(Decimal(available).formatted())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Transaction Row

private struct ImportRow: View {
    @Binding var transaction: ImportTransaction
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $transaction.isSelected).labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text(transaction.category)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(transaction.isExpense ? "-" : "+")\(symbol)\(transaction.amount.formatted())")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(transaction.isExpense ? AppColors.expense : AppColors.income)
        }
    }
}
