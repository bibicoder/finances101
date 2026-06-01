import SwiftUI

struct DeviceSetupView: View {
    @Environment(UserRoleManager.self) private var roleManager

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(AppColors.primaryDeep.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AppColors.primaryDeep)
                }
                .padding(.bottom, 28)

                // Title
                VStack(spacing: 8) {
                    Text("Welcome to Finance 101")
                        .font(.title2.bold())
                    Text("Whose phone is this?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)

                // Cards
                VStack(spacing: 16) {
                    roleCard(
                        icon: "person.fill.checkmark",
                        title: "My Phone",
                        subtitle: "I'm the account owner. I want full access to all data and settings.",
                        color: AppColors.primaryDeep
                    ) {
                        roleManager.completeDeviceSetup(as: .owner)
                    }

                    roleCard(
                        icon: "heart.fill",
                        title: "Family Member's Phone",
                        subtitle: "I'm viewing shared finances. I only need to see the balance, expenses, and wishlist.",
                        color: AppColors.charity
                    ) {
                        roleManager.completeDeviceSetup(as: .familyMember)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("This can be changed later in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 32)
            }
        }
    }

    private func roleCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DeviceSetupView()
        .environment(UserRoleManager())
}
