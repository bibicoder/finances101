import Foundation
import SwiftData

@Model
final class CategoryBudget {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var category: String = ""
    var monthlyLimit: Decimal = 0
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        category: String,
        monthlyLimit: Decimal,
        isActive: Bool = true
    ) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.isActive = isActive
        self.createdAt = Date()
    }
}
