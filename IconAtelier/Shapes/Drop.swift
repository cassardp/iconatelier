import SwiftUI

// Minimal parametric teardrop. The base silhouette uses three anchor
// points joined by three cubic Bézier arcs: tip at top, two widest points
// on the equator. The bottom arc is a single cubic with vertical tangents
// at the equator (handle length 4r/3, the standard half-circle
// approximation).
//
// `tipRoundness` rounds off the apex by De Casteljau-splitting each
// tip→widest cubic at parameter t = tipRoundness · 0.4. The two split
// points become apexL/apexR; a fillet cubic bridges them, with control
// handles taken from the De Casteljau intermediates so C¹ continuity is
// automatic.
//
// `bend` shifts the tip and its two handles laterally; equator handles
// stay vertical, so the up- and down-handles at each widest point remain
// colinear with the anchor → no cusp at the shoulders.
struct DropShape: InsettableShape, Equatable {
    var pointiness: Double   // 0...1
    var bulbSize: Double     // 0...1
    var tailOffset: Double   // 0...1
    var bend: Double         // -1...1
    var tipRoundness: Double // 0...1
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
        let tipR = max(0, min(1, tipRoundness))

        // Bulb width grows with `bulb`. Tip height grows with `tail`
        // alone — independent of `bulb`, so cranking up the bulb makes
        // the silhouette extend DOWNWARD only (the apex and equator stay
        // put). To anchor them, we center the maximum-bulb drop in the
        // rect: smaller bulbs sit with the same apex Y and leave empty
        // space below.
        let bulbDiameter = side * (0.40 + bulb * 0.40)   // 0.40...0.80
        var r = bulbDiameter / 2                           // 0.20...0.40
        let maxR = side * 0.40                             // bulb = 1

        var tipHeight = side * (0.20 + 0.50 * tail)        // 0.20...0.70
        // Anchor span = the drop's height at full bulb. We center that
        // in the rect so the apex Y is invariant under `bulb`. If full
        // bulb would overflow, scale `tipHeight` (and proportionally
        // `r`) so the max-bulb drop fits exactly.
        var anchorSpan = maxR + tipHeight
        if anchorSpan > side {
            let s = side / anchorSpan
            tipHeight *= s
            r = min(r, maxR * s)
            anchorSpan = side
        }

        let cx = rect.midX
        let topMargin = (side - anchorSpan) / 2 + insetAmount
        let tipApexY = rect.minY + topMargin
        let midY = tipApexY + tipHeight        // equator y (invariant)

        // Tip apex opening angle.
        let phi = Double.pi * (1 - p)
        let sinHalf = sin(phi / 2)
        let cosHalf = cos(phi / 2)

        // Handle lengths. Tip handle grows when the apex is rounded, but
        // capped so its lateral projection (tipHandleLen·sinHalf) never
        // exceeds `r` — otherwise the apex flares wider than the equator.
        let tipHandleRaw = tipHeight * (0.30 + 0.35 * (1 - p))
        let tipHandleLen: Double = {
            guard sinHalf > 1e-6 else { return tipHandleRaw }
            return min(tipHandleRaw, r * 0.95 / sinHalf)
        }()
        // Equator → tip handle, capped at ~r to avoid a thin neck on
        // tall narrow drops.
        let equatorHandleUp = min(tipHeight * 0.55, r * 1.10)
        // Equator → bulb-bottom handle. 4r/3 is the standard cubic
        // approximation of a half-circle.
        let equatorHandleDown = (4.0 / 3.0) * r

        // Lateral bend. Only the tip anchor and its two handles drift;
        // equator handles stay vertical. Handle lengths are scaled per
        // side by the side's chord ratio so the two flanks remain
        // equally round when the tip leans.
        let bendMax = min(r * 0.9, (rect.width - bulbDiameter) / 2 + r * 0.4)
        let tipDx = CGFloat(bnd) * bendMax

        let chordDefault = hypot(r, tipHeight)
        let chordRight = hypot(r - Double(tipDx), tipHeight)
        let chordLeft = hypot(r + Double(tipDx), tipHeight)
        let rightScale = chordDefault > 0 ? chordRight / chordDefault : 1
        let leftScale = chordDefault > 0 ? chordLeft / chordDefault : 1

        // Original control points for the two tip→widest cubics.
        let tipApex = CGPoint(x: cx + tipDx, y: tipApexY)
        let rightWidest = CGPoint(x: cx + r, y: midY)
        let leftWidest = CGPoint(x: cx - r, y: midY)

        let tipHandleRight = tipHandleLen * rightScale
        let tipHandleLeft = tipHandleLen * leftScale

        let tipCtrlRight = CGPoint(
            x: tipApex.x + tipHandleRight * sinHalf,
            y: tipApexY + tipHandleRight * cosHalf
        )
        let tipCtrlLeft = CGPoint(
            x: tipApex.x - tipHandleLeft * sinHalf,
            y: tipApexY + tipHandleLeft * cosHalf
        )
        let rightCtrlUp = CGPoint(x: cx + r, y: midY - equatorHandleUp * rightScale)
        let leftCtrlUp = CGPoint(x: cx - r, y: midY - equatorHandleUp * leftScale)
        let rightCtrlDown = CGPoint(x: cx + r, y: midY + equatorHandleDown)
        let leftCtrlDown = CGPoint(x: cx - r, y: midY + equatorHandleDown)

        // De Casteljau split: take each tip→widest cubic and split at
        // t = tipR · 0.4. The split point F becomes the new apex on that
        // side; (E, C) are the outer cubic's controls; D is the
        // intermediate that the fillet borrows to keep C¹ continuity.
        // At tipR = 0, splitT = 0 and the split degenerates: apexR =
        // tipApex, the outer cubic equals the original, and the fillet
        // collapses to a point.
        let splitT = tipR * 0.4

        func split(
            apex: CGPoint, ctrl1: CGPoint, ctrl2: CGPoint, end: CGPoint
        ) -> (apex: CGPoint, outerCtrl1: CGPoint, outerCtrl2: CGPoint, filletCtrl: CGPoint) {
            let t = CGFloat(splitT)
            let aP = CGPoint(
                x: apex.x + t * (ctrl1.x - apex.x),
                y: apex.y + t * (ctrl1.y - apex.y)
            )
            let bP = CGPoint(
                x: ctrl1.x + t * (ctrl2.x - ctrl1.x),
                y: ctrl1.y + t * (ctrl2.y - ctrl1.y)
            )
            let cP = CGPoint(
                x: ctrl2.x + t * (end.x - ctrl2.x),
                y: ctrl2.y + t * (end.y - ctrl2.y)
            )
            let dP = CGPoint(
                x: aP.x + t * (bP.x - aP.x),
                y: aP.y + t * (bP.y - aP.y)
            )
            let eP = CGPoint(
                x: bP.x + t * (cP.x - bP.x),
                y: bP.y + t * (cP.y - bP.y)
            )
            let fP = CGPoint(
                x: dP.x + t * (eP.x - dP.x),
                y: dP.y + t * (eP.y - dP.y)
            )
            return (apex: fP, outerCtrl1: eP, outerCtrl2: cP, filletCtrl: dP)
        }

        let splitRight = split(
            apex: tipApex, ctrl1: tipCtrlRight,
            ctrl2: rightCtrlUp, end: rightWidest
        )
        let splitLeft = split(
            apex: tipApex, ctrl1: tipCtrlLeft,
            ctrl2: leftCtrlUp, end: leftWidest
        )

        var path = Path()
        path.move(to: splitRight.apex)
        // apexR → right widest (outer half of the original right cubic).
        path.addCurve(
            to: rightWidest,
            control1: splitRight.outerCtrl1,
            control2: splitRight.outerCtrl2
        )
        // Bottom of the bulb: single half-circle cubic.
        path.addCurve(
            to: leftWidest,
            control1: rightCtrlDown,
            control2: leftCtrlDown
        )
        // left widest → apexL (outer half of the original left cubic, run
        // backwards — controls swap order).
        path.addCurve(
            to: splitLeft.apex,
            control1: splitLeft.outerCtrl2,
            control2: splitLeft.outerCtrl1
        )
        // Fillet apexL → apexR. control1 = left side's De Casteljau
        // intermediate, control2 = right side's. Both naturally tangent
        // to the surrounding cubics.
        path.addCurve(
            to: splitRight.apex,
            control1: splitLeft.filletCtrl,
            control2: splitRight.filletCtrl
        )
        path.closeSubpath()
        return path
    }
}

extension DropShape {
    /// Canonical default — moderate bulb, medium tip elongation,
    /// moderately rounded apex, no bend, sharp tip (no fillet).
    nonisolated static let canonical = DropParams(
        pointiness: 0.55, bulbSize: 0.60, tailOffset: 0.55,
        bend: 0, tipRoundness: 0
    )
}

struct DropParams: Hashable, Sendable {
    var pointiness: Double
    var bulbSize: Double
    var tailOffset: Double
    var bend: Double
    var tipRoundness: Double
}
