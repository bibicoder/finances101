import SwiftUI
import SwiftData

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
    
    private let horizonOptions = [7, 30, 90]
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    private var initialBalance: Decimal {
        settings.first?.initialBalance ?? 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                horizonPicker
                
                if timelineItems.isEmpty {
                    ContentUnavailableView(
                        "No transactions",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add income or expenses to see your timeline")
                    )
                } else {
                    timelineList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Timeline")
            .sheet(item: $selectedIncome) { income in
                EditIncomeSheet(income: income)
            }
            .sheet(item: $selectedExpense) { expense in
                EditExpenseSheet(expense: expense)
            }
        }
    }
    
    private var horizonPicker: some View {
        Picker("Horizon", selection: $selectedHorizon) {
            ForEach(horizonOptions, id: \.self) { days in
                Text("\(days) days").tag(days)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    private var timelineItems: [TimelineItem] {
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
    
    private var timelineList: some View {
        List {
            ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                TimelineRowView(
                    item: item,
                    runningBalance: calculateRunningBalance(upTo: index),
                    symbol: currencySymbol
                )
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
    
    private func calculateRunningBalance(upTo index: Int) -> Decimal {
        var balance = initialBalance
        let today = Calendar.current.startOfDay(for: Date())
        
        for i in 0...index {
            let item = timelineItems[i]
            let itemDay = Calendar.current.startOfDay(for: item.date)
            let isFuture = itemDay > today
            
            switch item.type {
            case .income:
                if item.status == "Paid" || isFuture {
                    balance += item.amount
                }
            case .expense:
                if item.status == "Paid" || isFuture {
                    balance -= item.amount
                }
            case .charityPayment:
                balance -= item.amount
            case .charityAccrual:
                break
            }
        }
        
        return balance
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
        case .income: return .green
        case .expense: return .orange
        case .charityAccrual: return .purple.opacity(0.6)
        case .charityPayment: return .purple
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
