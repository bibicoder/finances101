import SwiftUI

struct Category: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    
    init(_ name: String, icon: String, color: Color) {
        self.id = name
        self.name = name
        self.icon = icon
        self.color = color
    }
}

enum CategoryManager {
    
    static let expenseCategories: [Category] = [
        Category("Food", icon: "fork.knife", color: .orange),
        Category("Transport", icon: "car.fill", color: .blue),
        Category("Housing", icon: "house.fill", color: .brown),
        Category("Utilities", icon: "bolt.fill", color: .yellow),
        Category("Shopping", icon: "bag.fill", color: .pink),
        Category("Health", icon: "heart.text.square.fill", color: .red),
        Category("Entertainment", icon: "gamecontroller.fill", color: .purple),
        Category("Travel", icon: "airplane", color: .cyan),
        Category("Education", icon: "book.fill", color: .indigo),
        Category("Subscriptions", icon: "repeat", color: .mint),
        Category("Insurance", icon: "shield.fill", color: .green),
        Category("Taxes", icon: "doc.text.fill", color: .gray),
        Category("Charity", icon: "heart.fill", color: AppColors.charity),
        Category("Debt", icon: "creditcard.fill", color: .red),
        Category("Other", icon: "ellipsis.circle.fill", color: .secondary)
    ]
    
    static let incomeCategories: [Category] = [
        Category("Salary", icon: "briefcase.fill", color: .green),
        Category("Freelance", icon: "laptopcomputer", color: .blue),
        Category("Business", icon: "building.2.fill", color: .purple),
        Category("Investments", icon: "chart.line.uptrend.xyaxis", color: AppColors.accent),
        Category("Gift", icon: "gift.fill", color: .pink),
        Category("Refund", icon: "arrow.uturn.backward", color: .orange),
        Category("Other", icon: "ellipsis.circle.fill", color: .secondary)
    ]
    
    static let wishlistCategories: [Category] = [
        Category("Electronics", icon: "desktopcomputer", color: .blue),
        Category("Clothing", icon: "tshirt.fill", color: .pink),
        Category("Home", icon: "house.fill", color: .brown),
        Category("Travel", icon: "airplane", color: .cyan),
        Category("Vehicle", icon: "car.fill", color: .gray),
        Category("Entertainment", icon: "gamecontroller.fill", color: .purple),
        Category("Health", icon: "heart.fill", color: .red),
        Category("Education", icon: "book.fill", color: .indigo),
        Category("Other", icon: "ellipsis.circle.fill", color: .secondary)
    ]
    
    static func expenseCategory(for name: String) -> Category {
        expenseCategories.first { $0.name == name } ?? expenseCategories.last!
    }
    
    static func incomeCategory(for name: String) -> Category {
        incomeCategories.first { $0.name == name } ?? incomeCategories.last!
    }
    
    static func wishlistCategory(for name: String) -> Category {
        wishlistCategories.first { $0.name == name } ?? wishlistCategories.last!
    }
}

struct CategoryIconButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? category.color.opacity(0.2) : Color.clear)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
                    )
                
                Text(category.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? category.color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

struct CategoryGrid: View {
    let categories: [Category]
    @Binding var selected: String
    let columns: Int
    
    init(categories: [Category], selected: Binding<String>, columns: Int = 4) {
        self.categories = categories
        self._selected = selected
        self.columns = columns
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 16) {
            ForEach(categories) { category in
                CategoryIconButton(
                    category: category,
                    isSelected: selected == category.name
                ) {
                    selected = category.name
                    HapticManager.selection()
                }
            }
        }
    }
}
