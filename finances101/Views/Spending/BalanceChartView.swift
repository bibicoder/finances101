import SwiftUI
import Charts

struct BalanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Decimal
    let isPredicted: Bool
}

struct BalanceChartView: View {
    let dataPoints: [BalanceDataPoint]
    let symbol: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balance Over Time")
                .font(.headline)
            
            if dataPoints.isEmpty {
                emptyState
            } else {
                chartView
            }
        }
        .padding()
        .appCard()
    }
    
    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppColors.primaryLight.opacity(0.1))
            .frame(height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No data yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    private var dateSpanDays: Int {
        guard let first = dataPoints.map(\.date).min(),
              let last = dataPoints.map(\.date).max() else { return 0 }
        return Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
    }

    private var chartView: some View {
        Chart {
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", Double(truncating: point.balance as NSDecimalNumber))
                )
                .foregroundStyle(point.isPredicted ? AppColors.primaryDeep.opacity(0.45) : AppColors.primaryDeep)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: point.isPredicted ? [5, 5] : []))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", Double(truncating: point.balance as NSDecimalNumber))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            point.isPredicted ? AppColors.primaryDeep.opacity(0.08) : AppColors.primaryDeep.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.secondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .frame(height: 200)
        .chartXAxis {
            // Fixed label count regardless of range — weekly stride overlapped on Month/Year
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                if dateSpanDays > 120 {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                } else {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .chartXScale(range: .plotDimension(padding: 8))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(symbol)\(Decimal(doubleValue).formatted())")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    
    let sampleData: [BalanceDataPoint] = (-14...14).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        let baseBalance: Decimal = 10000
        let variation = Decimal(dayOffset * 100 + Int.random(in: -500...500))
        return BalanceDataPoint(
            date: date,
            balance: baseBalance + variation,
            isPredicted: dayOffset > 0
        )
    }
    
    return BalanceChartView(dataPoints: sampleData, symbol: "$")
        .padding()
}
