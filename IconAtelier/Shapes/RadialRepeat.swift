import SwiftUI
import Foundation

struct RadialRepeat<Base: Shape>: Shape {
    var base: Base
    var count: Int
    var centerHole: Double

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

            let local = CGRect(
                x: -unitWid / 2,
                y: -unitLen,
                width: unitWid,
                height: unitLen
            )
            var sub = base.path(in: local)

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
