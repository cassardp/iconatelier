import SwiftUI

struct TransformedShape: Shape {
    var base: AnyShape
    var stretchX: Double
    var stretchY: Double
    var rotationDegrees: Double
    var arc: Double = 0

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        guard side > 0 else { return Path() }

        let baseRect = CGRect(
            x: -side / 2, y: -side / 2, width: side, height: side
        )
        let basePath = base.path(in: baseRect)
        if basePath.isEmpty { return Path() }

        let rad = rotationDegrees * .pi / 180
        let sx = max(0.01, stretchX)
        let sy = max(0.01, stretchY)
        let rotateThenScale = CGAffineTransform(rotationAngle: CGFloat(rad))
            .concatenating(CGAffineTransform(scaleX: CGFloat(sx), y: CGFloat(sy)))
        let transformed = basePath.applying(rotateThenScale)

        let bent = Self.applyingBend(transformed, amount: arc)

        let bbox = bent.boundingRect
        guard bbox.width > 0, bbox.height > 0 else { return Path() }

        let fit = CGFloat(side) / max(bbox.width, bbox.height)
        let fitTransform = CGAffineTransform.identity
            .translatedBy(x: rect.midX, y: rect.midY)
            .scaledBy(x: fit, y: fit)
            .translatedBy(x: -bbox.midX, y: -bbox.midY)
        return bent.applying(fitTransform)
    }

    private static let bendSamples = 18

    static func applyingBend(_ path: Path, amount: Double) -> Path {
        guard abs(amount) > 1e-6 else { return path }
        let box = path.boundingRect
        let halfWidth = Double(box.width) / 2
        guard halfWidth > 0 else { return path }
        let centerX = Double(box.midX)

        func warp(_ p: CGPoint) -> CGPoint {
            let nx = (Double(p.x) - centerX) / halfWidth
            let dy = amount * halfWidth * (1 - nx * nx)
            return CGPoint(x: p.x, y: CGFloat(Double(p.y) - dy))
        }

        var result = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        path.forEach { element in
            switch element {
            case .move(let to):
                current = to
                subpathStart = to
                result.move(to: warp(to))
            case .line(let to):
                appendLine(to: &result, from: current, to: to, warp: warp)
                current = to
            case .quadCurve(let to, let control):
                appendQuad(to: &result, from: current, end: to, control: control, warp: warp)
                current = to
            case .curve(let to, let control1, let control2):
                appendCubic(to: &result, from: current, end: to, c1: control1, c2: control2, warp: warp)
                current = to
            case .closeSubpath:
                appendLine(to: &result, from: current, to: subpathStart, warp: warp)
                result.closeSubpath()
                current = subpathStart
            }
        }
        return result
    }

    private static func appendLine(
        to path: inout Path, from a: CGPoint, to b: CGPoint,
        warp: (CGPoint) -> CGPoint
    ) {
        for i in 1...bendSamples {
            let t = CGFloat(i) / CGFloat(bendSamples)
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            path.addLine(to: warp(p))
        }
    }

    private static func appendQuad(
        to path: inout Path, from a: CGPoint, end b: CGPoint, control c: CGPoint,
        warp: (CGPoint) -> CGPoint
    ) {
        for i in 1...bendSamples {
            let t = CGFloat(i) / CGFloat(bendSamples)
            let mt = 1 - t
            let p = CGPoint(
                x: mt * mt * a.x + 2 * mt * t * c.x + t * t * b.x,
                y: mt * mt * a.y + 2 * mt * t * c.y + t * t * b.y
            )
            path.addLine(to: warp(p))
        }
    }

    private static func appendCubic(
        to path: inout Path, from a: CGPoint, end b: CGPoint,
        c1: CGPoint, c2: CGPoint,
        warp: (CGPoint) -> CGPoint
    ) {
        for i in 1...bendSamples {
            let t = CGFloat(i) / CGFloat(bendSamples)
            let mt = 1 - t
            let p = CGPoint(
                x: mt * mt * mt * a.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * b.x,
                y: mt * mt * mt * a.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * b.y
            )
            path.addLine(to: warp(p))
        }
    }
}
