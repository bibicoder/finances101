import SwiftUI
import SwiftData

struct AddCharityPaymentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]
    @Query private var accruals: [CharityAccrual]
    @Query private var payments: [CharityPayment]
    
    @State private var amount = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var confettiTrigger = 0
    @State private var showCelebration = false
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    private var currentOwed: Decimal {
        let totalAccrued = accruals.reduce(0) { $0 + $1.accruedAmount }
        let totalPaid = payments.reduce(0) { $0 + $1.amount }
        return totalAccrued - totalPaid
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.trimmingCharacters(in: .whitespaces))
    }

    private var isFormValid: Bool {
        (parsedAmount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Current Obligation")
                        Spacer()
                        Text("\(currencySymbol)\(currentOwed.formatted())")
                            .foregroundStyle(.purple)
                            .fontWeight(.semibold)
                    }
                }
                
                Section("Payment Details") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Quick Amounts") {
                    HStack(spacing: 12) {
                        QuickAmountButton(amount: currentOwed * 0.1, symbol: currencySymbol, label: "10%") {
                            self.amount = "\(currentOwed * 0.1)"
                        }
                        
                        QuickAmountButton(amount: currentOwed * 0.25, symbol: currencySymbol, label: "25%") {
                            self.amount = "\(currentOwed * 0.25)"
                        }
                        
                        QuickAmountButton(amount: currentOwed, symbol: currencySymbol, label: "Full") {
                            self.amount = "\(currentOwed)"
                        }
                    }
                }
                
                Section("Note") {
                    TextField("Optional note (e.g., recipient)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Charity Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePayment() }
                        .disabled(!isFormValid)
                }
            }
            .overlay {
                ConfettiView(trigger: $confettiTrigger)
            }
            .overlay(alignment: .top) {
                if showCelebration {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.charity)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Good Karma!")
                                .font(.system(size: 16, weight: .bold))
                            Text("Obligation fully cleared")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.5), value: showCelebration)
        }
    }
    
    private func savePayment() {
        guard let amountDecimal = parsedAmount, amountDecimal > 0 else { return }
        let obligationCleared = amountDecimal >= currentOwed

        let payment = CharityPayment(
            date: date,
            amount: amountDecimal,
            note: note.isEmpty ? nil : note
        )

        modelContext.insert(payment)
        modelContext.saveWithLogging()
        HapticManager.success()

        if obligationCleared {
            confettiTrigger += 1
            showCelebration = true
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                dismiss()
            }
        } else {
            dismiss()
        }
    }
}

struct QuickAmountButton: View {
    let amount: Decimal
    let symbol: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("\(symbol)\(amount.formatted())")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.1))
            .foregroundStyle(.purple)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddCharityPaymentSheet()
        .modelContainer(for: [
            CharityAccrual.self,
            CharityPayment.self,
            AppSettings.self
        ], inMemory: true)
}
