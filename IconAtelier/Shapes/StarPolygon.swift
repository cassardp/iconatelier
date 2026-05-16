import SwiftUI
import Foundation

// A regular N-sided polygon with two extra parameters that subsume the
// Gielis-shape family used previously: `bulge` moves alternate vertices
// inward (pinch → star) or outward (puff → 2N-gon), and `roundness`
// fillets every vertex. Replaces GielisShape for the icon-design use case
// where the full Gielis expressivity (asteroids, gears, anisotropic lobes)
// isn't needed.
//
// Geometry:
//   - N "tip" vertices on a circle of radius R = side/2.
//   - N "indent" vertices on the bisector between adjacent tips, at radius
//     interpolated between three reference values by `bulge`:
//       bulge = -1 → inner = 0           (degenerate spike star, clamped)
//       bulge =  0 → inner = R·cos(π/N)  (regular N-gon — indents land on
//                                         the chord between adjacent tips)
//       bulge = +1 → inner = R           (regular 2N-gon, no kink at all)
//   - The 2N vertices are walked in order; each is optionally filleted
//     with radius roundness · (max non-overlapping radius at that corner).
struct StarPolygonShape: InsettableShape, Equatable {
    var sides: Int
    var bulge: Double
    var roundness: Double
    var rotationDegrees: Double = 0
    // Per-axis stretch. Both default to 1 (no stretch). The shape is built
    // in a unit space, then each coordinate is multiplied by its stretch
    // factor, and the whole thing is rescaled to fit the bounding square
    // along its larger axis. So (2, 1) yields a shape twice as wide as
    // tall that still touches the left/right edges of the bounds.
    var stretchX: Double = 1
    var stretchY: Double = 1

    var insetAmount: CGFloat = 0

    // bulge = -1 collapses indents to the center — clamp short of it so
    // the shape stays a renderable, non-degenerate spike star.
    private static let pinchCap: Double = 0.97
    // Near-π interior angles would produce arbitrarily flat fillets; treat
    // as straight so the indent points at star ≈ 0 don't generate spurious
    // arcs along the polygon's straight sides.
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
        // The indent radius is piecewise-linear in bulge:
        //   bulge =  0 → cos(π/N) (regular N-gon — indents on the chord)
        //   bulge = +1 → outer    (regular 2N-gon — no kink)
        //   bulge = -1 → 0        (spike star, clamped by pinchCap)
        let chordRadius = outer * Darwin.cos(.pi / Double(n))
        let inner: Double
        if clampedBulge >= 0 {
            inner = chordRadius + (outer - chordRadius) * clampedBulge
        } else {
            inner = chordRadius * (1 + clampedBulge)
        }
        let count = 2 * n

        // Build the vertex list in centered, unstretched coordinates first
        // so the stretch + fit logic operates on a clean unit shape.
        var local: [(x: Double, y: Double)] = []
        local.reserveCapacity(count)
        for i in 0..<count {
            let angle = startAngle + Double(i) * .pi / Double(n)
            let radius = i.isMultiple(of: 2) ? outer : inner
            local.append((radius * Darwin.cos(angle), radius * Darwin.sin(angle)))
        }

        // Apply per-axis stretch, then rescale so the dominant axis still
        // touches the bounds. With sx=sy=1 the path is unchanged; with
        // sx=2,sy=1 it becomes twice as wide as tall but still fits.
        let sx = max(0.01, stretchX)
        let sy = max(0.01, stretchY)
        let fit = 1.0 / max(sx, sy)

        var pts: [CGPoint] = []
        pts.reserveCapacity(count)
        for v in local {
            pts.append(CGPoint(
                x: cx + v.x * sx * fit,
                y: cy + v.y * sy * fit
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
        // Begin mid-edge so the first emitted segment is an arc with a clean
        // tangent in, not a stray line into the first corner.
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
        // Max non-overlapping fillet: tangent point capped at half of the
        // shorter adjacent edge, then r = tangentDist · tan(α/2).
        let tangentDist = min(lenBA, lenBC) / 2
        let halfTan = Darwin.tan(interior / 2)
        return CGFloat(factor * tangentDist * halfTan)
    }
}

// MARK: - Animatable

nonisolated extension StarPolygonShape: Animatable {
    // sides is Int (a cardinality, not continuous) and insetAmount is
    // driven externally by the modifier chain — neither animates as part
    // of user-visible state changes. The five continuous parameters pack
    // into a 5-deep AnimatablePair tree.
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

