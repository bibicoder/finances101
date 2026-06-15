import Foundation
import SwiftData

enum WishlistPriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

enum WishlistStatus: String, Codable, CaseIterable {
    case waiting = "Waiting"
    case scheduled = "Scheduled"
    case bought = "Bought"
}

@Model
final class WishlistItem {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var title: String = ""
    var amount: Decimal = 0
    var priority: WishlistPriority = WishlistPriority.medium
    var status: WishlistStatus = WishlistStatus.waiting
    var scheduledDate: Date?
    var category: String = "General"
    var note: String?
    var createdAt: Date = Date()
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        priority: WishlistPriority = .medium,
        status: WishlistStatus = .waiting,
        scheduledDate: Date? = nil,
        category: String = "General",
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.priority = priority
        self.status = status
        self.scheduledDate = scheduledDate
        self.category = category
        self.note = note
        self.createdAt = Date()
    }
}
