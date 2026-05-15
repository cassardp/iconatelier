import SwiftUI
import Foundation

// A single polygon shape that doubles as a star when `innerRatio` < 1.
//   innerRatio == 1.0 → regular n-gon (n = sides)
//   innerRatio  < 1.0 → n-pointed star (2n alternating vertices)
struct Polygon: Shape, Equatable {
    var sides: Int
    var innerRatio: Double = 1.0
    var rotationDegrees: Double
    /// Corner rounding as a fraction of the bounding side (0 = sharp).
    var cornerRadiusFraction: Double = 0

    func path(in rect: CGRect) -> Path {
        let n = max(3, sides)
        let side = min(rect.width, rect.height)
        let outerRadius = side / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = rotationDegrees * .pi / 180
        let r = side * max(0, min(0.5, cornerRadiusFraction))
        let clampedInner = max(0.05, min(1.0, innerRatio))

        let points: [CGPoint]
        if clampedInner >= 0.999 {
            let step = (2 * .pi) / Double(n)
            points = (0..<n).map { i in
                let angle = start + step * Double(i)
                return CGPoint(
                    x: center.x + outerRadius * CGFloat(Darwin.cos(angle)),
                    y: center.y + outerRadius * CGFloat(Darwin.sin(angle))
                )
            }
        } else {
            let innerRadius = outerRadius * clampedInner
            let step = .pi / Double(n)
            points = (0..<(n * 2)).map { i in
                let rr = i.isMultiple(of: 2) ? outerRadius : innerRadius
                let angle = start + step * Double(i)
                return CGPoint(
                    x: center.x + rr * CGFloat(Darwin.cos(angle)),
                    y: center.y + rr * CGFloat(Darwin.sin(angle))
                )
            }
        }
        return RoundedCornerPath.build(points: points, radius: r)
    }
}
