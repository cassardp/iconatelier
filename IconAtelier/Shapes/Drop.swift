import SwiftUI

// Parametric teardrop. Built from four cubics joining four anchor points:
// top tip, right shoulder, bottom, left shoulder. Each parameter shapes a
// different aspect of the silhouette without disturbing the others:
//
//   pointiness  — tip sharpness (0 = round head, 1 = needle)
//   bulbSize    — width of the bulb at the shoulders (0 = pinch, 1 = full)
//   tailOffset  — vertical position of the shoulders (0 = high, 1 = low)
//   bend        — lateral tip displacement (-1 = left, 0 = straight, 1 = right)
//
// The path is built in a unit square and then refit to the target rect via
// its bounding box, so a non-zero `bend` still produces a drop that fills
// the bounds — the silhouette curls within, it doesn't drift off-center.
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

        // Anchor geometry in unit space (top-left origin, y down).
        let shoulderY = 0.45 + tail * 0.35              // 0.45...0.80
        let halfW = max(0.10, bulb * 0.5)               // 0.10...0.50 (never degenerate)
        let shoulderR = 0.5 + halfW
        let shoulderL = 0.5 - halfW
        let tipX = 0.5 + bnd * 0.35                     // tip drifts off-center; refit fixes it

        // Cubic control points. The tip handles' Y distance from the tip
        // governs sharpness — short = needle, long = round head.
        let tipHandleY = shoulderY * (0.35 - 0.30 * p)
        let shoulderTopHandleY = shoulderY * 0.45
        let shoulderBotHandleY = shoulderY + (1 - shoulderY) * 0.63
        let bottomHandleX = halfW * 0.56

        var unitPath = Path()
        unitPath.move(to: CGPoint(x: tipX, y: 0))
        // Tip → right shoulder
        unitPath.addCurve(
            to: CGPoint(x: shoulderR, y: shoulderY),
            control1: CGPoint(x: tipX, y: tipHandleY),
            control2: CGPoint(x: shoulderR, y: shoulderTopHandleY)
        )
        // Right shoulder → bottom
        unitPath.addCurve(
            to: CGPoint(x: 0.5, y: 1.0),
            control1: CGPoint(x: shoulderR, y: shoulderBotHandleY),
            control2: CGPoint(x: 0.5 + bottomHandleX, y: 1.0)
        )
        // Bottom → left shoulder
        unitPath.addCurve(
            to: CGPoint(x: shoulderL, y: shoulderY),
            control1: CGPoint(x: 0.5 - bottomHandleX, y: 1.0),
            control2: CGPoint(x: shoulderL, y: shoulderBotHandleY)
        )
        // Left shoulder → tip
        unitPath.addCurve(
            to: CGPoint(x: tipX, y: 0),
            control1: CGPoint(x: shoulderL, y: shoulderTopHandleY),
            control2: CGPoint(x: tipX, y: tipHandleY)
        )
        unitPath.closeSubpath()

        // Refit the unit-space bbox to the target square so a bent drop
        // stays centered and fills the bounds along its longer axis.
        let bbox = unitPath.boundingRect
        guard bbox.width > 0, bbox.height > 0 else { return Path() }
        let fit = CGFloat(side) / max(bbox.width, bbox.height)
        let transform = CGAffineTransform.identity
            .translatedBy(x: rect.midX, y: rect.midY)
            .scaledBy(x: fit, y: fit)
            .translatedBy(x: -bbox.midX, y: -bbox.midY)
        return unitPath.applying(transform)
    }
}

extension DropShape {
    /// Canonical default — visually close to the original static teardrop,
    /// so swapping `.customPath(.drop)` for `.drop(default)` on first load
    /// is unsurprising.
    nonisolated static let canonical = DropParams(
        pointiness: 0.6, bulbSize: 1.0, tailOffset: 0.5, bend: 0
    )
}

struct DropParams: Hashable, Sendable {
    var pointiness: Double
    var bulbSize: Double
    var tailOffset: Double
    var bend: Double
}
