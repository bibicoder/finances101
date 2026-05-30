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
            .background(Color(.systemGroupedBackground))
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
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Current Obligation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("\(currencySymbol)\(currentOwed.formatted())")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(currentOwed > 0 ? .purple : .green)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
            
            HStack(spacing: 12) {
                StatBox(
                    title: "Total Accrued",
                    value: "\(currencySymbol)\(totalAccrued.formatted())",
                    color: .purple.opacity(0.7)
                )
                
                StatBox(
                    title: "Total Paid",
                    value: "\(currencySymbol)\(totalPaid.formatted())",
                    color: .green
                )
            }
            
            if currentOwed > 0 && roleManager.canEdit {
                suggestedPaymentCard
            }
        }
    }
    
    private var suggestedPaymentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Suggested Payment")
                    .font(.headline)
            }
            
            Text("Consider sending \(currencySymbol)\(suggestedPayment.formatted()) this week")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                showAddPayment = true
            } label: {
                Text("Make Payment")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
