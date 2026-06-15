import SwiftUI
import SwiftData

struct EditWishlistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let item: WishlistItem
    
    @State private var title: String
    @State private var amount: String
    @State private var priority: WishlistPriority
    @State private var status: WishlistStatus
    @State private var category: String
    @State private var note: String
    
    @State private var showDeleteAlert = false
    
    private let categories = ["General", "Electronics", "Clothing", "Home", "Travel", "Vehicle", "Entertainment", "Other"]
    
    init(item: WishlistItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _amount = State(initialValue: "\(item.amount)")
        _priority = State(initialValue: item.priority)
        _status = State(initialValue: item.status)
        _category = State(initialValue: item.category)
        _note = State(initialValue: item.note ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("What do you want?", text: $title)
                    
                    HStack {
                        Text("Price")
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
                
                Section("Priority") {
                    HStack(spacing: 12) {
                        ForEach(WishlistPriority.allCases, id: \.self) { p in
                            Button {
                                priority = p
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: priorityIcon(for: p))
                                        .font(.title2)
                                    Text(p.rawValue)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(priority == p ? priorityColor(for: p).opacity(0.2) : Color.clear)
                                .foregroundStyle(priority == p ? priorityColor(for: p) : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(priority == p ? priorityColor(for: p) : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(WishlistStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
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
                            Label("Delete Item", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Wishlist Item")
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
            .alert("Delete Item?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("This will permanently delete this wishlist item.")
            }
        }
    }
    
    private func priorityIcon(for priority: WishlistPriority) -> String {
        switch priority {
        case .low: return "star"
        case .medium: return "star.leadinghalf.filled"
        case .high: return "star.fill"
        }
    }
    
    private func priorityColor(for priority: WishlistPriority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .yellow
        }
    }
    
    private func saveChanges() {
        guard let amountDecimal = Decimal(userInput: amount) else { return }
        
        item.title = title
        item.amount = amountDecimal
        item.priority = priority
        item.status = status
        item.category = category
        item.note = note.isEmpty ? nil : note
        
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}
