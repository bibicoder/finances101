import SwiftUI
import SwiftData

struct DebtsWishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserRoleManager.self) private var roleManager
    @Query private var settings: [AppSettings]
    @Query(sort: \Debt.priority) private var debts: [Debt]
    @Query(sort: \WishlistItem.createdAt, order: .reverse) private var wishlistItems: [WishlistItem]
    
    @State private var selectedSegment = 0
    @State private var showAddDebt = false
    @State private var showAddWishlist = false
    @State private var safeToSpendAmount: Decimal = 0
    @State private var showAddSubscription = false
    @State private var showPayoffCalculator = false
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedSegment) {
                    Text("Debts").tag(0)
                    Text("Wishlist").tag(1)
                    Text("Subscriptions").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedSegment == 0 {
                    debtsSection
                } else if selectedSegment == 1 {
                    wishlistSection
                } else {
                    SubscriptionsView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if selectedSegment == 0 && roleManager.canEdit {
                        Button { showAddDebt = true } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    } else if selectedSegment == 1 {
                        Button { showAddWishlist = true } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
                if selectedSegment == 0 && !debts.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showPayoffCalculator = true
                        } label: {
                            Label("Payoff", systemImage: "chart.line.downtrend.xyaxis")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddDebt) {
                AddDebtSheet()
            }
            .sheet(isPresented: $showAddWishlist) {
                AddWishlistSheet()
            }
            .sheet(isPresented: $showPayoffCalculator) {
                DebtPayoffView()
            }
            .onAppear {
                let calculator = BalanceCalculator(modelContext: modelContext)
                safeToSpendAmount = calculator.safeToSpend()
            }
        }
    }
    
    private var debtsSection: some View {
        Group {
            if debts.isEmpty {
                ContentUnavailableView(
                    "No debts",
                    systemImage: "checkmark.circle.fill",
                    description: Text("You're debt free! Tap + to track a debt")
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        debtsSummary
                        
                        VStack(spacing: 8) {
                            ForEach(debts) { debt in
                                DebtRowView(debt: debt, symbol: currencySymbol)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var debtsSummary: some View {
        let totalDebt = debts.reduce(Decimal(0)) { $0 + $1.remainingAmount }
        
        return VStack(spacing: 8) {
            Text("Total Remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("\(currencySymbol)\(totalDebt.formatted())")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var wishlistSection: some View {
        Group {
            if wishlistItems.isEmpty {
                ContentUnavailableView(
                    "No wishlist items",
                    systemImage: "star.fill",
                    description: Text("Add things you want to buy later")
                )
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(wishlistItems) { item in
                            WishlistRowView(
                                item: item,
                                symbol: currencySymbol,
                                safeToSpend: safeToSpendAmount
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    DebtsWishlistView()
        .modelContainer(for: [
            Debt.self,
            WishlistItem.self,
            Subscription.self,
            AppSettings.self,
            IncomeEntry.self,
            ExpenseEntry.self,
            CharityAccrual.self,
            CharityPayment.self
        ], inMemory: true)
}
