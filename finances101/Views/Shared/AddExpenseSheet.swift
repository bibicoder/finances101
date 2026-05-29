import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]
    @FocusState private var isAmountFocused: Bool
    
    @State private var title = ""
    @State private var amount = ""
    @State private var dueDate = Date()
    @State private var category = "Food"
    @State private var type: ExpenseType = .optional
    @State private var status: ExpenseStatus = .planned
    @State private var note = ""
    @State private var isRecurring = false
    @State private var recurringFrequency: RecurringFrequency = .monthly
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.trimmingCharacters(in: .whitespaces))
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (parsedAmount ?? 0) > 0
    }

    private var amountError: String? {
        guard !amount.isEmpty else { return nil }
        if let v = parsedAmount, v <= 0 { return "Amount must be greater than 0" }
        if parsedAmount == nil { return "Enter a valid number" }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    amountSection
                    categorySection
                    detailsSection
                    dateSection
                    typeAndStatusSection
                    recurringSection
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isAmountFocused = false }
                }
            }
        }
    }
    
    private var amountSection: some View {
        VStack(spacing: 8) {
            Text("Amount")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currencySymbol)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.expense)
                
                TextField("0", text: $amount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isAmountFocused)
            }
            .frame(maxWidth: .infinity)

            if let error = amountError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 24)
        .appCard()
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
            
            CategoryGrid(
                categories: CategoryManager.expenseCategories,
                selected: $category
            )
        }
        .padding()
        .appCard()
    }
    
    private var detailsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Title")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("e.g., Grocery Shopping", text: $title)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            
            Divider().padding(.leading)
            
            HStack {
                Text("Note")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("Optional", text: $note)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
        }
        .appCard()
    }
    
    private var dateSection: some View {
        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
            .padding()
            .appCard()
    }
    
    private var typeAndStatusSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Type", selection: $type) {
                    ForEach(ExpenseType.allCases.filter { $0 != .recurring }, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Status", selection: $status) {
                    ForEach(ExpenseStatus.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .appCard()
    }
    
    private var recurringSection: some View {
        VStack(spacing: 0) {
            Toggle("Repeat", isOn: $isRecurring)
                .padding()
            
            if isRecurring {
                Divider().padding(.leading)
                
                Picker("Frequency", selection: $recurringFrequency) {
                    ForEach(RecurringFrequency.allCases.filter { $0 != .custom }, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                .padding()
            }
        }
        .appCard()
    }
    
    private func saveExpense() {
        guard let amountDecimal = parsedAmount, amountDecimal > 0 else { return }
        
        var templateId: UUID? = nil
        let finalType = isRecurring ? ExpenseType.recurring : type
        
        if isRecurring {
            let template = RecurringTemplate(
                title: title,
                amount: amountDecimal,
                type: .expense,
                frequency: recurringFrequency,
                category: category,
                startDate: dueDate,
                note: note.isEmpty ? nil : note
            )
            modelContext.insert(template)
            templateId = template.id
        }
        
        let expense = ExpenseEntry(
            title: title,
            amount: amountDecimal,
            dueDate: dueDate,
            category: category,
            type: finalType,
            status: status,
            note: note.isEmpty ? nil : note,
            isRecurring: isRecurring,
            recurringTemplateId: templateId
        )
        
        modelContext.insert(expense)
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}

#Preview {
    AddExpenseSheet()
        .modelContainer(for: [
            ExpenseEntry.self,
            RecurringTemplate.self
        ], inMemory: true)
}
