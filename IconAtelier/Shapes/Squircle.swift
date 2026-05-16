import SwiftUI
import Foundation

// Fills its bounding square with a true superellipse (Lamé curve):
//
//     |x|^n + |y|^n = r^n     with n ≈ 5.2
//
// n = 2 → circle, n → ∞ → square. n ≈ 5.2 matches the continuous-curvature
// "real" squircle Apple targets for app icons (G∞ transition between side
// and corner) — visibly smoother than the previous arc-circular /
// `.continuous` approximation, especially at large sizes.
//
// Used both as the user-facing `.squircle` layer primitive AND as the
// canvas / gallery / thumbnail iOS-icon mask — keeps the mask and any
// canvas-filling Squircle layer pixel-aligned at the edges.
struct SquircleShape: InsettableShape, Equatable {
    /// Exponent of the superellipse. ~5.0–5.2 is the band considered the
    /// "Apple squircle"; we use 5.2 as it slightly emphasizes the straighter
    /// side runs while keeping the corner soft.
    static let exponent: Double = 5.2

    /// 360 samples ≈ 1° per segment. Visually indistinguishable from a
    /// smooth curve even at 1024 pt export.
    private static let sampleCount = 360

    /// Distance from the bounding rect's edge to the squircle's edge. Set
    /// indirectly via `inset(by:)` so `strokeBorder` and similar
    /// `InsettableShape`-based modifiers produce a properly contained ring.
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) - insetAmount * 2
        guard side > 0 else { return Path() }
        let r = side / 2
        let cx = rect.midX
        let cy = rect.midY
        let invN = 2.0 / Self.exponent

        var path = Path()
        for i in 0...Self.sampleCount {
            let t = (Double(i) / Double(Self.sampleCount)) * 2 * .pi
            let c = Darwin.cos(t)
            let s = Darwin.sin(t)
            let x = (c >= 0 ? 1.0 : -1.0) * pow(abs(c), invN)
            let y = (s >= 0 ? 1.0 : -1.0) * pow(abs(s), invN)
            let p = CGPoint(x: cx + CGFloat(x) * r, y: cy + CGFloat(y) * r)
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> SquircleShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
