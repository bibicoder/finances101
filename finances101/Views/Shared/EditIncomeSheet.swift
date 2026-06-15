import SwiftUI
import SwiftData

struct EditIncomeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]
    
    let income: IncomeEntry
    
    @State private var title: String
    @State private var amount: String
    @State private var earnedDate: Date
    @State private var payoutDate: Date
    @State private var status: IncomeStatus
    @State private var category: String
    @State private var note: String
    
    @State private var showDeleteAlert = false
    
    private let categories = ["General", "Salary", "Freelance", "Business", "Investment", "Gift", "Other"]
    
    private var charityPercentage: Double {
        settings.first?.charityPercentage ?? 25.0
    }
    
    init(income: IncomeEntry) {
        self.income = income
        _title = State(initialValue: income.title)
        _amount = State(initialValue: "\(income.amount)")
        _earnedDate = State(initialValue: income.earnedDate)
        _payoutDate = State(initialValue: income.payoutDate)
        _status = State(initialValue: income.status)
        _category = State(initialValue: income.category)
        _note = State(initialValue: income.note ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                
                Section("Dates") {
                    DatePicker("Earned Date", selection: $earnedDate, displayedComponents: .date)
                    DatePicker("Payout Date", selection: $payoutDate, displayedComponents: .date)
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(IncomeStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let amountDecimal = Decimal(userInput: amount), amountDecimal > 0 {
                    Section {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.purple)
                            Text("Charity (\(Int(charityPercentage))%)")
                            Spacer()
                            Text("$\((amountDecimal * Decimal(charityPercentage) / 100).formatted())")
                                .foregroundStyle(.purple)
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Income", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
            }
            .alert("Delete Income?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteIncome()
                }
            } message: {
                Text("This will permanently delete this income entry.")
            }
        }
    }
    
    private func saveChanges() {
        guard let amountDecimal = Decimal(userInput: amount) else { return }
        
        let wasNotPaid = income.status != .paid
        let nowPaid = status == .paid
        
        income.title = title
        income.amount = amountDecimal
        income.earnedDate = earnedDate
        income.payoutDate = payoutDate
        income.status = status
        income.category = category
        income.note = note.isEmpty ? nil : note
        
        CharityManager.createAccrualIfNeeded(for: income, in: modelContext)
        
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
    
    private func deleteIncome() {
        modelContext.delete(income)
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}
