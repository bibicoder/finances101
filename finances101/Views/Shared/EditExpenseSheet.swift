import SwiftUI
import SwiftData

struct EditExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let expense: ExpenseEntry
    
    @State private var title: String
    @State private var amount: String
    @State private var dueDate: Date
    @State private var category: String
    @State private var type: ExpenseType
    @State private var status: ExpenseStatus
    @State private var note: String
    
    @State private var showDeleteAlert = false
    
    private let categories = ["General", "Housing", "Utilities", "Food", "Transport", "Entertainment", "Health", "Education", "Family", "Business", "Debt", "Other"]
    
    init(expense: ExpenseEntry) {
        self.expense = expense
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: "\(expense.amount)")
        _dueDate = State(initialValue: expense.dueDate)
        _category = State(initialValue: expense.category)
        _type = State(initialValue: expense.type)
        _status = State(initialValue: expense.status)
        _note = State(initialValue: expense.note ?? "")
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
                
                Section("Date") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(ExpenseType.allCases.filter { $0 != .recurring }, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ExpenseStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Expense", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Expense")
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
            .alert("Delete Expense?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteExpense()
                }
            } message: {
                Text("This will permanently delete this expense entry.")
            }
        }
    }
    
    private func saveChanges() {
        guard let amountDecimal = Decimal(string: amount) else { return }
        
        expense.title = title
        expense.amount = amountDecimal
        expense.dueDate = dueDate
        expense.category = category
        expense.type = type
        expense.status = status
        expense.note = note.isEmpty ? nil : note
        
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
    
    private func deleteExpense() {
        modelContext.delete(expense)
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}
