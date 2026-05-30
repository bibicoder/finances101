import SwiftUI
import SwiftData

struct AddDebtSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var creditor = ""
    @State private var totalAmount = ""
    @State private var paidAmount = ""
    @State private var interestRate = ""
    @State private var minimumPayment = ""
    @State private var priority = 1
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var note = ""

    private var parsedTotal: Decimal? {
        Decimal(string: totalAmount.trimmingCharacters(in: .whitespaces))
    }

    private var parsedPaid: Decimal {
        Decimal(string: paidAmount.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var isFormValid: Bool {
        !creditor.trimmingCharacters(in: .whitespaces).isEmpty &&
        (parsedTotal ?? 0) > 0 &&
        parsedPaid <= (parsedTotal ?? 0)
    }

    private var paidAmountError: String? {
        guard !paidAmount.isEmpty, let total = parsedTotal else { return nil }
        if parsedPaid > total { return "Already paid can't exceed total amount" }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Who do you owe?", text: $creditor)
                    
                    HStack {
                        Text("Total Amount")
                        Spacer()
                        TextField("0.00", text: $totalAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Already Paid")
                        Spacer()
                        TextField("0.00", text: $paidAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    if let error = paidAmountError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    HStack {
                        Text("Interest Rate (APR)")
                        Spacer()
                        TextField("0.0", text: $interestRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Min. Monthly Payment")
                        Spacer()
                        TextField("0.00", text: $minimumPayment)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                } header: {
                    Text("For Payoff Calculator")
                } footer: {
                    Text("Optional — used to calculate exact payoff dates and interest paid.")
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(3)
                        Text("Medium").tag(2)
                        Text("High").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Target Date") {
                    Toggle("Set Target Date", isOn: $hasTargetDate)
                    
                    if hasTargetDate {
                        DatePicker("Pay by", selection: $targetDate, displayedComponents: .date)
                    }
                }
                
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDebt()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private func saveDebt() {
        guard let total = parsedTotal, total > 0, parsedPaid <= total else { return }
        let paid = parsedPaid
        
        let debt = Debt(
            creditor: creditor,
            totalAmount: total,
            paidAmount: paid,
            priority: priority,
            targetDate: hasTargetDate ? targetDate : nil,
            note: note.isEmpty ? nil : note,
            interestRate: Double(interestRate),
            minimumPayment: Decimal(string: minimumPayment)
        )
        
        modelContext.insert(debt)
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}

#Preview {
    AddDebtSheet()
        .modelContainer(for: Debt.self, inMemory: true)
}
