import SwiftUI
import SwiftData

struct WalletsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]
    @Query private var incomes: [IncomeEntry]
    @Query private var expenses: [ExpenseEntry]
    @Query(sort: \WalletTransfer.date, order: .reverse) private var transfers: [WalletTransfer]
    @Query private var settings: [AppSettings]

    @State private var showAddWallet = false
    @State private var showTransfer = false
    @State private var selectedWallet: Wallet?

    private var currencySymbol: String { settings.first?.currencySymbol ?? "$" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if wallets.isEmpty {
                        emptyState
                    } else {
                        totalCard
                        walletGrid
                        if !transfers.isEmpty {
                            transfersSection
                        }
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Wallets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if wallets.count >= 2 {
                            Button {
                                showTransfer = true
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                        }
                        Button {
                            showAddWallet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    .foregroundStyle(AppColors.primaryDeep)
                }
            }
            .sheet(isPresented: $showAddWallet) {
                AddWalletSheet()
            }
            .sheet(isPresented: $showTransfer) {
                // Crypto wallets are read-only (tracked by address) — no manual transfers
                WalletTransferSheet(wallets: wallets.filter { !$0.isCrypto })
            }
            .sheet(item: $selectedWallet) { wallet in
                WalletDetailSheet(wallet: wallet, incomes: incomes, expenses: expenses, symbol: currencySymbol)
            }
            .task {
                // Refresh on-chain balances + prices for crypto wallets
                await CryptoService.refreshAll(wallets)
                modelContext.saveWithLogging()
            }
            .refreshable {
                await CryptoService.refreshAll(wallets)
                modelContext.saveWithLogging()
            }
        }
    }

    private var totalBalance: Decimal {
        wallets.reduce(Decimal(0)) { $0 + walletBalance($1) }
    }

    private func walletBalance(_ wallet: Wallet) -> Decimal {
        WalletBalanceCalculator.balance(of: wallet, incomes: incomes, expenses: expenses, transfers: transfers)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primaryDeep.opacity(0.3))
            Text("No Wallets Yet")
                .font(.title2.weight(.bold))
            Text("Add your accounts — cash, cards, savings — to track balances separately.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showAddWallet = true
            } label: {
                Label("Add First Wallet", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.primaryDeep)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }

    private var totalCard: some View {
        VStack(spacing: 4) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Text("\(totalBalance >= 0 ? "" : "-")\(currencySymbol)\(abs(totalBalance).formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text("\(wallets.count) wallets")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppColors.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var walletGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(wallets) { wallet in
                WalletCard(
                    wallet: wallet,
                    balance: walletBalance(wallet),
                    symbol: currencySymbol
                )
                .onTapGesture { selectedWallet = wallet }
            }
        }
    }

    private var transfersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transfers")
                .font(.headline)
            ForEach(transfers.prefix(5)) { transfer in
                HStack {
                    let fromName = wallets.first(where: { $0.id == transfer.fromWalletId })?.name ?? "?"
                    let toName = wallets.first(where: { $0.id == transfer.toWalletId })?.name ?? "?"
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(fromName) → \(toName)")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(transfer.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Text("\(currencySymbol)\(transfer.amount.formatted(.number.precision(.fractionLength(2))))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryDeep)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding()
        .appCard()
    }
}

// MARK: - Wallet Card

private struct WalletCard: View {
    let wallet: Wallet
    let balance: Decimal
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: wallet.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                Spacer()
                if wallet.isDefault {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer()
            Text(wallet.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            Text("\(balance >= 0 ? "" : "-")\(symbol)\(abs(balance).formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if wallet.isCrypto, let amount = wallet.cryptoAmount, let chain = wallet.cryptoChain {
                Text("\(amount.formatted(.number.precision(.fractionLength(0...6)))) \(chain)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(Color(hex: wallet.colorHex))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
