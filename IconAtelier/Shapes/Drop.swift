import SwiftUI

// Parametric teardrop with decoupled bulb size, tip elongation, and a
// smooth (no-kink) lateral bend.
//
// Geometry (screen coords, y down):
//   • Bulb = true circle of radius `r` (set by `bulbSize`). The lower
//     hemicircle is rendered with the magic 0.5523 cubic-Bézier
//     approximation.
//   • Shoulders sit on the bulb's equator → tangents leaving the
//     shoulders are vertical, matching the circle.
//   • Tip rises `tipHeight` above the equator (set by `tailOffset`,
//     scaled into the headroom left by the bulb in the rect).
//   • Tip apex carries an opening angle φ = π·(1 − pointiness):
//       - φ = π    → horizontal tangent (perfectly rounded top)
//       - φ = π/2  → 90° tip (slightly rounded)
//       - φ = 0    → vertical tangents (sharp needle, kink)
//     The two cubics meeting at the tip have control points placed
//     symmetrically along that tangent angle, so the transition from
//     "round" to "sharp" is continuous and visually pleasing.
//   • `bend` shifts the upper half horizontally via a smoothstep g(v),
//     where v is the normalized height above the equator. g(0)=g'(0)=0
//     at the shoulders → no kink; g(1)=1 at the tip → full lean.
//     Tip handles, shoulder handles, and the apex itself are all warped
//     by the same field, so the upper silhouette leans as one smooth S.
//
// The drop is sized so that the bulb keeps a stable visible diameter
// regardless of `tailOffset`, and the whole drop is uniformly scaled
// down if it would otherwise overflow the rect.
struct DropShape: InsettableShape, Equatable {
    var pointiness: Double  // 0...1
    var bulbSize: Double    // 0...1
    var tailOffset: Double  // 0...1
    var bend: Double        // -1...1
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> DropShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) - insetAmount * 2
        guard side > 0 else { return Path() }

        let p = max(0, min(1, pointiness))
        let bulb = max(0, min(1, bulbSize))
        let tail = max(0, min(1, tailOffset))
        let bnd = max(-1, min(1, bend))

        // Bulb diameter is a stable fraction of `side`, independent of
        // tail. Tail then elongates the tip into the remaining headroom.
        // If bulb + tail asks for more than `side`, everything is
        // scaled down uniformly.
        let bulbDiameter = side * (0.40 + bulb * 0.40)            // 0.40...0.80 of side
        var r = bulbDiameter / 2
        let maxTipHeight = max(0, side - bulbDiameter)
        var tipHeight = maxTipHeight * (0.30 + tail * 0.85)       // 0.30...1.15 of headroom
        var totalHeight = 2 * r + tipHeight
        if totalHeight > side {
            let s = side / totalHeight
            r *= s
            tipHeight *= s
            totalHeight = side
        }

        let cx = rect.midX
        let topMargin = (side - totalHeight) / 2 + insetAmount
        let tipApexY = rect.minY + topMargin
        let cy = tipApexY + tipHeight + r                          // bulb center y

        // Tip apex opening angle.
        let phi = Double.pi * (1 - p)
        let sinHalf = sin(phi / 2)
        let cosHalf = cos(phi / 2)

        // Handle lengths. Longer tip handle when tip is rounded so the
        // apex broadens; shorter when sharp so the cusp stays tight.
        let tipHandleLen = tipHeight * (0.28 + 0.30 * (1 - p))
        let shoulderHandleLen = tipHeight * 0.55
        let kCircle = 0.5522847498 * r

        // Max lateral lean of the tip (in pt). Capped so the bent tip
        // never escapes the rect's horizontal extent.
        let bendMax = min(r * 0.9, (rect.width - bulbDiameter) / 2 + r * 0.4)

        // Smoothstep warp: g(0) = g'(0) = 0, g(1) = 1, g'(1) = 0.
        // Smooth at both ends → no kink at shoulders or pinch at tip.
        func bendOffset(_ relY: Double) -> CGFloat {
            let v = max(0, min(1, relY))
            let g = v * v * (3 - 2 * v)
            return CGFloat(bnd * g) * bendMax
        }
        func warp(_ point: CGPoint) -> CGPoint {
            guard tipHeight > 0 else { return point }
            let relY = max(0, Double((cy - point.y) / tipHeight))
            return CGPoint(x: point.x + bendOffset(relY), y: point.y)
        }

        // Anchor points.
        let shoulderR = CGPoint(x: cx + r, y: cy)
        let shoulderL = CGPoint(x: cx - r, y: cy)
        let bulbBottom = CGPoint(x: cx, y: cy + r)

        // Tip apex + handles, in the un-warped frame.
        let tipBase = CGPoint(x: cx, y: tipApexY)
        let tipCtrl1Base = CGPoint(
            x: cx + tipHandleLen * sinHalf,
            y: tipApexY + tipHandleLen * cosHalf
        )
        let tipCtrl2Base = CGPoint(
            x: cx - tipHandleLen * sinHalf,
            y: tipApexY + tipHandleLen * cosHalf
        )

        // Shoulder handles aim straight up toward the tip.
        let shoulderCtrlRBase = CGPoint(x: cx + r, y: cy - shoulderHandleLen)
        let shoulderCtrlLBase = CGPoint(x: cx - r, y: cy - shoulderHandleLen)

        // Warp upper-half points/handles.
        let tip = warp(tipBase)
        let tipCtrl1 = warp(tipCtrl1Base)
        let tipCtrl2 = warp(tipCtrl2Base)
        let shoulderCtrlR = warp(shoulderCtrlRBase)
        let shoulderCtrlL = warp(shoulderCtrlLBase)
        // Shoulders, bulb, and bulb-bottom controls are at or below the
        // equator (relY ≤ 0) → smoothstep gives 0 → no warp applied.

        var path = Path()
        path.move(to: tip)
        // Tip → right shoulder.
        path.addCurve(to: shoulderR, control1: tipCtrl1, control2: shoulderCtrlR)
        // Right shoulder → bulb bottom (true quarter circle).
        path.addCurve(
            to: bulbBottom,
            control1: CGPoint(x: cx + r, y: cy + kCircle),
            control2: CGPoint(x: cx + kCircle, y: cy + r)
        )
        // Bulb bottom → left shoulder (true quarter circle).
        path.addCurve(
            to: shoulderL,
            control1: CGPoint(x: cx - kCircle, y: cy + r),
            control2: CGPoint(x: cx - r, y: cy + kCircle)
        )
        // Left shoulder → tip.
        path.addCurve(to: tip, control1: shoulderCtrlL, control2: tipCtrl2)
        path.closeSubpath()
        return path
    }
}

extension DropShape {
    /// Canonical default — full circular bulb, medium tip elongation,
    /// moderately rounded apex, no bend.
    nonisolated static let canonical = DropParams(
        pointiness: 0.55, bulbSize: 0.85, tailOffset: 0.55, bend: 0
    )
}

struct DropParams: Hashable, Sendable {
    var pointiness: Double
    var bulbSize: Double
    var tailOffset: Double
    var bend: Double
}
