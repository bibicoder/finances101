import SwiftUI
import SwiftData

enum TimelineTypeFilter: String, CaseIterable {
    case all = "All"
    case income = "Income"
    case expense = "Expense"
    case charity = "Charity"
}

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserRoleManager.self) private var roleManager
    @Query private var settings: [AppSettings]
    @Query(sort: \IncomeEntry.payoutDate) private var incomes: [IncomeEntry]
    @Query(sort: \ExpenseEntry.dueDate) private var expenses: [ExpenseEntry]
    @Query(sort: \CharityAccrual.date) private var charityAccruals: [CharityAccrual]
    @Query(sort: \CharityPayment.date) private var charityPayments: [CharityPayment]

    @State private var selectedHorizon: Int = 30
    @State private var selectedIncome: IncomeEntry?
    @State private var selectedExpense: ExpenseEntry?

    // Search & filter state
    @State private var searchText = ""
    @State private var typeFilter: TimelineTypeFilter = .all
    @State private var showFilterSheet = false
    @State private var filterMinAmount: String = ""
    @State private var filterMaxAmount: String = ""
    @State private var filterStartDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var filterEndDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var useDateFilter = false

    private let horizonOptions = [7, 30, 90]

    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }

    private var initialBalance: Decimal {
        settings.first?.initialBalance ?? 0
    }

    private var hasActiveFilters: Bool {
        typeFilter != .all || !filterMinAmount.isEmpty || !filterMaxAmount.isEmpty || useDateFilter
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                typeFilterBar
                horizonPicker

                let filtered = filteredItems
                if filtered.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty && !hasActiveFilters ? "No transactions" : "No results",
                        systemImage: "list.bullet.rectangle",
                        description: Text(
                            searchText.isEmpty && !hasActiveFilters
                                ? "Add income or expenses to see your timeline"
                                : "Try adjusting your search or filters"
                        )
                    )
                } else {
                    timelineList(items: filtered)
                }
            }
            .screenBackground()
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(hasActiveFilters ? AppColors.primaryDeep : AppColors.textSecondary)
                    }
                }
            }
            .sheet(item: $selectedIncome) { income in
                EditIncomeSheet(income: income)
            }
            .sheet(item: $selectedExpense) { expense in
                EditExpenseSheet(expense: expense)
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textSecondary)
            TextField("Search transactions...", text: $searchText)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimelineTypeFilter.allCases, id: \.self) { filter in
                    Button {
                        typeFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(typeFilter == filter ? AppColors.primaryDeep : AppColors.surface)
                            .foregroundStyle(typeFilter == filter ? .white : AppColors.textSecondary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private var horizonPicker: some View {
        Picker("Horizon", selection: $selectedHorizon) {
            ForEach(horizonOptions, id: \.self) { days in
                Text("\(days) days").tag(days)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Amount Range") {
                    HStack {
                        Text("Min")
                        Spacer()
                        TextField("0", text: $filterMinAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Max")
                        Spacer()
                        TextField("Any", text: $filterMaxAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Date Range") {
                    Toggle("Filter by date", isOn: $useDateFilter)
                    if useDateFilter {
                        DatePicker("From", selection: $filterStartDate, displayedComponents: .date)
                        DatePicker("To", selection: $filterEndDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button("Clear All Filters", role: .destructive) {
                        filterMinAmount = ""
                        filterMaxAmount = ""
                        useDateFilter = false
                        typeFilter = .all
                        searchText = ""
                        filterStartDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                        filterEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showFilterSheet = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var allTimelineItems: [TimelineItem] {
        let endDate = Calendar.current.date(byAdding: .day, value: selectedHorizon, to: Date()) ?? Date()
        var items: [TimelineItem] = []

        for income in incomes where income.payoutDate <= endDate {
            items.append(TimelineItem(
                id: income.id,
                date: income.payoutDate,
                title: income.title,
                amount: income.amount,
                type: .income,
                status: income.status == .paid ? "Paid" : "Pending",
                category: income.category
            ))
        }

        for expense in expenses where expense.dueDate <= endDate {
            items.append(TimelineItem(
                id: expense.id,
                date: expense.dueDate,
                title: expense.title,
                amount: expense.amount,
                type: .expense,
                status: expense.status == .paid ? "Paid" : "Planned",
                category: expense.category
            ))
        }

        for accrual in charityAccruals where accrual.date <= endDate {
            items.append(TimelineItem(
                id: accrual.id,
                date: accrual.date,
                title: "Charity Accrual",
                amount: accrual.accruedAmount,
                type: .charityAccrual,
                status: "Accrued",
                category: "Charity"
            ))
        }

        for payment in charityPayments where payment.date <= endDate {
            items.append(TimelineItem(
                id: payment.id,
                date: payment.date,
                title: "Charity Payment",
                amount: payment.amount,
                type: .charityPayment,
                status: "Sent",
                category: "Charity"
            ))
        }

        return items.sorted { $0.date < $1.date }
    }

    private var filteredItems: [TimelineItem] {
        var items = allTimelineItems

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q) ||
                $0.category.lowercased().contains(q)
            }
        }

        switch typeFilter {
        case .all: break
        case .income:  items = items.filter { $0.type == .income }
        case .expense: items = items.filter { $0.type == .expense }
        case .charity: items = items.filter { $0.type == .charityAccrual || $0.type == .charityPayment }
        }

        if let min = Decimal(userInput: filterMinAmount), !filterMinAmount.isEmpty {
            items = items.filter { $0.amount >= min }
        }
        if let max = Decimal(userInput: filterMaxAmount), !filterMaxAmount.isEmpty {
            items = items.filter { $0.amount <= max }
        }

        if useDateFilter {
            let start = Calendar.current.startOfDay(for: filterStartDate)
            let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: filterEndDate) ?? filterEndDate
            items = items.filter { $0.date >= start && $0.date <= end }
        }

        return items
    }

    private func timelineList(items: [TimelineItem]) -> some View {
        let balances = precomputeRunningBalances(for: items)
        return List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                TimelineRowView(
                    item: item,
                    runningBalance: balances[index],
                    symbol: currencySymbol
                )
                .listRowBackground(AppColors.surface)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .contextMenu {
                    if roleManager.canEdit {
                        if item.type == .income {
                            Button {
                                selectedIncome = incomes.first { $0.id == item.id }
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            if item.status != "Paid" {
                                Button {
                                    markIncomeAsPaid(id: item.id)
                                } label: {
                                    Label("Mark as Paid", systemImage: "checkmark.circle")
                                }
                            }
                        }
                        if item.type == .expense {
                            Button {
                                selectedExpense = expenses.first { $0.id == item.id }
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            if item.status != "Paid" {
                                Button {
                                    markExpenseAsPaid(id: item.id)
                                } label: {
                                    Label("Mark as Paid", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func markIncomeAsPaid(id: UUID) {
        guard let income = incomes.first(where: { $0.id == id }) else { return }
        income.status = .paid
        income.payoutDate = Date()
        CharityManager.createAccrualIfNeeded(for: income, in: modelContext)
        modelContext.saveWithLogging()
        HapticManager.success()
    }
    
    private func markExpenseAsPaid(id: UUID) {
        guard let expense = expenses.first(where: { $0.id == id }) else { return }
        expense.status = .paid
        expense.dueDate = Date()
        modelContext.saveWithLogging()
        HapticManager.success()
    }
    
    private func precomputeRunningBalances(for items: [TimelineItem]) -> [Decimal] {
        let today = Calendar.current.startOfDay(for: Date())
        var balance = initialBalance
        return items.map { item in
            let isFuture = Calendar.current.startOfDay(for: item.date) > today
            switch item.type {
            case .income:
                if item.status == "Paid" || isFuture { balance += item.amount }
            case .expense:
                if item.status == "Paid" || isFuture { balance -= item.amount }
            case .charityPayment:
                balance -= item.amount
            case .charityAccrual:
                break
            }
            return balance
        }
    }
}

struct TimelineItem: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let amount: Decimal
    let type: TimelineItemType
    let status: String
    let category: String
}

enum TimelineItemType {
    case income
    case expense
    case charityAccrual
    case charityPayment
    
    var color: Color {
        switch self {
        case .income:        return AppColors.income
        case .expense:       return AppColors.expense
        case .charityAccrual: return AppColors.charity.opacity(0.7)
        case .charityPayment: return AppColors.charity
        }
    }
    
    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .charityAccrual: return "heart.text.square.fill"
        case .charityPayment: return "heart.circle.fill"
        }
    }
}

#Preview {
    TimelineView()
        .modelContainer(for: [
            IncomeEntry.self,
            ExpenseEntry.self,
            CharityAccrual.self,
            CharityPayment.self,
            AppSettings.self
        ], inMemory: true)
}
