import SwiftUI

struct CharityHistoryRow: View {
    let date: Date
    let amount: Decimal
    let symbol: String
    let subtitle: String
    let isPayment: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPayment ? "arrow.up.heart.fill" : "heart.text.square.fill")
                .font(.title3)
                .foregroundStyle(isPayment ? .green : .purple.opacity(0.7))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isPayment ? "Payment Sent" : "Obligation Added")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(isPayment ? "-" : "+")\(symbol)\(amount.formatted())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isPayment ? .green : .purple)
                
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 8) {
        CharityHistoryRow(
            date: Date(),
            amount: 375.00,
            symbol: "$",
            subtitle: "From $1,500 @ 25%",
            isPayment: false
        )
        
        CharityHistoryRow(
            date: Date(),
            amount: 100.00,
            symbol: "$",
            subtitle: "Monthly charity",
            isPayment: true
        )
    }
    .padding()
}
