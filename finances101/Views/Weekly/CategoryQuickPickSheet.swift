import SwiftUI

/// Expense parsed from quick entry, waiting for the user to confirm a category.
struct PendingQuickExpense: Identifiable {
    let id = UUID()
    let title: String
    let amount: Decimal
    let suggestedCategory: String
    let dueDate: Date
}

/// Compact half-sheet shown right after quick entry ("Gas 80" + Enter).
/// Tap a category → saved with it. Swipe down without picking → saved with the
/// auto-suggested category (handled by the caller in onDismiss).
struct CategoryQuickPickSheet: View {
    let pending: PendingQuickExpense
    let symbol: String
    let onPick: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pending.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Pick a category, or swipe down for auto")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text("-\(symbol)\(pending.amount.formatted(.number.precision(.fractionLength(2))))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppColors.expense)
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(CategoryManager.expenseCategories) { category in
                    chip(for: category)
                }
            }
            .padding(.horizontal, 16)

            Button {
                onPick(pending.suggestedCategory)
            } label: {
                Text("Keep \"\(pending.suggestedCategory)\"")
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }

    private func chip(for category: Category) -> some View {
        let isSuggested = category.name == pending.suggestedCategory
        return Button {
            HapticManager.selection()
            onPick(category.name)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 17))
                    .frame(width: 40, height: 40)
                    .background(category.color.opacity(isSuggested ? 0.25 : 0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(isSuggested ? category.color : .clear, lineWidth: 2)
                    )
                Text(category.name)
                    .font(.caption2.weight(isSuggested ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(category.color)
        }
        .buttonStyle(.plain)
    }
}
