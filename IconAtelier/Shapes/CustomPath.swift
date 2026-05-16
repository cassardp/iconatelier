import SwiftUI
import Foundation

// A serialized Path produced by a boolean operation (or any future
// "freeze the silhouette" feature). Stored normalized so its bbox center
// sits at (0.5, 0.5) in a unit square and its longer dimension spans
// [0, 1]. The shorter dimension is centered with margin — the original
// aspect is preserved automatically through the unit-space coordinates.
//
// PathPrimitive is reserved for boolean-op results. Named built-in shapes
// (drop, polygon, star…) have their own parametric `ShapeSpec` cases.
nonisolated struct PathPrimitive: Hashable, Codable, Sendable {
    enum Element: Hashable, Codable, Sendable {
        case move(x: Double, y: Double)
        case line(x: Double, y: Double)
        case quad(x: Double, y: Double, cx: Double, cy: Double)
        case curve(x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double)
        case close
    }

    var elements: [Element]
    // bbox.width / bbox.height of the original path. Kept for reference
    // (and so the IconProject placement math can derive the layer's logical
    // size); the renderer doesn't need it — the unit coords already encode
    // the aspect.
    var aspect: Double
}

extension PathPrimitive {
    /// Walk `path`'s elements, compute its bbox, and renormalize every
    /// coordinate so the bbox center maps to (0.5, 0.5) and the longer side
    /// spans the unit interval. Returns nil for an empty or degenerate path.
    init?(path: Path) {
        let bbox = path.boundingRect
        guard bbox.width.isFinite, bbox.height.isFinite,
              bbox.width > 0, bbox.height > 0 else { return nil }
        let cx = bbox.midX
        let cy = bbox.midY
        let m = max(bbox.width, bbox.height)

        func map(_ p: CGPoint) -> (Double, Double) {
            (Double((p.x - cx) / m + 0.5), Double((p.y - cy) / m + 0.5))
        }

        var els: [Element] = []
        path.forEach { element in
            switch element {
            case .move(let p):
                let (x, y) = map(p)
                els.append(.move(x: x, y: y))
            case .line(let p):
                let (x, y) = map(p)
                els.append(.line(x: x, y: y))
            case .quadCurve(let p, let c):
                let (x, y) = map(p)
                let (qcx, qcy) = map(c)
                els.append(.quad(x: x, y: y, cx: qcx, cy: qcy))
            case .curve(let p, let c1, let c2):
                let (x, y) = map(p)
                let (c1x, c1y) = map(c1)
                let (c2x, c2y) = map(c2)
                els.append(.curve(
                    x: x, y: y,
                    c1x: c1x, c1y: c1y,
                    c2x: c2x, c2y: c2y
                ))
            case .closeSubpath:
                els.append(.close)
            }
        }
        self.elements = els
        self.aspect = Double(bbox.width / bbox.height)
    }
}

// Renders a stored `PathPrimitive` into a rect. The path is positioned so
// its bbox center lands at the rect center and its longer dimension fills
// the rect's shorter side — the shorter dimension stays proportionally
// smaller, automatically letterboxed.
struct CustomPathShape: InsettableShape, Equatable {
    var primitive: PathPrimitive
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> CustomPathShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) - insetAmount * 2
        guard side > 0 else { return Path() }
        let midX = rect.midX
        let midY = rect.midY

        func map(_ u: Double, _ v: Double) -> CGPoint {
            CGPoint(
                x: midX + (CGFloat(u) - 0.5) * side,
                y: midY + (CGFloat(v) - 0.5) * side
            )
        }

        var p = Path()
        for el in primitive.elements {
            switch el {
            case .move(let x, let y):
                p.move(to: map(x, y))
            case .line(let x, let y):
                p.addLine(to: map(x, y))
            case .quad(let x, let y, let cx, let cy):
                p.addQuadCurve(to: map(x, y), control: map(cx, cy))
            case .curve(let x, let y, let c1x, let c1y, let c2x, let c2y):
                p.addCurve(
                    to: map(x, y),
                    control1: map(c1x, c1y),
                    control2: map(c2x, c2y)
                )
            case .close:
                p.closeSubpath()
            }
        }
        return p
    }
}
