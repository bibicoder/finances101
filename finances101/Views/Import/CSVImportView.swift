import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private struct ImportRow: Identifiable {
    let id = UUID()
    let transaction: CSVTransaction
    var category: String
    var include: Bool
}

struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    @State private var rows: [ImportRow] = []
    @State private var isImporting = false
    @State private var importDone = false
    @State private var importedCount = 0
    @State private var parseError: String?

    private var selectedCount: Int { rows.filter { $0.include }.count }
    private var totalAmount: Decimal { rows.filter { $0.include }.reduce(0) { $0 + $1.transaction.amount } }

    var body: some View {
        NavigationStack {
            Group {
                if rows.isEmpty {
                    emptyState
                } else if importDone {
                    successState
                } else {
                    previewList
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !rows.isEmpty && !importDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import \(selectedCount)") {
                            importSelected()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedCount == 0)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFilePick(result)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primaryDeep.opacity(0.3))

            VStack(spacing: 8) {
                Text("Import Bank Statement")
                    .font(.title2.weight(.bold))
                Text("Supports Chase, Bank of America, Wells Fargo CSV exports. Other banks may work with generic format.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let error = parseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColors.expense)
                    .padding(.horizontal)
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Choose CSV File", systemImage: "folder.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primaryDeep)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var successState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.income)
            Text("Imported \(importedCount) transactions")
                .font(.title2.weight(.bold))
            Button("Done") { dismiss() }
                .font(.headline)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewList: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedCount) of \(rows.count) selected")
                        .font(.subheadline.weight(.semibold))
                    Text("Total: \(totalAmount.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Button(selectedCount == rows.count ? "Deselect All" : "Select All") {
                    let all = selectedCount == rows.count
                    for i in rows.indices { rows[i].include = !all }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.primaryDeep)
            }
            .padding()
            .background(AppColors.surface)

            Divider()

            List {
                ForEach($rows) { $row in
                    HStack(spacing: 12) {
                        Toggle("", isOn: $row.include)
                            .labelsHidden()

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.transaction.description)
                                .font(.subheadline)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text(row.transaction.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                Text("·")
                                    .foregroundStyle(AppColors.textSecondary)
                                Picker("", selection: $row.category) {
                                    ForEach(CategoryManager.expenseCategories.map { $0.name }, id: \.self) {
                                        Text($0).tag($0)
                                    }
                                }
                                .labelsHidden()
                                .font(.caption)
                            }
                        }

                        Spacer()

                        Text("\(row.transaction.isCredit ? "+" : "-")$\(row.transaction.amount.formatted(.number.precision(.fractionLength(2))))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(row.transaction.isCredit ? AppColors.income : AppColors.expense)
                    }
                    .listRowBackground(AppColors.surface)
                    .opacity(row.include ? 1 : 0.4)
                }
            }
            .listStyle(.plain)
        }
    }

    private func handleFilePick(_ result: Result<[URL], Error>) {
        parseError = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                parseError = "Permission denied to access this file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let parsed = CSVImportParser.parse(csv: content)
                if parsed.isEmpty {
                    parseError = "No transactions found. Check the file format."
                } else {
                    rows = parsed.map {
                        ImportRow(
                            transaction: $0,
                            category: $0.rawCategory.isEmpty ? CSVImportParser.autoCategory(for: $0.description) : $0.rawCategory,
                            include: true
                        )
                    }
                }
            } catch {
                parseError = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            parseError = error.localizedDescription
        }
    }

    private func importSelected() {
        let selected = rows.filter { $0.include }
        var count = 0
        for row in selected {
            if row.transaction.isCredit {
                let entry = IncomeEntry(
                    title: row.transaction.description,
                    amount: row.transaction.amount,
                    earnedDate: row.transaction.date,
                    payoutDate: row.transaction.date,
                    status: .paid,
                    category: row.category
                )
                modelContext.insert(entry)
            } else {
                let entry = ExpenseEntry(
                    title: row.transaction.description,
                    amount: row.transaction.amount,
                    dueDate: row.transaction.date,
                    category: row.category,
                    type: .optional,
                    status: .paid
                )
                modelContext.insert(entry)
            }
            count += 1
        }
        modelContext.saveWithLogging()
        HapticManager.success()
        importedCount = count
        importDone = true
    }
}

#Preview {
    CSVImportView()
        .modelContainer(for: [ExpenseEntry.self, IncomeEntry.self], inMemory: true)
}
