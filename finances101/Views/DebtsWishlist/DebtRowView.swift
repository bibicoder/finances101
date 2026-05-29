import SwiftUI
import SwiftData

struct DebtRowView: View {
    let debt: Debt
    let symbol: String
    
    @Environment(\.modelContext) private var modelContext
    @State private var showPaymentSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.creditor)
                        .font(.headline)
                    
                    if let note = debt.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(symbol)\(debt.remainingAmount.formatted())")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.yellow)
                    
                    Text("of \(symbol)\(debt.totalAmount.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            ProgressView(value: debt.progressPercentage, total: 100)
                .tint(.green)
            
            HStack {
                Text("\(Int(debt.progressPercentage))% paid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let targetDate = debt.targetDate {
                    Text(targetDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button("Pay") {
                    showPaymentSheet = true
                }
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button {
                showPaymentSheet = true
            } label: {
                Label("Make Payment", systemImage: "dollarsign.circle")
            }
            
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showPaymentSheet) {
            DebtPaymentSheet(debt: debt)
        }
        .sheet(isPresented: $showEditSheet) {
            EditDebtSheet(debt: debt)
        }
        .confirmationDialog("Delete \"\(debt.creditor)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(debt)
                modelContext.saveWithLogging()
            }
        } message: {
            Text("This will permanently delete this debt.")
        }
    }
}

struct DebtPaymentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let debt: Debt
    @State private var paymentAmount: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text("$\(debt.remainingAmount.formatted())")
                            .foregroundStyle(.secondary)
                    }
                    
                    TextField("Payment Amount", text: $paymentAmount)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button("Record Payment") {
                        recordPayment()
                    }
                    .disabled(paymentAmount.isEmpty)
                }
            }
            .navigationTitle("Pay Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func recordPayment() {
        guard let amount = Decimal(string: paymentAmount) else { return }
        let actualPayment = min(amount, debt.remainingAmount)
        debt.paidAmount += actualPayment
        
        let expense = ExpenseEntry(
            title: "Debt Payment: \(debt.creditor)",
            amount: actualPayment,
            dueDate: Date(),
            category: "Debt",
            type: .mandatory,
            status: .paid,
            isDebtPayment: true
        )
        modelContext.insert(expense)
        
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}

#Preview {
    DebtRowView(
        debt: Debt(creditor: "Friend", totalAmount: 2000, paidAmount: 500),
        symbol: "$"
    )
    .padding()
}
