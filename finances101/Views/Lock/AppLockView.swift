import SwiftUI

struct AppLockView: View {
    @Environment(UserRoleManager.self) private var roleManager
    @State private var showPINEntry = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 48) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppColors.primaryDeep)

                    Text("Finance 101")
                        .font(.largeTitle.bold())

                    Text("Who's viewing?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    Button {
                        showPINEntry = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                            Text("My View")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.primaryDeep)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        roleManager.unlockAsViewer()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                            Text("Family View")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.charity.opacity(0.12))
                        .foregroundStyle(AppColors.charity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.charity.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .sheet(isPresented: $showPINEntry) {
            PINEntryView()
        }
    }
}
