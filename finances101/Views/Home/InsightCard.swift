import SwiftUI

struct InsightCard: View {
    let insights: [FinancialInsight]
    @State private var showAll = false

    var body: some View {
        if let top = insights.first {
            Button { showAll = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: top.icon)
                        .font(.title2)
                        .foregroundStyle(top.severity.color)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(top.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(top.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if insights.count > 1 {
                        Text("+\(insights.count - 1)")
                            .font(.caption2).fontWeight(.bold)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(top.severity.color.opacity(0.15))
                            .foregroundStyle(top.severity.color)
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .appCard()
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(top.severity.color.opacity(0.25), lineWidth: 1)
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
                        ZStack {
                            Circle()
                                .fill(insight.severity.color.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: insight.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(insight.severity.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(insight.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                }
            }
        }
    }
}
