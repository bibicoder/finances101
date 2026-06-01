import SwiftUI
import SwiftData

struct WalletDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var wallet: Wallet
    let incomes: [IncomeEntry]
    let expenses: [ExpenseEntry]
    let symbol: String

    @State private var showDeleteAlert = false

    private var walletIncomes: [IncomeEntry] {
        incomes.filter { $0.walletId == wallet.id }.sorted { $0.payoutDate > $1.payoutDate }
    }
    private var walletExpenses: [ExpenseEntry] {
        expenses.filter { $0.walletId == wallet.id }.sorted { $0.dueDate > $1.dueDate }
    }
    private var paidIncome: Decimal {
        walletIncomes.filter { $0.status == .paid }.reduce(0) { $0 + $1.amount }
    }
    private var paidExpenses: Decimal {
        walletExpenses.filter { $0.status == .paid }.reduce(0) { $0 + $1.amount }
    }
    private var balance: Decimal { wallet.initialBalance + paidIncome - paidExpenses }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: wallet.iconName)
                            .font(.system(size: 36))
                            .foregroundStyle(Color(hex: wallet.colorHex))
                        Text(wallet.name)
                            .font(.title2.weight(.bold))
                        Text("\(balance >= 0 ? "" : "-")\(symbol)\(abs(balance).formatted(.number.precision(.fractionLength(2))))")
                            .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(balance >= 0 ? AppColors.income : AppColors.expense)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .appCard()

                    // Stats
                    HStack(spacing: 12) {
                        statBox(label: "Income", value: paidIncome, color: AppColors.income)
                        statBox(label: "Expenses", value: paidExpenses, color: AppColors.expense)
                    }

                    // Edit name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name").font(.caption).foregroundStyle(AppColors.textSecondary)
                        TextField("Wallet name", text: $wallet.name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: wallet.name) { _, _ in modelContext.saveWithLogging() }
                    }
                    .padding()
                    .appCard()

                    if !walletIncomes.isEmpty || !walletExpenses.isEmpty {
                        recentTransactions
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Wallet", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.expense.opacity(0.1))
                            .foregroundStyle(AppColors.expense)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Wallet?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(wallet)
                    modelContext.saveWithLogging()
                    dismiss()
                }
            } message: {
                Text("Transactions assigned to this wallet will become unassigned.")
            }
        }
    }

    private func statBox(label: String, value: Decimal, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(AppColors.textSecondary)
            Text("\(symbol)\(value.formatted(.number.precision(.fractionLength(0))))")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .appCard()
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions").font(.headline)
            let items: [(date: Date, title: String, amount: Decimal, isIncome: Bool)] =
                (walletIncomes.prefix(3).map { (date: $0.payoutDate, title: $0.title, amount: $0.amount, isIncome: true) } +
                 walletExpenses.prefix(3).map { (date: $0.dueDate, title: $0.title, amount: $0.amount, isIncome: false) })
                .sorted { $0.date > $1.date }

            ForEach(items.prefix(6), id: \.title) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline)
                        Text(item.date, style: .date).font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Text("\(item.isIncome ? "+" : "-")\(symbol)\(item.amount.formatted(.number.precision(.fractionLength(2))))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.isIncome ? AppColors.income : AppColors.expense)
                }
                Divider()
            }
        }
        .padding()
        .appCard()
    }
}
