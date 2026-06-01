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
            RoundedRectangle(cornerRadius: 10)
                .fill(iconBgColor)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: item.type.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(item.type.color)
                )
            
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
    
    private var iconBgColor: Color {
        switch item.type {
        case .income:        return Color(hex: "DCFCE7")
        case .expense:       return Color(hex: "FEE2E2")
        case .charityAccrual: return Color(hex: "F3E8FF")
        case .charityPayment: return Color(hex: "EDE9FE")
        }
    }

    private var statusColor: Color {
        switch item.status {
        case "Paid", "Sent", "Earned":  return AppColors.income
        case "Planned", "Pending":      return AppColors.warning
        case "Delayed":                 return Color(hex: "D97706")  // amber
        case "Cancelled":               return AppColors.expense
        case "Accrued":                 return AppColors.charity
        default:                        return AppColors.textSecondary
        }
    }

    private var statusIcon: String {
        switch item.status {
        case "Paid", "Sent", "Earned": return "checkmark.circle.fill"
        case "Planned", "Pending":     return "clock.fill"
        case "Delayed":                return "exclamationmark.circle.fill"
        case "Cancelled":              return "xmark.circle.fill"
        default:                       return "circle.fill"
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
