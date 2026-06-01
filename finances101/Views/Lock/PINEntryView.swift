import SwiftUI

struct PINEntryView: View {
    @Environment(UserRoleManager.self) private var roleManager
    @Environment(\.dismiss) private var dismiss

    @State private var enteredPIN = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var showError = false

    private let pinLength = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.primaryDeep)

                    Text("My View")
                        .font(.title2.bold())

                    Text("Enter your PIN to access full data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                PINDotsView(filledCount: enteredPIN.count, totalCount: pinLength)
                    .offset(x: shakeOffset)

                if showError {
                    Text("Incorrect PIN. Try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                PINNumpadView(enteredPIN: $enteredPIN, maxLength: pinLength) {
                    checkPIN()
                }
            }
            .padding(.vertical, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func checkPIN() {
        if KeychainManager.verifyWifePIN(enteredPIN) {
            roleManager.unlockAsOwner()
            dismiss()
        } else {
            withAnimation(.default) {
                shakeOffset = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.default) { shakeOffset = -10 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.default) { shakeOffset = 0 }
                }
            }
            showError = true
            enteredPIN = ""
        }
    }
}
