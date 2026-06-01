import SwiftUI

/// Animated achievement card. Icon springs in on appear.
struct AchievementBadge: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = AppColors.primaryDeep

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 54, height: 54)
                Circle()
                    .stroke(color.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 54, height: 54)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                    .scaleEffect(appeared ? 1.0 : 0.3)
                    .rotationEffect(.degrees(appeared ? 0 : -30))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(color)
                .scaleEffect(appeared ? 1.0 : 0.1)
                .opacity(appeared ? 1.0 : 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.surface)
                .shadow(color: color.opacity(0.18), radius: 14, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.35).delay(0.15)) {
                appeared = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AchievementBadge(
            icon: "trophy.fill",
            title: "Debt Crushed!",
            subtitle: "Paid off in full",
            color: .yellow
        )
        AchievementBadge(
            icon: "heart.fill",
            title: "Good Karma",
            subtitle: "Charity obligation cleared",
            color: AppColors.charity
        )
        AchievementBadge(
            icon: "star.fill",
            title: "Wishlist Goal",
            subtitle: "You bought it!",
            color: AppColors.accent
        )
    }
    .padding()
    .background(AppColors.background)
}
