import SwiftUI

struct CategoryRulesView: View {
    @State private var customRules: [CustomKeywordStore.Rule] = []
    @State private var showAddSheet = false

    private let categories = CategoryManager.expenseCategories.map { $0.name }.sorted()

    var body: some View {
        List {
            // Custom rules section
            if !customRules.isEmpty {
                Section {
                    ForEach(customRules) { rule in
                        HStack(spacing: 12) {
                            Image(systemName: "tag.fill")
                                .font(.caption)
                                .foregroundStyle(AppColors.primaryDeep)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.keyword)
                                    .font(.subheadline.weight(.medium))
                                Text("→ \(rule.category)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            CustomKeywordStore.shared.remove(id: customRules[i].id)
                        }
                        customRules.remove(atOffsets: indexSet)
                    }
                } header: {
                    Text("Custom Rules")
                } footer: {
                    Text("Custom rules are checked first and override built-in ones. Swipe to delete.")
                }
            }

            // Built-in preview (read-only)
            Section {
                builtInRow("gas, fuel, chevron", category: "Transport")
                builtInRow("grocery, whole foods, kroger", category: "Food")
                builtInRow("rent, mortgage, lease", category: "Housing")
                builtInRow("netflix, spotify, hulu", category: "Subscriptions")
                builtInRow("insurance, geico, state farm", category: "Insurance")
                builtInRow("gym, planet fitness, equinox", category: "Health")
                builtInRow("amazon, target, bestbuy", category: "Shopping")
                builtInRow("doctor, dentist, pharmacy", category: "Health")
                builtInRow("school, tuition, udemy", category: "Education")
                builtInRow("electric, internet, comcast", category: "Utilities")
                builtInRow("charity, donation, tithe", category: "Charity")
            } header: {
                Text("Built-in Rules (read-only)")
            }
        }
        .navigationTitle("Auto-Categorization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear { customRules = CustomKeywordStore.shared.load() }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            customRules = CustomKeywordStore.shared.load()
        }) {
            AddKeywordRuleSheet(categories: categories)
        }
    }

    private func builtInRow(_ keywords: String, category: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(keywords)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                Text("→ \(category)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Add Rule Sheet

private struct AddKeywordRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [String]

    @State private var keyword = ""
    @State private var selectedCategory = "Food"
    @FocusState private var keywordFocused: Bool

    private var isValid: Bool {
        !keyword.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. whole foods, costco, aldi", text: $keyword)
                        .focused($keywordFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Keyword")
                } footer: {
                    Text("If any expense title contains this word, it gets this category.")
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Add Rule")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { keywordFocused = true }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        CustomKeywordStore.shared.add(
                            keyword: keyword.trimmingCharacters(in: .whitespaces),
                            category: selectedCategory
                        )
                        HapticManager.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    NavigationStack {
        CategoryRulesView()
    }
}
