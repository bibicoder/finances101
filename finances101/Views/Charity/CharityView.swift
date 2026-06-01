import SwiftUI
import SwiftData

struct CharityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserRoleManager.self) private var roleManager
    @Query private var settings: [AppSettings]
    @Query(sort: \CharityAccrual.date, order: .reverse) private var accruals: [CharityAccrual]
    @Query(sort: \CharityPayment.date, order: .reverse) private var payments: [CharityPayment]
    
    @State private var showAddPayment = false
    @State private var selectedSegment = 0
    
    private var currencySymbol: String {
        settings.first?.currencySymbol ?? "$"
    }
    
    private var charityPercentage: Double {
        settings.first?.charityPercentage ?? 25.0
    }
    
    private var totalAccrued: Decimal {
        accruals.reduce(0) { $0 + $1.accruedAmount }
    }
    
    private var totalPaid: Decimal {
        payments.reduce(0) { $0 + $1.amount }
    }
    
    private var currentOwed: Decimal {
        totalAccrued - totalPaid
    }
    
    private var suggestedPayment: Decimal {
        min(currentOwed, currentOwed * 0.1)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summarySection
                    segmentedHistorySection
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Charity")
            .toolbar {
                if roleManager.canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddPayment = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddPayment) {
                AddCharityPaymentSheet()
            }
        }
    }
    
    private var summarySection: some View {
        VStack(spacing: 14) {
            // Hero card
            VStack(spacing: 6) {
                Text("Current Obligation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text("\(currencySymbol)\(currentOwed.formatted())")
                    .font(.system(size: 42, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white)
                Text(currentOwed > 0 ? "Needs to be paid" : "All clear ✓")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(currentOwed > 0 ? Color(hex: "FCA5A5") : Color(hex: "86EFAC"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                LinearGradient(
                    colors: [AppColors.charity, Color(hex: "7C3AED")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: AppColors.charity.opacity(0.3), radius: 16, x: 0, y: 6)

            // Stat boxes
            HStack(spacing: 12) {
                StatBox(title: "Total Accrued",
                        value: "\(currencySymbol)\(totalAccrued.formatted())",
                        color: AppColors.charity)
                StatBox(title: "Total Paid",
                        value: "\(currencySymbol)\(totalPaid.formatted())",
                        color: AppColors.income)
            }

            if currentOwed > 0 && roleManager.canEdit {
                suggestedPaymentCard
            }
        }
    }

    private var suggestedPaymentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppColors.warning)
                Text("Suggested Payment")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            Text("Consider sending \(currencySymbol)\(suggestedPayment.formatted()) this week")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
            Button {
                showAddPayment = true
            } label: {
                Text("Make Payment")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppColors.primaryDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .appCard()
    }
    
    private var segmentedHistorySection: some View {
        VStack(spacing: 12) {
            Picker("History", selection: $selectedSegment) {
                Text("Accruals").tag(0)
                Text("Payments").tag(1)
            }
            .pickerStyle(.segmented)
            
            if selectedSegment == 0 {
                accrualsHistory
            } else {
                paymentsHistory
            }
        }
    }
    
    private var accrualsHistory: some View {
        VStack(spacing: 8) {
            if accruals.isEmpty {
                ContentUnavailableView(
                    "No accruals yet",
                    systemImage: "heart.text.square",
                    description: Text("Charity obligations will appear when you add income")
                )
                .frame(height: 150)
            } else {
                ForEach(accruals) { accrual in
                    CharityHistoryRow(
                        date: accrual.date,
                        amount: accrual.accruedAmount,
                        symbol: currencySymbol,
                        subtitle: accrualSubtitle(for: accrual),
                        isPayment: false
                    )
                }
            }
        }
    }
    
    private func accrualSubtitle(for accrual: CharityAccrual) -> String {
        if accrual.note == "Fixed monthly charity" {
            return "Fixed monthly amount"
        } else if accrual.baseAmount > 0 && accrual.percentage > 0 {
            return "From \(currencySymbol)\(accrual.baseAmount.formattedFull()) @ \(Int(accrual.percentage))%"
        } else {
            return accrual.note ?? "Charity"
        }
    }

    private var paymentsHistory: some View {
        VStack(spacing: 8) {
            if payments.isEmpty {
                ContentUnavailableView(
                    "No payments yet",
                    systemImage: "heart.circle",
                    description: Text("Record your charity payments here")
                )
                .frame(height: 150)
            } else {
                ForEach(payments) { payment in
                    CharityHistoryRow(
                        date: payment.date,
                        amount: payment.amount,
                        symbol: currencySymbol,
                        subtitle: payment.note ?? "Charity payment",
                        isPayment: true
                    )
                }
            }
        }
    }
    
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .appCard()
    }
}

#Preview {
    CharityView()
        .modelContainer(for: [
            CharityAccrual.self,
            CharityPayment.self,
            AppSettings.self
        ], inMemory: true)
}
