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

    private let colorOptions = ["7C3AED", "16A34A", "EF4444", "F59E0B", "3B82F6", "EC4899", "06B6D4", "84CC16"]

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g., Chase Checking", text: $name)
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(WalletType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Initial Balance") {
                    HStack {
                        Text(symbol)
                            .foregroundStyle(AppColors.textSecondary)
                        TextField("0.00", text: $initialBalance)
                            .keyboardType(.decimalPad)
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
        let balance = Decimal(string: initialBalance.trimmingCharacters(in: .whitespaces)) ?? 0
        let wallet = Wallet(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            initialBalance: balance,
            colorHex: colorHex,
            isDefault: wallets.isEmpty,
            sortOrder: wallets.count
        )
        modelContext.insert(wallet)
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}
