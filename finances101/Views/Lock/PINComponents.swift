import SwiftUI

struct PINDotsView: View {
    let filledCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<totalCount, id: \.self) { index in
                Circle()
                    .fill(index < filledCount ? AppColors.primaryDeep : Color(.systemGray4))
                    .frame(width: 16, height: 16)
                    .scaleEffect(index < filledCount ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.2), value: filledCount)
            }
        }
    }
}

struct PINNumpadView: View {
    @Binding var enteredPIN: String
    let maxLength: Int
    let onComplete: () -> Void

    private let buttons: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(buttons, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { label in
                        if label.isEmpty {
                            Color.clear.frame(width: 72, height: 72)
                        } else if label == "⌫" {
                            Button {
                                if !enteredPIN.isEmpty {
                                    enteredPIN.removeLast()
                                }
                                HapticManager.selection()
                            } label: {
                                Image(systemName: "delete.left")
                                    .font(.title2)
                                    .frame(width: 72, height: 72)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                            .foregroundStyle(.primary)
                        } else {
                            Button {
                                guard enteredPIN.count < maxLength else { return }
                                enteredPIN.append(label)
                                HapticManager.selection()
                                if enteredPIN.count == maxLength {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onComplete()
                                    }
                                }
                            } label: {
                                Text(label)
                                    .font(.title.bold())
                                    .frame(width: 72, height: 72)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }
}
