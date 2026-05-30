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
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDays = 30
    @State private var showDoneAlert = false
    @State private var importedCount = 0

    private var symbol: String { settings.first?.currencySymbol ?? "$" }
    private var selectedCount: Int { transactions.filter(\.isSelected).count }
    private var allSelected: Bool { selectedCount == transactions.count }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Fetching transactions...")
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
                } else if transactions.isEmpty {
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
            Text("\(importedCount) transactions added to your app.")
        }
    }

    private var transactionList: some View {
        List {
            Section {
                Picker("Period", selection: $selectedDays) {
                    Text("Last 30 days").tag(30)
                    Text("Last 60 days").tag(60)
                    Text("Last 90 days").tag(90)
                }
                .onChange(of: selectedDays) { _, _ in Task { await load() } }

                Button(allSelected ? "Deselect All" : "Select All") {
                    let newValue = !allSelected
                    for i in transactions.indices { transactions[i].isSelected = newValue }
                }
                .font(.subheadline)
            }

            Section("\(transactions.count) transactions • \(selectedCount) selected") {
                ForEach($transactions) { $tx in
                    ImportRow(transaction: $tx, symbol: symbol)
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
            let plaidTxs = try await PlaidService.fetchTransactions(accessToken: token, days: selectedDays)
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
