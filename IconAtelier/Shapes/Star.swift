import SwiftUI
import Foundation

struct Star: Shape, Equatable {
    var points: Int
    var innerRatio: Double
    var rotationDegrees: Double

    func path(in rect: CGRect) -> Path {
        let n = max(3, points)
        let side = min(rect.width, rect.height)
        let outerRadius = side / 2
        let innerRadius = outerRadius * max(0.05, min(0.95, innerRatio))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = rotationDegrees * .pi / 180
        let step = .pi / Double(n)

        var path = Path()
        for i in 0..<(n * 2) {
            let r = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle: Double = start + step * Double(i)
            let p = CGPoint(
                x: center.x + r * CGFloat(Darwin.cos(angle)),
                y: center.y + r * CGFloat(Darwin.sin(angle))
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}
