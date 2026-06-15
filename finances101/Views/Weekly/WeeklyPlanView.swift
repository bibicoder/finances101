import SwiftUI
import SwiftData

struct WeeklyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseEntry.dueDate) private var expenses: [ExpenseEntry]
    @Query(sort: \IncomeEntry.payoutDate) private var incomes: [IncomeEntry]
    @Query(sort: \WishlistItem.createdAt, order: .reverse) private var wishlistItems: [WishlistItem]
    @Query private var settings: [AppSettings]
    @Query private var charityAccruals: [CharityAccrual]
    @Query private var charityPayments: [CharityPayment]
    @Query private var wallets: [Wallet]
    @Query private var walletTransfers: [WalletTransfer]

    @State private var activeQuickEntryWeekId: Date? = nil
    @State private var quickEntryText = ""
    @FocusState private var quickEntryFocused: Bool

    // Quick-entry expense waiting for category confirmation in the half-sheet.
    // `autoCommitStash` survives sheet dismissal so swiping down still saves with the auto category.
    @State private var pendingExpense: PendingQuickExpense?
    @State private var autoCommitStash: PendingQuickExpense?

    private var symbol: String { settings.first?.currencySymbol ?? "$" }
    private var weeks: [PlanWeek] { PlanWeek.next6Weeks() }

    private var startingBalance: Decimal {
        BalanceCalculator(
            incomes: incomes, expenses: expenses,
            accruals: charityAccruals, payments: charityPayments,
            settings: settings.first,
            wallets: wallets, transfers: walletTransfers
        ).actualBalance()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                balanceHeader
                    .padding(.horizontal, 16)

                ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                    weekCard(week: week, index: index)
                        .padding(.horizontal, 16)
                }

                unscheduledWishlistSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
            .padding(.top, 12)
        }
        .screenBackground()
        .sheet(item: $pendingExpense, onDismiss: {
            // Swiped down without picking → save with the auto-suggested category
            if let stash = autoCommitStash {
                insertExpense(stash, category: stash.suggestedCategory)
                autoCommitStash = nil
            }
        }) { pending in
            CategoryQuickPickSheet(pending: pending, symbol: symbol) { category in
                autoCommitStash = nil
                insertExpense(pending, category: category)
                pendingExpense = nil
            }
        }
    }

    private func insertExpense(_ pending: PendingQuickExpense, category: String) {
        modelContext.insert(
            ExpenseEntry(title: pending.title, amount: pending.amount, dueDate: pending.dueDate,
                         category: category, type: .optional, status: .planned)
        )
        modelContext.saveWithLogging()
        HapticManager.success()
    }

    // MARK: - Balance Header

    private var balanceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Balance")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(startingBalance < 0 ? "-" : "")\(symbol)\(abs(startingBalance).formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(startingBalance >= 0 ? AppColors.income : AppColors.expense)
            }
            Spacer()
            Text("6-Week Cashflow")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppColors.primaryDeep.opacity(0.1))
                .foregroundStyle(AppColors.primaryDeep)
                .clipShape(Capsule())
        }
        .padding()
        .appCard()
    }

    // MARK: - Week Card

    private func weekCard(week: PlanWeek, index: Int) -> some View {
        let wExpenses = weekExpenses(for: week)
        let wIncomes = weekIncomes(for: week)
        let wPaidExpenses = weekPaidExpenses(for: week)
        let wPaidIncomes = weekPaidIncomes(for: week)
        let projected = projectedBalance(throughWeekIndex: index)
        let isActive = activeQuickEntryWeekId == week.id
        let weekNet = (wIncomes + wPaidIncomes).reduce(Decimal(0)) { $0 + $1.amount }
                    - (wExpenses + wPaidExpenses).reduce(Decimal(0)) { $0 + $1.amount }
        let hasAnyRows = !wIncomes.isEmpty || !wExpenses.isEmpty || !wPaidIncomes.isEmpty || !wPaidExpenses.isEmpty

        return VStack(spacing: 0) {
            weekHeader(week: week, projected: projected)
            Divider()

            // Already received/paid this week (auto-imported from bank or marked manually)
            ForEach(wPaidIncomes) { income in
                planRow(
                    title: income.title, amount: income.amount,
                    date: income.payoutDate, isIncome: true, category: nil, isPaid: true,
                    moveMenu: AnyView(incomeMoveMenu(income: income, currentWeek: week))
                )
                Divider().padding(.leading, 44)
            }

            ForEach(wPaidExpenses) { expense in
                planRow(
                    title: expense.title, amount: expense.amount,
                    date: expense.dueDate, isIncome: false,
                    category: CategoryManager.expenseCategory(for: expense.category), isPaid: true,
                    moveMenu: AnyView(expenseMoveMenu(expense: expense, currentWeek: week))
                )
                Divider().padding(.leading, 44)
            }

            ForEach(wIncomes) { income in
                planRow(
                    title: income.title, amount: income.amount,
                    date: income.payoutDate, isIncome: true, category: nil,
                    moveMenu: AnyView(incomeMoveMenu(income: income, currentWeek: week))
                )
                Divider().padding(.leading, 44)
            }

            ForEach(wExpenses) { expense in
                planRow(
                    title: expense.title, amount: expense.amount,
                    date: expense.dueDate, isIncome: false,
                    category: CategoryManager.expenseCategory(for: expense.category),
                    moveMenu: AnyView(expenseMoveMenu(expense: expense, currentWeek: week))
                )
                Divider().padding(.leading, 44)
            }

            if !hasAnyRows {
                Text("Nothing planned this week")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }

            if hasAnyRows {
                weekNetRow(weekNet: weekNet)
                Divider()
            }

            if isActive {
                quickEntryRow(week: week)
            } else {
                addRowButton(week: week)
            }
        }
        .appCard()
    }

    private func weekHeader(week: PlanWeek, projected: Decimal) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(week.label)
                    .font(.system(size: 15, weight: .bold))
                Text(week.dateRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("End balance")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(projected < 0 ? "-" : "")\(symbol)\(abs(projected).formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(projected >= 0 ? AppColors.income : AppColors.expense)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(projected < 0 ? AppColors.expense.opacity(0.04) : Color.clear)
    }

    private func weekNetRow(weekNet: Decimal) -> some View {
        HStack {
            Text("Net this week")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text("\(weekNet >= 0 ? "+" : "-")\(symbol)\(abs(weekNet).formatted(.number.precision(.fractionLength(0))))")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(weekNet >= 0 ? AppColors.income : AppColors.expense)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.04))
    }

    // MARK: - Plan Row with Move Context Menu (6.4)

    // Expense rows are color-coded by category (icon + label); income rows stay green.
    // Paid rows (bank-imported or marked done) render dimmed with a checkmark.
    private func planRow(title: String, amount: Decimal, date: Date, isIncome: Bool, category: Category?, isPaid: Bool = false, moveMenu: AnyView) -> some View {
        let accent: Color = isIncome ? AppColors.income : (category?.color ?? AppColors.expense)
        let icon: String = isPaid ? "checkmark" : (isIncome ? "arrow.down" : (category?.icon ?? "arrow.up"))

        return HStack(spacing: 10) {
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: isIncome || isPaid ? 9 : 11, weight: .bold))
                        .foregroundStyle(accent)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.medium)).lineLimit(1)
                HStack(spacing: 4) {
                    Text(date, style: .date)
                        .foregroundStyle(AppColors.textSecondary)
                    if let category {
                        Text("·").foregroundStyle(AppColors.textSecondary)
                        Text(category.name)
                            .foregroundStyle(accent)
                            .fontWeight(.medium)
                    }
                    if isPaid {
                        Text("·").foregroundStyle(AppColors.textSecondary)
                        Text(isIncome ? "received" : "paid")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .font(.caption2)
            }
            Spacer()
            Text("\(isIncome ? "+" : "-")\(symbol)\(amount.formatted(.number.precision(.fractionLength(2))))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(isIncome ? AppColors.income : AppColors.expense)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .opacity(isPaid ? 0.6 : 1)
        .contextMenu { moveMenu }
    }

    @ViewBuilder
    private func expenseMoveMenu(expense: ExpenseEntry, currentWeek: PlanWeek) -> some View {
        // Long press → change category
        Menu {
            ForEach(CategoryManager.expenseCategories) { category in
                Button {
                    expense.category = category.name
                    modelContext.saveWithLogging()
                    HapticManager.selection()
                } label: {
                    if expense.category == category.name {
                        Label(category.name, systemImage: "checkmark")
                    } else {
                        Label(category.name, systemImage: category.icon)
                    }
                }
            }
        } label: {
            Label("Category: \(expense.category)", systemImage: "tag")
        }
        Divider()
        ForEach(weeks) { week in
            if week.id != currentWeek.id {
                Button {
                    expense.dueDate = week.midpoint()
                    modelContext.saveWithLogging()
                    HapticManager.selection()
                } label: {
                    Label("Move to \(week.label)", systemImage: "calendar")
                }
            }
        }
        Divider()
        Button(role: .destructive) {
            modelContext.delete(expense)
            modelContext.saveWithLogging()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func incomeMoveMenu(income: IncomeEntry, currentWeek: PlanWeek) -> some View {
        ForEach(weeks) { week in
            if week.id != currentWeek.id {
                Button {
                    let mid = week.midpoint()
                    income.payoutDate = mid
                    income.earnedDate = mid
                    modelContext.saveWithLogging()
                    HapticManager.selection()
                } label: {
                    Label("Move to \(week.label)", systemImage: "calendar")
                }
            }
        }
    }

    // MARK: - Quick Add (6.2)

    private func addRowButton(week: PlanWeek) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                activeQuickEntryWeekId = week.id
                quickEntryText = ""
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.primaryDeep)
                Text("Quick add  \"Gas 80\"  or  \"Paycheck 2500\"")
                    .font(.caption)
                    .foregroundStyle(AppColors.primaryDeep.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func quickEntryRow(week: PlanWeek) -> some View {
        HStack(spacing: 8) {
            TextField("\"Gas 80\"  or  \"Paycheck 2500\"", text: $quickEntryText)
                .font(.caption)
                .focused($quickEntryFocused)
                .onAppear { quickEntryFocused = true }
                .onSubmit { commitQuickEntry(for: week) }

            Button { commitQuickEntry(for: week) } label: {
                Image(systemName: "return.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(quickEntryText.isEmpty ? Color.gray.opacity(0.35) : AppColors.primaryDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .disabled(quickEntryText.isEmpty)

            Button {
                withAnimation { activeQuickEntryWeekId = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.primaryDeep.opacity(0.04))
    }

    private func commitQuickEntry(for week: PlanWeek) {
        let result = QuickEntryParser.parse(quickEntryText)
        let targetDate = week.midpoint()
        switch result {
        case .expense(let title, let amount, let category):
            // Don't insert yet — show the compact category sheet first.
            // Picking a chip saves with that category; swiping down saves with `category` (auto).
            let pending = PendingQuickExpense(
                title: title, amount: amount,
                suggestedCategory: category, dueDate: targetDate
            )
            autoCommitStash = pending
            pendingExpense = pending
        case .income(let title, let amount):
            modelContext.insert(
                IncomeEntry(title: title, amount: amount,
                            earnedDate: targetDate, payoutDate: targetDate, status: .planned)
            )
            modelContext.saveWithLogging()
            HapticManager.success()
        case .invalid:
            HapticManager.selection()
            return
        }
        quickEntryText = ""
        withAnimation { activeQuickEntryWeekId = nil }
    }

    // MARK: - Wishlist Section (6.5)

    @ViewBuilder
    private var unscheduledWishlistSection: some View {
        let pending = Array(wishlistItems.filter { $0.status == .waiting }.prefix(5))
        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Schedule from Wishlist", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text("\(pending.count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(AppColors.primaryDeep.opacity(0.1))
                        .foregroundStyle(AppColors.primaryDeep)
                        .clipShape(Capsule())
                }

                ForEach(pending) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text(item.category).font(.caption2).foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Text("\(symbol)\(item.amount.formatted(.number.precision(.fractionLength(0))))")
                            .font(.subheadline.weight(.semibold).monospacedDigit())

                        Menu {
                            ForEach(weeks) { week in
                                Button {
                                    scheduleWishlist(item: item, to: week)
                                } label: {
                                    Label("→ \(week.label)", systemImage: "calendar.badge.plus")
                                }
                            }
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.primaryDeep)
                                .padding(6)
                                .background(AppColors.primaryDeep.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    if item.id != pending.last?.id { Divider() }
                }
            }
            .padding()
            .appCard()
        }
    }

    private func scheduleWishlist(item: WishlistItem, to week: PlanWeek) {
        let targetDate = week.midpoint()
        item.status = .scheduled
        item.scheduledDate = targetDate
        modelContext.insert(
            ExpenseEntry(title: "Wishlist: \(item.title)", amount: item.amount,
                         dueDate: targetDate, category: item.category,
                         type: .optional, status: .planned)
        )
        modelContext.saveWithLogging()
        HapticManager.success()
    }

    // MARK: - Projection Helpers (6.6)

    private func weekExpenses(for week: PlanWeek) -> [ExpenseEntry] {
        expenses.filter {
            $0.dueDate >= week.startDate && $0.dueDate < week.endDate &&
            $0.status == .planned && !$0.isDebtPayment
        }
    }

    private func weekIncomes(for week: PlanWeek) -> [IncomeEntry] {
        incomes.filter {
            $0.payoutDate >= week.startDate && $0.payoutDate < week.endDate &&
            $0.status.isUpcoming  // planned, earned, delayed — not cancelled, not paid
        }
    }

    // Already-paid activity (bank imports land here) — shown in its week,
    // but NOT added to the projection: it's already inside the current balance.
    private func weekPaidExpenses(for week: PlanWeek) -> [ExpenseEntry] {
        expenses.filter {
            $0.dueDate >= week.startDate && $0.dueDate < week.endDate &&
            $0.status == .paid && !$0.isDebtPayment
        }
    }

    private func weekPaidIncomes(for week: PlanWeek) -> [IncomeEntry] {
        incomes.filter {
            $0.payoutDate >= week.startDate && $0.payoutDate < week.endDate &&
            $0.status == .paid
        }
    }

    private func projectedBalance(throughWeekIndex index: Int) -> Decimal {
        var balance = startingBalance
        for i in 0...index {
            let w = weeks[i]
            balance += weekIncomes(for: w).reduce(0) { $0 + $1.amount }
            balance -= weekExpenses(for: w).reduce(0) { $0 + $1.amount }
        }
        return balance
    }
}

#Preview {
    WeeklyPlanView()
        .modelContainer(for: [
            ExpenseEntry.self, IncomeEntry.self, WishlistItem.self,
            AppSettings.self, CharityAccrual.self, CharityPayment.self
        ], inMemory: true)
}
