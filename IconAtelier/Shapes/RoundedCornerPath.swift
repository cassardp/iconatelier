import SwiftUI
import Foundation

// Builds a closed Path through the given vertices, rounding each corner with
// the requested radius. Uses CoreGraphics' tangent-arc API, which clamps the
// effective radius to what fits along each edge — so the caller can pass any
// value without worrying about overshoot.
enum RoundedCornerPath {
    static func build(points: [CGPoint], radius: CGFloat) -> Path {
        guard points.count >= 3 else { return Path() }
        guard radius > 0.5 else {
            var p = Path()
            p.move(to: points[0])
            for i in 1..<points.count { p.addLine(to: points[i]) }
            p.closeSubpath()
            return p
        }

        var path = Path()
        let n = points.count
        // Start on the midpoint of the edge entering vertex 0 so the first
        // tangent-arc has a well-defined current point.
        let prev = points[n - 1]
        let first = points[0]
        path.move(to: midpoint(prev, first))
        for i in 0..<n {
            let vertex = points[i]
            let next = points[(i + 1) % n]
            path.addArc(tangent1End: vertex, tangent2End: next, radius: radius)
        }
        path.closeSubpath()
        return path
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
