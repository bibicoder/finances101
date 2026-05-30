import SwiftUI

private enum SetupStep {
    case enterNew, confirm
}

struct PINSetupSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: SetupStep = .enterNew
    @State private var firstPIN = ""
    @State private var confirmPIN = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var mismatchError = false

    private let pinLength = 4

    private var currentPIN: Binding<String> {
        step == .enterNew ? $firstPIN : $confirmPIN
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.primaryDeep)

                    Text(step == .enterNew ? "Set Family PIN" : "Confirm PIN")
                        .font(.title2.bold())

                    Text(step == .enterNew
                         ? "Enter a \(pinLength)-digit PIN for family access"
                         : "Enter the same PIN again to confirm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                PINDotsView(
                    filledCount: step == .enterNew ? firstPIN.count : confirmPIN.count,
                    totalCount: pinLength
                )
                .offset(x: shakeOffset)

                if mismatchError {
                    Text("PINs don't match. Try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                PINNumpadView(enteredPIN: currentPIN, maxLength: pinLength) {
                    handleComplete()
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

    private func handleComplete() {
        if step == .enterNew {
            step = .confirm
            mismatchError = false
        } else {
            if firstPIN == confirmPIN {
                KeychainManager.saveWifePIN(firstPIN)
                HapticManager.success()
                dismiss()
            } else {
                shake()
                mismatchError = true
                firstPIN = ""
                confirmPIN = ""
                step = .enterNew
            }
        }
    }

    private func shake() {
        withAnimation(.default) { shakeOffset = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) { shakeOffset = -10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.default) { shakeOffset = 0 }
            }
        }
    }
}
