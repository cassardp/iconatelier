import SwiftUI
import Foundation

struct Polygon: Shape, Equatable {
    var sides: Int
    var rotationDegrees: Double

    func path(in rect: CGRect) -> Path {
        let n = max(3, sides)
        let side = min(rect.width, rect.height)
        let radius = side / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = rotationDegrees * .pi / 180
        let step = (2 * .pi) / Double(n)

        var path = Path()
        for i in 0..<n {
            let angle: Double = start + step * Double(i)
            let p = CGPoint(
                x: center.x + radius * CGFloat(Darwin.cos(angle)),
                y: center.y + radius * CGFloat(Darwin.sin(angle))
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}
