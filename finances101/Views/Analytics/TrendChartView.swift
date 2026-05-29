import SwiftUI
import Charts

struct MonthlyTrendData: Identifiable {
    let id = UUID()
    let month: Date
    let income: Decimal
    let expense: Decimal
}

struct TrendChartView: View {
    let data: [MonthlyTrendData]
    let symbol: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Trends")
                .font(.headline)
            
            if data.isEmpty {
                emptyState
            } else {
                chartView
                legendView
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
                    Image(systemName: "chart.bar.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No trend data yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    private var chartView: some View {
        Chart {
            ForEach(data) { item in
                BarMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Amount", Double(truncating: item.income as NSDecimalNumber))
                )
                .foregroundStyle(AppColors.income)
                .position(by: .value("Type", "Income"))
                
                BarMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Amount", Double(truncating: item.expense as NSDecimalNumber))
                )
                .foregroundStyle(AppColors.expense)
                .position(by: .value("Type", "Expense"))
            }
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
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
    
    private var legendView: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.income)
                    .frame(width: 10, height: 10)
                Text("Income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.expense)
                    .frame(width: 10, height: 10)
                Text("Expenses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    
    let sampleData: [MonthlyTrendData] = (-5...0).map { monthOffset in
        let month = calendar.date(byAdding: .month, value: monthOffset, to: today)!
        return MonthlyTrendData(
            month: month,
            income: Decimal(5000 + Int.random(in: -1000...1000)),
            expense: Decimal(3500 + Int.random(in: -800...800))
        )
    }
    
    return TrendChartView(data: sampleData, symbol: "$")
        .padding()
}
