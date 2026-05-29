import SwiftUI
import SwiftData

struct WishlistRowView: View {
    @Environment(\.modelContext) private var modelContext
    let item: WishlistItem
    let symbol: String
    let safeToSpend: Decimal
    
    @State private var showScheduleSheet = false
    @State private var showEditSheet = false
    
    private var affordabilityStatus: AffordabilityStatus {
        if item.status == .bought {
            return .bought
        } else if safeToSpend >= item.amount {
            return .canAfford
        } else if safeToSpend >= item.amount * 0.5 {
            return .soon
        } else {
            return .notYet
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            priorityBadge
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .strikethrough(item.status == .bought)
                    
                    if item.status == .scheduled {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(item.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let scheduledDate = item.scheduledDate {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(scheduledDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(symbol)\(item.amount.formatted())")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                affordabilityBadge
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            if item.status == .waiting {
                Button {
                    showScheduleSheet = true
                } label: {
                    Label("Schedule", systemImage: "calendar")
                }
            }
            
            if item.status != .bought {
                Button {
                    markAsBought()
                } label: {
                    Label("Mark as Bought", systemImage: "checkmark.circle")
                }
            }
            
            Button(role: .destructive) {
                deleteItem()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleWishlistSheet(item: item)
        }
        .sheet(isPresented: $showEditSheet) {
            EditWishlistSheet(item: item)
        }
    }
    
    private var priorityBadge: some View {
        Image(systemName: priorityIcon)
            .font(.title2)
            .foregroundStyle(priorityColor)
            .frame(width: 32)
    }
    
    private var priorityIcon: String {
        switch item.priority {
        case .high: return "star.fill"
        case .medium: return "star.leadinghalf.filled"
        case .low: return "star"
        }
    }
    
    private var priorityColor: Color {
        switch item.priority {
        case .high: return .yellow
        case .medium: return .orange
        case .low: return .gray
        }
    }
    
    private var affordabilityBadge: some View {
        Text(affordabilityStatus.label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(affordabilityStatus.color.opacity(0.15))
            .foregroundStyle(affordabilityStatus.color)
            .clipShape(Capsule())
    }
    
    private func markAsBought() {
        item.status = .bought
        
        let expense = ExpenseEntry(
            title: "Wishlist: \(item.title)",
            amount: item.amount,
            dueDate: Date(),
            category: item.category,
            type: .optional,
            status: .paid
        )
        modelContext.insert(expense)
        
        try? modelContext.save()
        HapticManager.success()
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

enum AffordabilityStatus {
    case canAfford
    case soon
    case notYet
    case bought
    
    var label: String {
        switch self {
        case .canAfford: return "Can Afford"
        case .soon: return "Soon"
        case .notYet: return "Not Yet"
        case .bought: return "Bought"
        }
    }
    
    var color: Color {
        switch self {
        case .canAfford: return .green
        case .soon: return .orange
        case .notYet: return .red
        case .bought: return .blue
        }
    }
}

struct ScheduleWishlistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let item: WishlistItem
    @State private var scheduledDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Purchase Date", selection: $scheduledDate, displayedComponents: .date)
                }
                
                Section {
                    Button("Schedule Purchase") {
                        scheduleItem()
                    }
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func scheduleItem() {
        item.status = .scheduled
        item.scheduledDate = scheduledDate
        
        let expense = ExpenseEntry(
            title: "Wishlist: \(item.title)",
            amount: item.amount,
            dueDate: scheduledDate,
            category: item.category,
            type: .optional,
            status: .planned
        )
        modelContext.insert(expense)
        
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}

#Preview {
    VStack(spacing: 8) {
        WishlistRowView(
            item: WishlistItem(title: "iPhone 15 Pro", amount: 1199, priority: .high),
            symbol: "$",
            safeToSpend: 2000
        )
        
        WishlistRowView(
            item: WishlistItem(title: "AirPods Pro", amount: 249, priority: .medium),
            symbol: "$",
            safeToSpend: 100
        )
    }
    .padding()
}
