import Foundation
import SwiftData

@Model
final class CategoryBudget {
    var id: UUID
    var category: String
    var monthlyLimit: Decimal
    var isActive: Bool
    var createdAt: Date

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
