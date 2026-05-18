import SwiftUI
import Foundation

nonisolated struct PathPrimitive: Hashable, Codable, Sendable {
    enum Element: Hashable, Codable, Sendable {
        case move(x: Double, y: Double)
        case line(x: Double, y: Double)
        case quad(x: Double, y: Double, cx: Double, cy: Double)
        case curve(x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double)
        case close
    }

    var elements: [Element]

    var aspect: Double
}

extension PathPrimitive {

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
