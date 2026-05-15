import SwiftUI
import Foundation

// Drawn in `rect` with the base on the bottom edge (y == rect.maxY) and the
// tip toward the top (y near rect.maxY - length*rect.height). The shape stays
// vertical here; orientation around a center is handled by RadialRepeat.
struct Petal: Shape, Equatable {
    var length: Double      // 0..1 — fraction of rect.height used between base and tip
    var width: Double       // 0..1 — base width as fraction of rect.width
    var pointiness: Double  // 0..1 — 0 = rounded tip, 1 = sharp tip
    var curvature: Double   // -1..1 — sides bulge outward (>0) or pinch inward (<0)

    func path(in rect: CGRect) -> Path {
        let w = rect.width * max(0.05, min(1, width))
        let h = rect.height * max(0.05, min(1, length))
        let cx = rect.midX
        let baseY = rect.maxY
        let tipY = baseY - h
        let baseLeft = CGPoint(x: cx - w / 2, y: baseY)
        let baseRight = CGPoint(x: cx + w / 2, y: baseY)
        let tip = CGPoint(x: cx, y: tipY)

        let p = max(0, min(1, pointiness))
        let c = max(-1, min(1, curvature))

        // How far below the tip the tip-side controls sit. p==1 → controls
        // right at the tip (sharp). p==0 → controls well below the tip
        // (rounded blob).
        let tipBlend = (1 - p) * h * 0.45
        // Lateral push for the base-side controls. Positive curvature pushes
        // them outward (bulged sides); negative pulls them inward (pinched).
        let baseLateral = c * w * 0.45
        // Mid-height anchor for the base-side controls.
        let baseMidY = baseY - h * 0.5

        let leftCtrl1 = CGPoint(x: baseLeft.x + baseLateral, y: baseMidY)
        let leftCtrl2 = CGPoint(x: cx - w * 0.18, y: tipY + tipBlend)
        let rightCtrl1 = CGPoint(x: cx + w * 0.18, y: tipY + tipBlend)
        let rightCtrl2 = CGPoint(x: baseRight.x - baseLateral, y: baseMidY)

        var path = Path()
        path.move(to: baseLeft)
        path.addCurve(to: tip, control1: leftCtrl1, control2: leftCtrl2)
        path.addCurve(to: baseRight, control1: rightCtrl1, control2: rightCtrl2)
        path.closeSubpath()
        return path
    }
}
