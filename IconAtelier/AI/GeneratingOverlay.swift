import SwiftUI
import UIKit

struct GeneratingOverlay: View {
    let startDate: Date?
    let total: Int

    @State private var appearedAt: Date = .now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(appearedAt))
            content(elapsed: elapsed)
        }
        .ignoresSafeArea()
        .transition(
            .asymmetric(
                insertion: .identity,
                removal: .opacity.animation(.easeOut(duration: 0.35))
            )
        )
        .onAppear {
            appearedAt = .now
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        }
    }

    // MARK: - Composition

    @ViewBuilder
    private func content(elapsed: TimeInterval) -> some View {
        let reveal = easeOutCubic(progress(elapsed, start: 0.00, duration: 0.70))
        let titleP = easeOutBack(progress(elapsed, start: 0.35, duration: 0.55))
        let subP   = easeOutBack(progress(elapsed, start: 0.50, duration: 0.55))
        let badgeP = easeOutBack(progress(elapsed, start: 0.60, duration: 0.65))

        ZStack {
            AnimatedMesh(time: elapsed)

            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Text("Generating…")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .opacity(titleP)
                        .offset(y: (1 - titleP) * 14)

                    Text("Keep the app open.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black.opacity(0.78))
                        .opacity(subP)
                        .offset(y: (1 - subP) * 10)
                }

                ZStack {
                    HaloPulse(time: elapsed)
                        .opacity(badgeP)

                    GenerationCountdownBadge(startDate: startDate, total: total)
                        .scaleEffect(0.4 + 0.6 * badgeP)
                        .opacity(badgeP)
                }
            }
        }
        .mask {
            GeometryReader { geo in
                let maxRadius = hypot(geo.size.width, geo.size.height) * 1.05
                let radius = maxRadius * reveal
                Circle()
                    .frame(width: radius * 2, height: radius * 2)
                    .position(
                        x: geo.size.width - 32,
                        y: geo.safeAreaInsets.top + 28
                    )
            }
        }
    }

    // MARK: - Easing

    private func progress(_ t: Double, start: Double, duration: Double) -> Double {
        guard duration > 0 else { return t >= start ? 1 : 0 }
        return min(1, max(0, (t - start) / duration))
    }

    private func easeOutCubic(_ p: Double) -> Double {
        1 - pow(1 - p, 3)
    }

    private func easeInOutCubic(_ p: Double) -> Double {
        p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
    }

    private func easeOutBack(_ p: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(p - 1, 3) + c1 * pow(p - 1, 2)
    }
}

// MARK: - Animated mesh background

private struct AnimatedMesh: View {

    let time: Double

    var body: some View {
        let t = time

        let cornerTL = 0.62 + 0.10 * sin(t * 0.32 + 0.0)
        let cornerTR = 0.62 + 0.10 * sin(t * 0.36 + 1.7)
        let cornerBL = 0.62 + 0.10 * sin(t * 0.30 + 3.0)
        let cornerBR = 0.62 + 0.10 * sin(t * 0.34 + 4.2)

        let edgeLightness = 0.85 + 0.04 * sin(t * 0.42 + 1.1)

        let centerLightness = 0.96 + 0.03 * sin(t * 0.65)

        let colors: [Color] = [
            Color(white: cornerTL),       Color(white: edgeLightness),    Color(white: cornerTR),
            Color(white: edgeLightness),  Color(white: centerLightness),  Color(white: edgeLightness),
            Color(white: cornerBL),       Color(white: edgeLightness),    Color(white: cornerBR),
        ]

        MeshGradient(
            width: 3,
            height: 3,
            points: meshPoints(t: t),
            colors: colors
        )
    }

    private func meshPoints(t: Double) -> [SIMD2<Float>] {

        let centerX: Float = 0.5 + 0.34 * Float(cos(t * 0.48))
        let centerY: Float = 0.5 + 0.30 * Float(sin(t * 0.71))

        let amp: Float = 0.10
        let s = { (phase: Double) -> Float in Float(sin(t * 0.55 + phase)) }
        let c = { (phase: Double) -> Float in Float(cos(t * 0.45 + phase)) }

        return [
            [0.0,                0.0],
            [0.5 + amp * s(0.0), 0.0],
            [1.0,                0.0],

            [0.0,                0.5 + amp * c(1.3)],
            [centerX,            centerY],
            [1.0,                0.5 + amp * c(2.4)],

            [0.0,                1.0],
            [0.5 + amp * s(3.1), 1.0],
            [1.0,                1.0]
        ]
    }
}

// MARK: - Halo behind the badge

private struct HaloPulse: View {
    let time: Double

    var body: some View {
        let pulse = 0.5 + 0.5 * sin(time * 1.6)
        let scale = 1.0 + 0.12 * pulse
        let opacity = 0.35 + 0.25 * pulse

        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 30,
                    endRadius: 110
                )
            )
            .frame(width: 220, height: 220)
            .scaleEffect(scale)
            .opacity(opacity)
            .blendMode(.multiply)
    }
}

// MARK: - Countdown badge

private struct GenerationCountdownBadge: View {
    let startDate: Date?
    let total: Int

    var body: some View {
        TimelineView(.periodic(from: startDate ?? .now, by: 1)) { context in
            let remaining = remaining(at: context.date)
            ZStack {
                Circle()
                    .fill(.black)
                Text("\(remaining)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.3), value: remaining)
            }
            .frame(width: 110, height: 110)
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        }
    }

    private func remaining(at now: Date) -> Int {
        guard let startDate else { return total }
        let elapsed = Int(now.timeIntervalSince(startDate))
        return max(0, total - elapsed)
    }
}
