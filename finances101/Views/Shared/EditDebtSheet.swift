import SwiftUI
import SwiftData

struct EditDebtSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let debt: Debt
    
    @State private var creditor: String
    @State private var totalAmount: String
    @State private var paidAmount: String
    @State private var interestRate: String
    @State private var minimumPayment: String
    @State private var priority: Int
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var note: String

    @State private var showDeleteAlert = false

    init(debt: Debt) {
        self.debt = debt
        _creditor = State(initialValue: debt.creditor)
        _totalAmount = State(initialValue: "\(debt.totalAmount)")
        _paidAmount = State(initialValue: "\(debt.paidAmount)")
        _interestRate = State(initialValue: debt.interestRate.map { "\($0)" } ?? "")
        _minimumPayment = State(initialValue: debt.minimumPayment.map { "\($0)" } ?? "")
        _priority = State(initialValue: debt.priority)
        _hasTargetDate = State(initialValue: debt.targetDate != nil)
        _targetDate = State(initialValue: debt.targetDate ?? Date())
        _note = State(initialValue: debt.note ?? "")
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
                
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Debt", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(creditor.isEmpty || totalAmount.isEmpty)
                }
            }
            .alert("Delete Debt?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteDebt()
                }
            } message: {
                Text("This will permanently delete this debt.")
            }
        }
    }
    
    private func saveChanges() {
        guard let total = Decimal(string: totalAmount) else { return }
        let paid = Decimal(string: paidAmount) ?? 0
        
        debt.creditor = creditor
        debt.totalAmount = total
        debt.paidAmount = paid
        debt.interestRate = Double(interestRate)
        debt.minimumPayment = Decimal(string: minimumPayment)
        debt.priority = priority
        debt.targetDate = hasTargetDate ? targetDate : nil
        debt.note = note.isEmpty ? nil : note
        
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
    
    private func deleteDebt() {
        modelContext.delete(debt)
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}
