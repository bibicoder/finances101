import SwiftUI
import SwiftData

struct AddDebtSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var creditor = ""
    @State private var totalAmount = ""
    @State private var paidAmount = ""
    @State private var priority = 1
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var note = ""
    
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
                    .disabled(creditor.isEmpty || totalAmount.isEmpty)
                }
            }
        }
    }
    
    private func saveDebt() {
        guard let total = Decimal(string: totalAmount) else { return }
        let paid = Decimal(string: paidAmount) ?? 0
        
        let debt = Debt(
            creditor: creditor,
            totalAmount: total,
            paidAmount: paid,
            priority: priority,
            targetDate: hasTargetDate ? targetDate : nil,
            note: note.isEmpty ? nil : note
        )
        
        modelContext.insert(debt)
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}

#Preview {
    AddDebtSheet()
        .modelContainer(for: Debt.self, inMemory: true)
}
