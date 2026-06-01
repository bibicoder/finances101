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
    @State private var confettiTrigger = 0
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedSegment) {
                    Text("Weekly").tag(0)
                    Text("Debts").tag(1)
                    Text("Wishlist").tag(2)
                    Text("Subscriptions").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedSegment == 0 {
                    WeeklyPlanView()
                } else if selectedSegment == 1 {
                    debtsSection
                } else if selectedSegment == 2 {
                    wishlistSection
                } else {
                    SubscriptionsView()
                }
            }
            .screenBackground()
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if selectedSegment == 1 && roleManager.canEdit {
                        Button { showAddDebt = true } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    } else if selectedSegment == 2 {
                        Button { showAddWishlist = true } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
                if selectedSegment == 1 && !debts.isEmpty {
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
            .overlay { ConfettiView(trigger: $confettiTrigger) }
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
        let totalOriginal = debts.reduce(Decimal(0)) { $0 + $1.totalAmount }
        let paid = totalOriginal - totalDebt
        let pct = totalOriginal > 0 ? Double(truncating: (paid / totalOriginal) as NSDecimalNumber) : 0

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Remaining")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("\(currencySymbol)\(totalDebt.formatted())")
                        .font(.system(size: 32, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Paid off")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color(hex: "86EFAC"))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(Color(hex: "86EFAC"))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppColors.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppColors.cardShadow, radius: 16, x: 0, y: 4)
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
                                safeToSpend: safeToSpendAmount,
                                onPurchase: { confettiTrigger += 1 }
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
