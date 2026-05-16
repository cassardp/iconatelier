import SwiftUI
import Foundation

// Duplicates a base Shape around a common center. Each instance is drawn in
// a local rect with its base at (0, 0) and its tip at (0, -unitLen), so a
// shape like Petal whose body extends from y=0 (base) up to negative y (tip)
// composes naturally. Each instance is rotated to face outward, then offset
// by `centerHole * radius` from the center.
struct RadialRepeat<Base: Shape>: Shape {
    var base: Base
    var count: Int            // 2..24
    var centerHole: Double    // -0.5..0.5 — signed fraction of outer radius:
                              //   > 0  empty hole at the center,
                              //   = 0  bases meet at the center,
                              //   < 0  bases cross the center → overlap.
                              // The outer tip always lands at outerRadius
                              // because unitLen = outerRadius - inner, so the
                              // pattern never overflows the bounds.
    var phaseDegrees: Double  // global rotation of the pattern
    var alternateScale: Double // 0..1 — odd-indexed instances scaled by this factor (1 = uniform)

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = side / 2
        let inner = outerRadius * max(-0.5, min(0.5, centerHole))
        let unitLen = max(0, outerRadius - inner)
        let unitWid = unitLen * 0.55
        let n = max(2, count)
        let phase = phaseDegrees * .pi / 180
        let alt = max(0.05, min(1, alternateScale))

        var path = Path()
        for i in 0..<n {
            let theta = (Double(i) / Double(n)) * 2 * .pi + phase
            let s = (alt < 1 && !i.isMultiple(of: 2)) ? alt : 1.0

            // Local frame: base at (0, 0), tip extends toward y = -unitLen.
            let local = CGRect(
                x: -unitWid * s / 2,
                y: -unitLen * s,
                width: unitWid * s,
                height: unitLen * s
            )
            var sub = base.path(in: local)

            // Order: rotate around local origin so the petal's "up" (-y axis)
            // aligns with the outward direction at angle theta, then translate
            // outward by `inner`, then translate to parent center.
            let transform = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .translatedBy(
                    x: inner * Darwin.cos(theta),
                    y: inner * Darwin.sin(theta)
                )
                .rotated(by: theta + .pi / 2)
            sub = sub.applying(transform)
            path.addPath(sub)
        }
        return path
    }
}
