import SwiftUI

/// Full-screen confetti burst. Increment `trigger` to fire.
/// Add as .overlay on NavigationStack for best results.
struct ConfettiView: View {
    @Binding var trigger: Int

    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { _ in
            SwiftUI.TimelineView(.animation(minimumInterval: 1 / 60.0, paused: particles.isEmpty)) { tl in
                Canvas { ctx, size in
                    for p in particles {
                        let elapsed = max(0, tl.date.timeIntervalSince(p.birth) - p.delay)
                        guard elapsed > 0 else { continue }
                        let y = elapsed * 580 * p.speed
                        guard y < size.height + 20 else { continue }
                        let x = p.normX * size.width + p.wobble * sin(elapsed * 2.8)
                        let alpha = max(0.0, 1.0 - max(0, elapsed - 1.7) / 0.8)
                        guard alpha > 0 else { continue }
                        var c = ctx
                        c.opacity = alpha
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .degrees(p.initRot + elapsed * p.rotSpeed))
                        c.fill(
                            Path(roundedRect: CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h), cornerRadius: 2),
                            with: .color(p.color)
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onChange(of: trigger) { _, val in
            guard val > 0 else { return }
            let now = Date()
            particles = (0..<90).map { _ in ConfettiParticle(birth: now) }
            Task {
                try? await Task.sleep(for: .seconds(3))
                particles = []
            }
        }
    }
}

private struct ConfettiParticle {
    private static let palette: [Color] = [
        Color(hex: "7C3AED"), Color(hex: "A78BFA"), Color(hex: "DDD6FE"),
        Color(hex: "84CC16"), Color(hex: "BEF264"), Color(hex: "ECFCCB"),
        Color(hex: "FFFFFF"), Color(hex: "5B21B6"),
    ]

    let color: Color
    let normX: Double
    let wobble: Double
    let speed: Double
    let w: Double
    let h: Double
    let initRot: Double
    let rotSpeed: Double
    let delay: Double
    let birth: Date

    init(birth: Date) {
        self.birth = birth
        color = Self.palette.randomElement()!
        normX = Double.random(in: 0.05...0.95)
        wobble = Double.random(in: -50...50)
        speed = Double.random(in: 0.5...1.0)
        w = Double.random(in: 7...13)
        h = Double.random(in: 4...7)
        initRot = Double.random(in: 0...360)
        rotSpeed = Double.random(in: 100...360) * (Bool.random() ? 1 : -1)
        delay = Double.random(in: 0...0.7)
    }
}
