import SwiftUI
import Foundation

nonisolated struct StarPolygonCanonical: Hashable, Sendable {
    var sides: Int
    var bulge: Double
    var roundness: Double
    var rotationDegrees: Double = 0
}

struct StarPolygonShape: InsettableShape, Equatable {
    var sides: Int
    var bulge: Double
    var roundness: Double
    var rotationDegrees: Double = 0

    var stretchX: Double = 1
    var stretchY: Double = 1

    var insetAmount: CGFloat = 0

    private static let pinchCap: Double = 0.97

    private static let straightAngleTolerance: Double = 0.001

    func inset(by amount: CGFloat) -> StarPolygonShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let n = max(2, min(sides, 64))
        let side = min(rect.width, rect.height) - insetAmount * 2
        guard side > 0 else { return Path() }
        let outer = Double(side) / 2
        let cx = Double(rect.midX)
        let cy = Double(rect.midY)
        let startAngle = rotationDegrees * .pi / 180 - .pi / 2
        let clampedBulge = min(1, max(-Self.pinchCap, bulge))

        let chordRadius = outer * Darwin.cos(.pi / Double(n))
        let inner: Double
        if clampedBulge >= 0 {
            inner = chordRadius + (outer - chordRadius) * clampedBulge
        } else {
            inner = chordRadius * (1 + clampedBulge)
        }
        let count = 2 * n

        var local: [(x: Double, y: Double)] = []
        local.reserveCapacity(count)
        for i in 0..<count {
            let angle = startAngle + Double(i) * .pi / Double(n)
            let radius = i.isMultiple(of: 2) ? outer : inner
            local.append((radius * Darwin.cos(angle), radius * Darwin.sin(angle)))
        }

        let sx = max(0.01, stretchX)
        let sy = max(0.01, stretchY)

        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity
        for v in local {
            let x = v.x * sx
            let y = v.y * sy
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
        let bboxW = maxX - minX
        let bboxH = maxY - minY
        let bboxMidX = (maxX + minX) / 2
        let bboxMidY = (maxY + minY) / 2
        let fit = Double(side) / max(bboxW, bboxH)

        var pts: [CGPoint] = []
        pts.reserveCapacity(count)
        for v in local {
            pts.append(CGPoint(
                x: cx + (v.x * sx - bboxMidX) * fit,
                y: cy + (v.y * sy - bboxMidY) * fit
            ))
        }

        let clampedRoundness = min(1, max(0, roundness))

        if clampedRoundness <= 0 {
            var p = Path()
            p.move(to: pts[0])
            for i in 1..<count { p.addLine(to: pts[i]) }
            p.closeSubpath()
            return p
        }

        var path = Path()

        let firstMid = CGPoint(
            x: (pts[count - 1].x + pts[0].x) / 2,
            y: (pts[count - 1].y + pts[0].y) / 2
        )
        path.move(to: firstMid)
        for i in 0..<count {
            let a = pts[(i + count - 1) % count]
            let b = pts[i]
            let c = pts[(i + 1) % count]
            let r = filletRadius(a: a, b: b, c: c, factor: clampedRoundness)
            if r <= 0 {
                path.addLine(to: b)
            } else {
                path.addArc(tangent1End: b, tangent2End: c, radius: r)
            }
        }
        path.closeSubpath()
        return path
    }

    private func filletRadius(
        a: CGPoint, b: CGPoint, c: CGPoint, factor: Double
    ) -> CGFloat {
        let vBAx = Double(a.x - b.x); let vBAy = Double(a.y - b.y)
        let vBCx = Double(c.x - b.x); let vBCy = Double(c.y - b.y)
        let lenBA = Darwin.hypot(vBAx, vBAy)
        let lenBC = Darwin.hypot(vBCx, vBCy)
        guard lenBA > 0, lenBC > 0 else { return 0 }
        let cosA = (vBAx * vBCx + vBAy * vBCy) / (lenBA * lenBC)
        let interior = Darwin.acos(min(1, max(-1, cosA)))
        if interior > .pi - Self.straightAngleTolerance { return 0 }

        let tangentDist = min(lenBA, lenBC) / 2
        let halfTan = Darwin.tan(interior / 2)
        return CGFloat(factor * tangentDist * halfTan)
    }
}

// MARK: - Animatable

nonisolated extension StarPolygonShape: Animatable {

    typealias Pair = AnimatablePair
    var animatableData: Pair<Pair<Pair<Double, Double>, Pair<Double, Double>>, Double> {
        get {
            Pair(
                Pair(Pair(bulge, roundness), Pair(stretchX, stretchY)),
                rotationDegrees
            )
        }
        set {
            bulge = newValue.first.first.first
            roundness = newValue.first.first.second
            stretchX = newValue.first.second.first
            stretchY = newValue.first.second.second
            rotationDegrees = newValue.second
        }
    }
}

// MARK: - Preview
