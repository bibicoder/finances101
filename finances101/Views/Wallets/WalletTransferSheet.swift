import SwiftUI
import SwiftData

struct WalletTransferSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let wallets: [Wallet]

    @State private var fromWallet: Wallet?
    @State private var toWallet: Wallet?
    @State private var amount = ""
    @State private var date = Date()
    @State private var note = ""

    private var isValid: Bool {
        guard let from = fromWallet, let to = toWallet else { return false }
        return from.id != to.id && (Decimal(userInput: amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("From") {
                    Picker("From Wallet", selection: $fromWallet) {
                        Text("Select").tag(Optional<Wallet>.none)
                        ForEach(wallets) { w in
                            Label(w.name, systemImage: w.iconName).tag(Optional(w))
                        }
                    }
                }

                Section("To") {
                    Picker("To Wallet", selection: $toWallet) {
                        Text("Select").tag(Optional<Wallet>.none)
                        ForEach(wallets.filter { $0.id != fromWallet?.id }) { w in
                            Label(w.name, systemImage: w.iconName).tag(Optional(w))
                        }
                    }
                }

                Section("Amount") {
                    HStack {
                        Text("$").foregroundStyle(AppColors.textSecondary)
                        TextField("0.00", text: $amount).keyboardType(.decimalPad)
                    }
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transfer") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let from = fromWallet, let to = toWallet,
              let amt = Decimal(userInput: amount), amt > 0 else { return }
        let transfer = WalletTransfer(
            fromWalletId: from.id,
            toWalletId: to.id,
            amount: amt,
            date: date,
            note: note.isEmpty ? nil : note
        )
        modelContext.insert(transfer)
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}
