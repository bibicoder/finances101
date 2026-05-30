import SwiftUI
import SwiftData

struct AddBudgetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editing: CategoryBudget? = nil
    var existingCategories: [String] = []

    @State private var selectedCategory: String = ""
    @State private var limitText: String = ""

    private var isEditing: Bool { editing != nil }
    private var isValid: Bool { !selectedCategory.isEmpty && (Decimal(string: limitText) ?? 0) > 0 }

    private var availableCategories: [Category] {
        CategoryManager.expenseCategories.filter { cat in
            cat.name != "Charity" && cat.name != "Debt" &&
            (isEditing || !existingCategories.contains(cat.name))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section("Category") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableCategories) { cat in
                                    Button {
                                        selectedCategory = cat.name
                                        HapticManager.selection()
                                    } label: {
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedCategory == cat.name
                                                          ? cat.color.opacity(0.2)
                                                          : Color(.systemFill))
                                                    .frame(width: 48, height: 48)
                                                Image(systemName: cat.icon)
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundStyle(selectedCategory == cat.name ? cat.color : .secondary)
                                            }
                                            .overlay(
                                                Circle().stroke(selectedCategory == cat.name ? cat.color : .clear, lineWidth: 2)
                                            )
                                            Text(cat.name)
                                                .font(.caption2)
                                                .foregroundStyle(selectedCategory == cat.name ? .primary : .secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 56)
                                    }
                                    .buttonStyle(.plain)
                                    .scaleEffect(selectedCategory == cat.name ? 1.05 : 1)
                                    .animation(.spring(duration: 0.2), value: selectedCategory)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                } else if let cat = CategoryManager.expenseCategories.first(where: { $0.name == editing?.category }) {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(cat.color.opacity(0.12)).frame(width: 40, height: 40)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(cat.color)
                            }
                            Text(cat.name).font(.subheadline).fontWeight(.semibold)
                        }
                    } header: { Text("Category") }
                }

                Section("Monthly Limit") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $limitText)
                            .keyboardType(.decimalPad)
                        Text("per month")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Budget" : "Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let b = editing else { return }
        selectedCategory = b.category
        limitText = "\(b.monthlyLimit)"
    }

    private func save() {
        guard let limit = Decimal(string: limitText), limit > 0 else { return }

        if let b = editing {
            b.monthlyLimit = limit
        } else {
            let budget = CategoryBudget(category: selectedCategory, monthlyLimit: limit)
            modelContext.insert(budget)
        }

        modelContext.saveWithLogging()
        HapticManager.success()
        dismiss()
    }
}
