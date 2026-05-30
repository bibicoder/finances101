import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryBudget.category) private var budgets: [CategoryBudget]
    @Query(sort: \ExpenseEntry.dueDate, order: .reverse) private var expenses: [ExpenseEntry]
    @Query private var settings: [AppSettings]

    @State private var selectedMonth = Date()
    @State private var showAddBudget = false
    @State private var editingBudget: CategoryBudget?

    private var symbol: String { settings.first?.currencySymbol ?? "$" }
    private var activeBudgets: [CategoryBudget] { budgets.filter(\.isActive) }

    private var monthExpenses: [ExpenseEntry] {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return [] }
        return expenses.filter { $0.dueDate >= start && $0.dueDate <= end && $0.status == .paid && !$0.isDebtPayment }
    }

    private var spentByCategory: [String: Decimal] {
        monthExpenses.reduce(into: [:]) { dict, e in
            dict[e.category, default: 0] += e.amount
        }
    }

    private var totalBudget: Decimal { activeBudgets.reduce(Decimal(0)) { $0 + $1.monthlyLimit } }
    private var totalSpent: Decimal {
        activeBudgets.reduce(Decimal(0)) { acc, b in acc + (spentByCategory[b.category] ?? 0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeBudgets.isEmpty {
                    emptyState
                } else {
                    budgetList
                }
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddBudget = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetSheet(existingCategories: activeBudgets.map(\.category))
            }
            .sheet(item: $editingBudget) { budget in
                AddBudgetSheet(editing: budget, existingCategories: activeBudgets.map(\.category))
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No budgets yet",
            systemImage: "chart.bar.fill",
            description: Text("Set monthly limits per category to track spending")
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddBudget = true } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
    }

    // MARK: Budget List

    private var budgetList: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthNavigator
                summaryCard
                budgetRows
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.left").font(.title3).foregroundStyle(AppColors.primaryDeep)
            }
            Spacer()
            Text(selectedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
            Spacer()
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.right").font(.title3).foregroundStyle(AppColors.primaryDeep)
            }
        }
        .padding(.horizontal, 4)
    }

    private var summaryCard: some View {
        let remaining = totalBudget - totalSpent
        let usedPct = totalBudget > 0 ? Double(truncating: (totalSpent / totalBudget * 100) as NSDecimalNumber) : 0
        let overBudget = totalSpent > totalBudget

        return VStack(spacing: 12) {
            HStack(spacing: 0) {
                summaryCell("Budget", value: "\(symbol)\(totalBudget.formatted(.number.precision(.fractionLength(0))))", color: AppColors.primaryLight)
                Divider().frame(height: 36)
                summaryCell("Spent", value: "\(symbol)\(totalSpent.formatted(.number.precision(.fractionLength(0))))", color: overBudget ? AppColors.expense : .primary)
                Divider().frame(height: 36)
                summaryCell("Left", value: "\(symbol)\(abs(remaining).formatted(.number.precision(.fractionLength(0))))", color: overBudget ? AppColors.expense : AppColors.income)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemFill))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressColor(pct: usedPct))
                        .frame(width: min(geo.size.width * CGFloat(usedPct / 100), geo.size.width), height: 10)
                        .animation(.spring(duration: 0.6), value: usedPct)
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(Int(usedPct))% of total budget used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if overBudget {
                    Label("Over budget", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.expense)
                }
            }
        }
        .padding()
        .appCard()
    }

    private func summaryCell(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var budgetRows: some View {
        VStack(spacing: 0) {
            ForEach(activeBudgets) { budget in
                let spent = spentByCategory[budget.category] ?? 0
                let pct = budget.monthlyLimit > 0
                    ? Double(truncating: (spent / budget.monthlyLimit * 100) as NSDecimalNumber)
                    : 0

                BudgetRow(budget: budget, spent: spent, pct: pct, symbol: symbol)
                    .contentShape(Rectangle())
                    .onTapGesture { editingBudget = budget }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(budget)
                            modelContext.saveWithLogging()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                if budget.id != activeBudgets.last?.id {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .appCard()
    }

    private func progressColor(pct: Double) -> Color {
        switch pct {
        case 100...: return AppColors.expense
        case 80..<100: return .orange
        case 60..<80:  return .yellow
        default:       return AppColors.income
        }
    }
}

// MARK: - Budget Row

private struct BudgetRow: View {
    let budget: CategoryBudget
    let spent: Decimal
    let pct: Double
    let symbol: String

    private var cat: Category { CategoryManager.expenseCategory(for: budget.category) }
    private var isOver: Bool { spent > budget.monthlyLimit }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(cat.color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: cat.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(cat.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.category)
                        .font(.subheadline).fontWeight(.semibold)
                    Text("\(symbol)\(spent.formatted(.number.precision(.fractionLength(0)))) of \(symbol)\(budget.monthlyLimit.formatted(.number.precision(.fractionLength(0))))")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                if isOver {
                    Label("Over", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppColors.expense)
                        .clipShape(Capsule())
                } else {
                    Text("\(Int(pct))%")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(pct >= 80 ? .orange : .secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(cat.color.opacity(0.1)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(rowProgressColor)
                        .frame(width: min(geo.size.width * CGFloat(min(pct, 100)) / 100, geo.size.width), height: 6)
                        .animation(.spring(duration: 0.5), value: pct)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var rowProgressColor: Color {
        isOver ? AppColors.expense : (pct >= 80 ? .orange : cat.color)
    }
}
