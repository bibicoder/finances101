import SwiftUI

struct TimelineRowView: View {
    let item: TimelineItem
    let runningBalance: Decimal
    let symbol: String
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                mainContent
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
    
    private var mainContent: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.icon)
                .font(.title2)
                .foregroundStyle(item.type.color)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Text(item.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(item.status)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(item.type.color)
                
                Text("Bal: \(symbol)\(runningBalance.formatted())")
                    .font(.caption)
                    .foregroundStyle(runningBalance < 0 ? .red : .secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.vertical, 8)
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                Label(item.category, systemImage: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if item.type == .income || item.type == .expense {
                    Label(item.status, systemImage: statusIcon)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }
        }
        .padding(.leading, 48)
        .padding(.bottom, 8)
    }
    
    private var amountText: String {
        let prefix: String
        switch item.type {
        case .income:
            prefix = "+"
        case .expense, .charityPayment:
            prefix = "-"
        case .charityAccrual:
            prefix = ""
        }
        return "\(prefix)\(symbol)\(item.amount.formatted())"
    }
    
    private var statusColor: Color {
        switch item.status {
        case "Paid", "Sent": return .green
        case "Planned", "Pending": return .orange
        case "Accrued": return .purple
        default: return .secondary
        }
    }
    
    private var statusIcon: String {
        switch item.status {
        case "Paid", "Sent": return "checkmark.circle.fill"
        case "Planned", "Pending": return "clock.fill"
        default: return "circle.fill"
        }
    }
}

#Preview {
    List {
        TimelineRowView(
            item: TimelineItem(
                id: UUID(),
                date: Date(),
                title: "Salary",
                amount: 3500,
                type: .income,
                status: "Pending",
                category: "Work"
            ),
            runningBalance: 5000,
            symbol: "$"
        )
        
        TimelineRowView(
            item: TimelineItem(
                id: UUID(),
                date: Date(),
                title: "Rent",
                amount: 1200,
                type: .expense,
                status: "Planned",
                category: "Housing"
            ),
            runningBalance: 3800,
            symbol: "$"
        )
    }
}
