import SwiftUI

struct DropShape: InsettableShape, Equatable {
    var pointiness: Double
    var bulbSize: Double
    var tailOffset: Double
    var bend: Double
    var tipRoundness: Double
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

        let bulbDiameter = side * (0.40 + bulb * 0.40)
        var r = bulbDiameter / 2
        let maxR = side * 0.40

        var tipHeight = side * (0.20 + 0.50 * tail)

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
        let midY = tipApexY + tipHeight

        let phi = Double.pi * (1 - p)
        let sinHalf = sin(phi / 2)
        let cosHalf = cos(phi / 2)

        let tipHandleRaw = tipHeight * (0.30 + 0.35 * (1 - p))
        let tipHandleLen: Double = {
            guard sinHalf > 1e-6 else { return tipHandleRaw }
            return min(tipHandleRaw, r * 0.95 / sinHalf)
        }()

        let equatorHandleUp = min(tipHeight * 0.55, r * 1.10)

        let equatorHandleDown = (4.0 / 3.0) * r

        let bendMax = min(r * 0.9, (rect.width - bulbDiameter) / 2 + r * 0.4)
        let tipDx = CGFloat(bnd) * bendMax

        let chordDefault = hypot(r, tipHeight)
        let chordRight = hypot(r - Double(tipDx), tipHeight)
        let chordLeft = hypot(r + Double(tipDx), tipHeight)
        let rightScale = chordDefault > 0 ? chordRight / chordDefault : 1
        let leftScale = chordDefault > 0 ? chordLeft / chordDefault : 1

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

        path.addCurve(
            to: rightWidest,
            control1: splitRight.outerCtrl1,
            control2: splitRight.outerCtrl2
        )

        path.addCurve(
            to: leftWidest,
            control1: rightCtrlDown,
            control2: leftCtrlDown
        )

        path.addCurve(
            to: splitLeft.apex,
            control1: splitLeft.outerCtrl2,
            control2: splitLeft.outerCtrl1
        )

        path.addCurve(
            to: splitRight.apex,
            control1: splitLeft.filletCtrl,
            control2: splitRight.filletCtrl
        )
        path.closeSubpath()
        return path
    }
}

nonisolated struct DropParams: Hashable, Sendable {
    var pointiness: Double
    var bulbSize: Double
    var tailOffset: Double
    var bend: Double
    var tipRoundness: Double

    static let canonical = DropParams(
        pointiness: 0.55, bulbSize: 0.60, tailOffset: 0.55,
        bend: 0, tipRoundness: 0
    )
}
