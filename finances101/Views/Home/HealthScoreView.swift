import SwiftUI
import SwiftData

struct HealthScoreView: View {
    let score: HealthScore
    let symbol: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    gaugeSection
                    pillarsSection
                    tipSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Financial Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Gauge

    private var gaugeSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(score.gradeColor.opacity(0.12), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 180, height: 180)

                // Score arc
                Circle()
                    .trim(from: 0.125, to: 0.125 + 0.75 * Double(score.total) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [score.gradeColor.opacity(0.6), score.gradeColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 180, height: 180)
                    .animation(.spring(duration: 1.0), value: score.total)

                VStack(spacing: 2) {
                    Text("\(score.total)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(score.gradeColor)
                    Text(score.grade)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            Text("Based on last 30 days of activity")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .appCard()
    }

    // MARK: Pillars

    private var pillarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                pillarCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Savings Rate",
                    score: score.savingsScore,
                    color: AppColors.income,
                    detail: savingsDetail
                )
                pillarCard(
                    icon: "creditcard.fill",
                    title: "Debt Load",
                    score: score.debtScore,
                    color: .orange,
                    detail: debtDetail
                )
                pillarCard(
                    icon: "shield.fill",
                    title: "Emergency Buffer",
                    score: score.bufferScore,
                    color: AppColors.primaryLight,
                    detail: bufferDetail
                )
                pillarCard(
                    icon: "heart.fill",
                    title: "Giving",
                    score: score.charityScore,
                    color: AppColors.charity,
                    detail: charityDetail
                )
            }
        }
    }

    private func pillarCard(icon: String, title: String, score: Int, color: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                Text("\(score)/25")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 25, height: 6)
                        .animation(.spring(duration: 0.8), value: score)
                }
            }
            .frame(height: 6)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .appCard()
    }

    // MARK: Tip

    private var tipSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Tip")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(score.tip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .appCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: Detail strings

    private var savingsDetail: String {
        if score.monthlyIncome == 0 { return "No income recorded yet" }
        let rate = max(0, score.savingsRate)
        return String(format: "%.0f%% saved this month", rate)
    }

    private var debtDetail: String {
        if score.totalDebt == 0 { return "Debt free" }
        return "\(symbol)\(score.totalDebt.formatted(.number.precision(.fractionLength(0)))) remaining"
    }

    private var bufferDetail: String {
        if score.bufferMonths >= 6 { return "6+ months covered" }
        if score.bufferMonths <= 0 { return "No buffer" }
        return String(format: "%.1f months of expenses", score.bufferMonths)
    }

    private var charityDetail: String {
        if !score.charityEnabled { return "Not configured" }
        if score.charityOwed == 0 { return "All caught up" }
        return "\(symbol)\(score.charityOwed.formatted(.number.precision(.fractionLength(0)))) owed"
    }
}
