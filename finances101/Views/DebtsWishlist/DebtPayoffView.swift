import SwiftUI
import SwiftData

struct DebtPayoffView: View {
    @Query(sort: \Debt.priority) private var debts: [Debt]
    @Query private var settings: [AppSettings]
    @Environment(\.dismiss) private var dismiss

    @State private var strategy: PayoffStrategy = .avalanche
    @State private var extraMonthly: String = ""
    @State private var summary: PayoffSummary?

    private var symbol: String { settings.first?.currencySymbol ?? "$" }
    private var activeDebts: [Debt] { debts.filter { $0.remainingAmount > 0 } }

    var body: some View {
        NavigationStack {
            Form {
                strategySection
                inputSection
                if let summary {
                    summarySection(summary)
                    resultsSection(summary)
                } else if !activeDebts.isEmpty {
                    hintSection
                }
            }
            .navigationTitle("Payoff Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: strategy)      { _, _ in recalculate() }
            .onChange(of: extraMonthly)  { _, _ in recalculate() }
            .onAppear { recalculate() }
        }
    }

    // MARK: Sections

    private var strategySection: some View {
        Section {
            Picker("Strategy", selection: $strategy) {
                ForEach(PayoffStrategy.allCases, id: \.self) { s in
                    Label(s.rawValue, systemImage: s.icon).tag(s)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Strategy")
        } footer: {
            Text(strategy == .avalanche
                 ? "Pay off the highest interest rate first. Saves the most money overall."
                 : "Pay off the smallest balance first. Fastest wins for motivation.")
        }
    }

    private var inputSection: some View {
        Section("Monthly Extra Payment") {
            HStack {
                Text(symbol)
                    .foregroundStyle(.secondary)
                TextField("0", text: $extraMonthly)
                    .keyboardType(.decimalPad)
                Text("/ month")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hintSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Add interest rates for best results", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.primaryDeep)
                Text("Edit each debt to add its APR (annual interest rate). Without rates, avalanche and snowball will use remaining balance only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func summarySection(_ s: PayoffSummary) -> some View {
        Section {
            HStack(spacing: 0) {
                summaryCell(
                    label: "Debt-Free",
                    value: s.debtFreeDate.formatted(date: .abbreviated, time: .omitted),
                    color: AppColors.income
                )
                Divider().frame(height: 44)
                summaryCell(
                    label: "Months",
                    value: "\(s.totalMonths)",
                    color: AppColors.primaryDeep
                )
                Divider().frame(height: 44)
                summaryCell(
                    label: "Total Interest",
                    value: s.totalInterestPaid > 0
                        ? "\(symbol)\(Int(s.totalInterestPaid))"
                        : "—",
                    color: s.totalInterestPaid > 0 ? AppColors.expense : .secondary
                )
            }
        } header: {
            Text("Summary")
        }
    }

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func resultsSection(_ s: PayoffSummary) -> some View {
        Section("Payoff Order") {
            ForEach(s.results, id: \.id) { result in
                resultRow(result)
            }
        }
    }

    private func resultRow(_ result: PayoffResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(orderColor(result.order).opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("#\(result.order)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(orderColor(result.order))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.creditor)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(payoffLabel(result))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(result.payoffDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .fontWeight(.semibold)
                if result.totalInterestPaid > 1 {
                    Text("+\(symbol)\(Int(result.totalInterestPaid)) interest")
                        .font(.caption2)
                        .foregroundStyle(AppColors.expense)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func payoffLabel(_ r: PayoffResult) -> String {
        let months = r.monthsToPayoff
        if months < 12 {
            return "\(months) month\(months == 1 ? "" : "s")"
        }
        let years = months / 12
        let rem   = months % 12
        return rem == 0 ? "\(years)y" : "\(years)y \(rem)mo"
    }

    private func orderColor(_ order: Int) -> Color {
        switch order {
        case 1: return AppColors.income
        case 2: return Color.orange
        case 3: return .orange
        default: return .secondary
        }
    }

    // MARK: Logic

    private func recalculate() {
        guard !activeDebts.isEmpty else { summary = nil; return }
        let extra = Double(extraMonthly) ?? 0
        summary = DebtPayoffCalculator.calculate(debts: activeDebts, extraMonthly: extra, strategy: strategy)
    }
}
