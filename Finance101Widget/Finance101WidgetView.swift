import SwiftUI
import WidgetKit

struct Finance101WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Finance101Entry

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        default:            smallView
        }
    }

    private var smallView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.49, green: 0.23, blue: 0.93), Color(red: 0.36, green: 0.13, blue: 0.71)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                    Text("Finance 101")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.75))

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Balance")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(entry.currencySymbol)\(formattedAmount(entry.balance))")
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var mediumView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.49, green: 0.23, blue: 0.93), Color(red: 0.36, green: 0.13, blue: 0.71)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                        Text("Finance 101")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.75))

                    Spacer()

                    Text("Balance")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(entry.currencySymbol)\(formattedAmount(entry.balance))")
                        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .leading)

                Divider()
                    .background(.white.opacity(0.3))
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Safe to Spend")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(entry.currencySymbol)\(formattedAmount(entry.safeToSpend))")
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(entry.safeToSpend >= 0 ? Color(red: 0.52, green: 0.8, blue: 0.09) : .red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Spacer()

                    Text(entry.date, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private func formattedAmount(_ value: Double) -> String {
        if abs(value) >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if abs(value) >= 1_000 {
            return String(format: "%.1fk", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}

#Preview(as: .systemSmall) {
    Finance101Widget()
} timeline: {
    Finance101Entry(date: Date(), balance: 4250, safeToSpend: 1800, currencySymbol: "$")
}

#Preview(as: .systemMedium) {
    Finance101Widget()
} timeline: {
    Finance101Entry(date: Date(), balance: 4250, safeToSpend: 1800, currencySymbol: "$")
}
