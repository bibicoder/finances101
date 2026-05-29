import SwiftUI
import SwiftData

struct AddIncomeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]
    @FocusState private var isAmountFocused: Bool
    
    @State private var title = ""
    @State private var amount = ""
    @State private var earnedDate = Date()
    @State private var payoutDate = Date()
    @State private var status: IncomeStatus = .earned
    @State private var category = "Salary"
    @State private var note = ""
    @State private var isRecurring = false
    @State private var recurringFrequency: RecurringFrequency = .monthly
    
    private var charityPercentage: Double {
        settings.first?.charityPercentage ?? 25.0
    }
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    amountSection
                    categorySection
                    detailsSection
                    dateSection
                    statusSection
                    recurringSection
                    charityPreview
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Add Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveIncome()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || amount.isEmpty)
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
                    .foregroundStyle(AppColors.primaryDeep)
                
                TextField("0", text: $amount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isAmountFocused)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 24)
        .appCard()
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
            
            CategoryGrid(
                categories: CategoryManager.incomeCategories,
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
                TextField("e.g., Monthly Salary", text: $title)
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
        VStack(spacing: 0) {
            DatePicker("Earned Date", selection: $earnedDate, displayedComponents: .date)
                .padding()
            
            Divider().padding(.leading)
            
            DatePicker("Payout Date", selection: $payoutDate, displayedComponents: .date)
                .padding()
        }
        .appCard()
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
            
            Picker("Status", selection: $status) {
                ForEach(IncomeStatus.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
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
    
    @ViewBuilder
    private var charityPreview: some View {
        if let amountDecimal = Decimal(string: amount), amountDecimal > 0, charityPercentage > 0 {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(AppColors.charity)
                
                Text("Charity (\(Int(charityPercentage))%)")
                
                Spacer()
                
                Text("\(currencySymbol)\((amountDecimal * Decimal(charityPercentage / 100)).formatted())")
                    .foregroundStyle(AppColors.charity)
                    .fontWeight(.semibold)
            }
            .padding()
            .background(AppColors.charity.opacity(0.1))
            .appCard()
        }
    }
    
    private func saveIncome() {
        guard let amountDecimal = Decimal(string: amount) else { return }
        
        var templateId: UUID? = nil
        
        if isRecurring {
            let template = RecurringTemplate(
                title: title,
                amount: amountDecimal,
                type: .income,
                frequency: recurringFrequency,
                category: category,
                startDate: earnedDate,
                note: note.isEmpty ? nil : note
            )
            modelContext.insert(template)
            templateId = template.id
        }
        
        let income = IncomeEntry(
            title: title,
            amount: amountDecimal,
            earnedDate: earnedDate,
            payoutDate: payoutDate,
            status: status,
            category: category,
            note: note.isEmpty ? nil : note,
            isRecurring: isRecurring,
            recurringTemplateId: templateId
        )
        
        modelContext.insert(income)
        
        if status == .paid {
            let accrual = CharityAccrual(
                date: payoutDate,
                baseAmount: amountDecimal,
                percentage: charityPercentage,
                linkedIncomeId: income.id,
                note: "From: \(title)"
            )
            modelContext.insert(accrual)
        }
        
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}

#Preview {
    AddIncomeSheet()
        .modelContainer(for: [
            IncomeEntry.self,
            CharityAccrual.self,
            RecurringTemplate.self,
            AppSettings.self
        ], inMemory: true)
}
