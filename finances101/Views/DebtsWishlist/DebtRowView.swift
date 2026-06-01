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
                        .foregroundStyle(AppColors.expense)
                    
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
            DebtPaymentSheet(debt: debt, symbol: symbol)
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
    var symbol: String = "$"
    @State private var paymentAmount: String = ""
    @State private var confettiTrigger = 0
    @State private var showCelebration = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text("\(symbol)\(debt.remainingAmount.formatted())")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(symbol)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $paymentAmount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button("Record Payment") {
                        recordPayment()
                    }
                    .disabled(paymentAmount.isEmpty || (Decimal(string: paymentAmount) ?? 0) <= 0)
                }
            }
            .navigationTitle("Pay Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                ConfettiView(trigger: $confettiTrigger)
            }
            .overlay(alignment: .top) {
                if showCelebration {
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debt Crushed!")
                                .font(.system(size: 16, weight: .bold))
                            Text("You paid it off completely")
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

        if debt.remainingAmount <= 0 {
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

#Preview {
    DebtRowView(
        debt: Debt(creditor: "Friend", totalAmount: 2000, paidAmount: 500),
        symbol: "$"
    )
    .padding()
}
