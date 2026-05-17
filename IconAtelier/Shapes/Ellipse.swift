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

// Parametric superellipse for the ellipse/circle family. Same Lamé curve as
// `SquircleShape`, but `n` is driven by `roundness`:
//
//   roundness = 1 → n = 2    (true ellipse / circle)
//   roundness = 0 → n = 10   (very square corners, still C∞ smooth)
//
// Aspect ratio (true ellipse vs circle) is handled by the outer `.transform`
// wrapper's stretchX / stretchY — this shape always fills its bounding
// square along its longer axis after refit.
struct SuperellipseShape: InsettableShape, Equatable {
    /// 0...1. 1 → pure circle/ellipse, 0 → very square. Mid values trace the
    /// squircle-style continuum (n ≈ 5.2 sits around roundness ≈ 0.4).
    var roundness: Double

    /// Starting angle of the arc, in degrees. 0 = right (3 o'clock),
    /// -90 = top, 90 = bottom. Ignored when `arcSweep >= 1`.
    var arcStart: Double = -90

    /// Fraction of the full revolution to trace, 0...1. 1 produces a
    /// closed loop (default). Anything less produces an OPEN arc — the
    /// path is not closed, so a fill will look like a pie slice
    /// (CGPath closes implicitly between endpoints) while a stroke
    /// shows only the arc itself.
    var arcSweep: Double = 1.0

    private static let sampleCount = 360
    private static let minExponent: Double = 2.0
    private static let maxExponent: Double = 10.0

    var insetAmount: CGFloat = 0

    /// Maps the UI-facing `roundness` to the Lamé exponent. Linear in n —
    /// visually the curvature change is non-linear but predictable enough.
    private var exponent: Double {
        let r = max(0, min(1, roundness))
        return Self.minExponent + (Self.maxExponent - Self.minExponent) * (1 - r)
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) - insetAmount * 2
        guard side > 0 else { return Path() }
        let r = side / 2
        let cx = rect.midX
        let cy = rect.midY
        let invN = 2.0 / exponent

        // arcSweep < 1 → open arc; >= 1 → full closed loop.
        let sweepFrac = max(0, min(1, arcSweep))
        let isClosed = sweepFrac >= 1.0 - 1e-6
        let startRad = arcStart * .pi / 180
        let totalRad = (isClosed ? 2 : sweepFrac * 2) * .pi
        let segments = isClosed ? Self.sampleCount : max(2, Int((Double(Self.sampleCount) * sweepFrac).rounded()))

        var path = Path()
        for i in 0...segments {
            let t = startRad + (Double(i) / Double(segments)) * totalRad
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
        if isClosed {
            path.closeSubpath()
        }
        return path
    }

    func inset(by amount: CGFloat) -> SuperellipseShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
