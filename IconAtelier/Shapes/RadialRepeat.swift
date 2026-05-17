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

    // First instance points up (-y axis) so the pattern reads symmetrically
    // around the vertical axis without a configurable phase.
    private static var basePhase: Double { -.pi / 2 }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = side / 2
        let inner = outerRadius * max(-0.5, min(0.5, centerHole))
        let unitLen = max(0, outerRadius - inner)
        let unitWid = unitLen * 0.55
        let n = max(2, count)

        var path = Path()
        for i in 0..<n {
            let theta = (Double(i) / Double(n)) * 2 * .pi + Self.basePhase

            // Local frame: base at (0, 0), tip extends toward y = -unitLen.
            let local = CGRect(
                x: -unitWid / 2,
                y: -unitLen,
                width: unitWid,
                height: unitLen
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
