import SwiftUI

/// Displays a Decimal amount that animates (counts up/down) when the value changes.
/// Uses ease-out cubic interpolation over 0.65s.
struct AnimatedNumber: View {
    let value: Decimal
    let symbol: String
    let font: Font
    let color: Color

    @State private var displayed: Double = 0

    var body: some View {
        Text(formatted)
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .onAppear { animateTo(value) }
            .onChange(of: value) { _, new in animateTo(new) }
    }

    private var formatted: String {
        let neg = displayed < 0
        return "\(neg ? "-" : "")\(symbol)\(Int(abs(displayed)).formatted())"
    }

    private func animateTo(_ target: Decimal) {
        let end = NSDecimalNumber(decimal: target).doubleValue
        let start = displayed
        let steps = 28
        let duration = 0.65
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration / Double(steps) * Double(i)) {
                let t = Double(i) / Double(steps)
                let eased = 1 - pow(1 - t, 3)
                displayed = start + (end - start) * eased
            }
        }
    }
}
