import SwiftUI

/// Full-screen overlay shown while an AI generation request is in flight.
/// Light-gray mesh background + title + subtitle + circular countdown badge.
struct GeneratingOverlay: View {
    let startDate: Date?
    let total: Int

    private static let meshColors: [Color] = Color.mesh3x3(
        topLeft:     Color(red: 0.96, green: 0.96, blue: 0.97),
        topRight:    Color(red: 0.93, green: 0.93, blue: 0.94),
        bottomLeft:  Color(red: 0.95, green: 0.95, blue: 0.95),
        bottomRight: Color(red: 0.91, green: 0.91, blue: 0.92)
    )

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0,   0  ], [0.5, 0  ], [1,   0  ],
                    [0,   0.5], [0.5, 0.5], [1,   0.5],
                    [0,   1  ], [0.5, 1  ], [1,   1  ]
                ],
                colors: Self.meshColors
            )
            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Text("Generating…")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("Keep the app open.")
                        .font(.subheadline)
                        .foregroundStyle(.black.opacity(0.65))
                }
                GenerationCountdownBadge(startDate: startDate, total: total)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity.animation(.easeInOut(duration: 0.55)))
    }
}

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
