import SwiftUI
import SwiftData

struct AddWishlistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var amount = ""
    @State private var priority: WishlistPriority = .medium
    @State private var category = "General"
    @State private var note = ""
    
    private let categories = ["General", "Electronics", "Clothing", "Home", "Travel", "Vehicle", "Entertainment", "Other"]
    
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
                
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add to Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
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
    
    private func saveItem() {
        guard let amountDecimal = Decimal(string: amount) else { return }
        
        let item = WishlistItem(
            title: title,
            amount: amountDecimal,
            priority: priority,
            category: category,
            note: note.isEmpty ? nil : note
        )
        
        modelContext.insert(item)
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}

#Preview {
    AddWishlistSheet()
        .modelContainer(for: WishlistItem.self, inMemory: true)
}
