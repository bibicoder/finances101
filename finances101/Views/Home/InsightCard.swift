import SwiftUI

struct InsightCard: View {
    let insights: [FinancialInsight]
    @State private var showAll = false

    var body: some View {
        if let top = insights.first {
            Button { showAll = true } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(top.severity.color.opacity(0.12))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: top.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(top.severity.color)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(top.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        Text(top.message)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if insights.count > 1 {
                        Text("+\(insights.count - 1)")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(top.severity.color.opacity(0.12))
                            .foregroundStyle(top.severity.color)
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                }
                .padding(14)
                .appCard()
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(top.severity.color.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showAll) {
                InsightsListView(insights: insights)
            }
        }
    }
}

struct InsightsListView: View {
    let insights: [FinancialInsight]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 14) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(insight.severity.color.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: insight.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(insight.severity.color)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(insight.message)
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Financial Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.primaryDeep)
                }
            }
        }
    }
}
