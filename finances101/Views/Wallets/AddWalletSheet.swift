import SwiftUI
import SwiftData

struct AddWalletSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]
    @Query private var settings: [AppSettings]

    private var symbol: String { settings.first?.currencySymbol ?? "$" }

    @State private var name = ""
    @State private var type: WalletType = .card
    @State private var initialBalance = ""
    @State private var colorHex = "7C3AED"
    @State private var cryptoChain: CryptoChain = .bitcoin
    @State private var cryptoAddress = ""

    private let colorOptions = ["7C3AED", "16A34A", "EF4444", "F59E0B", "3B82F6", "EC4899", "06B6D4", "84CC16"]

    private var cryptoAddressPlaceholder: String {
        if cryptoChain.isTron { return "Public address (T…)" }
        if cryptoChain.evmRPC != nil { return "Public address (0x…)" }
        return "Public address"
    }

    private var isValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        if type == .crypto {
            return hasName && !cryptoAddress.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return hasName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(type == .crypto ? "e.g., Cold Wallet" : "e.g., Chase Checking", text: $name)
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(WalletType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if type == .crypto {
                    Section {
                        Picker("Coin / Token", selection: $cryptoChain) {
                            ForEach(CryptoChain.allCases, id: \.self) { chain in
                                Text(chain.displayName).tag(chain)
                            }
                        }
                        TextField(cryptoAddressPlaceholder, text: $cryptoAddress)
                            .font(.system(.footnote, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text("Crypto (read-only)")
                    } footer: {
                        Text("Paste the PUBLIC \(cryptoChain.isTron ? "Tron (T…)" : cryptoChain.tokenContract != nil ? "wallet (0x…)" : "")  address only — never a private key or seed phrase. Stablecoins (USDT/USDC) read the token balance at that address. Balance and price update automatically.")
                    }
                } else {
                    Section {
                        HStack {
                            Text(symbol)
                                .foregroundStyle(AppColors.textSecondary)
                            TextField("0.00", text: $initialBalance)
                                .keyboardType(.decimalPad)
                        }
                    } header: {
                        Text("Balance")
                    } footer: {
                        Text("For manual assets (gold, stocks, PayPal, foreign cash) pick type Other or Investment and enter the amount. Use Savings/Investment to keep it out of Safe-to-Spend. You can update the balance anytime.")
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .opacity(colorHex == hex ? 1 : 0)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let isCrypto = type == .crypto
        // Crypto wallets are valued from the chain — manual initial balance stays 0
        let balance = isCrypto ? 0 : (Decimal(userInput: initialBalance) ?? 0)
        let wallet = Wallet(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            initialBalance: balance,
            colorHex: colorHex,
            isDefault: wallets.isEmpty,
            sortOrder: wallets.count
        )
        if isCrypto {
            wallet.cryptoChain = cryptoChain.rawValue
            wallet.cryptoAddress = cryptoAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        modelContext.insert(wallet)
        modelContext.saveWithLogging()
        HapticManager.success()

        if isCrypto {
            // Fetch on-chain balance right away
            Task { @MainActor in
                await CryptoService.refreshAll([wallet])
                modelContext.saveWithLogging()
            }
        }
        dismiss()
    }
}
