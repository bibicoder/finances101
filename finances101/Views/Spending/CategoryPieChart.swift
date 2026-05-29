import SwiftUI
import Charts

struct CategoryData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Decimal
    let color: Color
    let icon: String
}

struct CategoryPieChart: View {
    let data: [CategoryData]
    let symbol: String
    
    private var total: Decimal {
        data.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
            
            if data.isEmpty {
                emptyState
            } else {
                HStack(spacing: 20) {
                    chartView
                    legendView
                }
            }
        }
        .padding()
        .appCard()
    }
    
    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppColors.accent.opacity(0.1))
            .frame(height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No spending data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    private var chartView: some View {
        Chart(data) { item in
            SectorMark(
                angle: .value("Amount", Double(truncating: item.amount as NSDecimalNumber)),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(item.color)
            .cornerRadius(4)
        }
        .frame(width: 140, height: 140)
        .overlay {
            VStack(spacing: 2) {
                Text("Total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(symbol)\(total.formatted())")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
    }
    
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data.prefix(5)) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                    
                    Text(item.category)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    let percentage = total > 0 ? Double(truncating: (item.amount / total * 100) as NSDecimalNumber) : 0
                    Text("\(Int(percentage))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if data.count > 5 {
                Text("+\(data.count - 5) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let sampleData: [CategoryData] = [
        CategoryData(category: "Food", amount: 450, color: .orange, icon: "fork.knife"),
        CategoryData(category: "Transport", amount: 200, color: .blue, icon: "car.fill"),
        CategoryData(category: "Shopping", amount: 350, color: .pink, icon: "bag.fill"),
        CategoryData(category: "Entertainment", amount: 150, color: .purple, icon: "gamecontroller.fill"),
        CategoryData(category: "Health", amount: 100, color: .red, icon: "heart.fill")
    ]
    
    return CategoryPieChart(data: sampleData, symbol: "$")
        .padding()
}
