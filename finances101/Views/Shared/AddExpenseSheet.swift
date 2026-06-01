import SwiftUI
import SwiftData

private struct SplitRow: Identifiable {
    let id = UUID()
    var category: String
    var amount: String
}

struct AddExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [AppSettings]
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]
    @FocusState private var isAmountFocused: Bool

    @State private var title = ""
    @State private var amount = ""
    @State private var dueDate = Date()
    @State private var category = "Food"
    @State private var type: ExpenseType = .optional
    @State private var selectedWalletId: UUID?
    @State private var status: ExpenseStatus = .planned
    @State private var note = ""
    @State private var isRecurring = false
    @State private var recurringFrequency: RecurringFrequency = .monthly
    @State private var isSplit = false
    @State private var splitRows: [SplitRow] = []
    @State private var showReceiptScanner = false

    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.trimmingCharacters(in: .whitespaces))
    }

    private var splitTotal: Decimal {
        splitRows.compactMap { Decimal(string: $0.amount.trimmingCharacters(in: .whitespaces)) }.reduce(0, +)
    }

    private var splitRemaining: Decimal {
        (parsedAmount ?? 0) - splitTotal
    }

    private var isSplitValid: Bool {
        guard isSplit, let total = parsedAmount, total > 0 else { return true }
        return splitRows.count >= 2 &&
               splitRows.allSatisfy { (Decimal(string: $0.amount) ?? 0) > 0 } &&
               splitTotal == total
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (parsedAmount ?? 0) > 0 &&
        isSplitValid
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
                    if isSplit {
                        splitSection
                    } else {
                        categorySection
                    }
                    detailsSection
                    dateSection
                    typeAndStatusSection
                    if !isSplit { recurringSection }
                    splitToggleSection
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showReceiptScanner = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(AppColors.primaryDeep)
                    }
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
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerView { scannedAmount, scannedTitle in
                    amount = "\(scannedAmount)"
                    if title.isEmpty && !scannedTitle.isEmpty {
                        title = scannedTitle
                    }
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

            if !wallets.isEmpty {
                Divider().padding(.leading)
                HStack {
                    Text("Wallet")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Wallet", selection: $selectedWalletId) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(wallets) { w in
                            Label(w.name, systemImage: w.iconName).tag(Optional(w.id))
                        }
                    }
                    .labelsHidden()
                }
                .padding()
            }
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
    
    private var splitToggleSection: some View {
        Toggle(isOn: $isSplit) {
            Label("Split by Category", systemImage: "arrow.triangle.branch")
        }
        .padding()
        .appCard()
        .onChange(of: isSplit) { _, enabled in
            if enabled {
                let total = parsedAmount ?? 0
                splitRows = [
                    SplitRow(category: category, amount: total > 0 ? "\(total)" : ""),
                    SplitRow(category: "Food", amount: "")
                ]
            } else {
                splitRows = []
            }
        }
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Split by Category")
                    .font(.headline)
                Spacer()
                let rem = splitRemaining
                Text(rem == 0 ? "Balanced" : "\(rem > 0 ? "Remaining" : "Over"): \(currencySymbol)\(abs(rem).formatted(.number.precision(.fractionLength(2))))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(rem == 0 ? AppColors.income : AppColors.expense)
            }

            ForEach($splitRows) { $row in
                HStack(spacing: 12) {
                    Picker("", selection: $row.category) {
                        ForEach(CategoryManager.expenseCategories.map { $0.name }, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 2) {
                        Text(currencySymbol)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                        TextField("0.00", text: $row.amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    if splitRows.count > 2 {
                        Button {
                            splitRows.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(AppColors.expense)
                        }
                    }
                }
                .padding(.vertical, 4)

                Divider()
            }

            Button {
                splitRows.append(SplitRow(category: "Food", amount: ""))
            } label: {
                Label("Add Split", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryDeep)
            }
        }
        .padding()
        .appCard()
    }

    private func saveExpense() {
        guard let amountDecimal = parsedAmount, amountDecimal > 0 else { return }

        if isSplit {
            for row in splitRows {
                guard let splitAmount = Decimal(string: row.amount.trimmingCharacters(in: .whitespaces)),
                      splitAmount > 0 else { continue }
                let entry = ExpenseEntry(
                    title: title,
                    amount: splitAmount,
                    dueDate: dueDate,
                    category: row.category,
                    type: type,
                    status: status,
                    note: note.isEmpty ? nil : note
                )
                modelContext.insert(entry)
            }
        } else {
            var templateId: UUID?
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
                recurringTemplateId: templateId,
                walletId: selectedWalletId
            )
            modelContext.insert(expense)
        }

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
