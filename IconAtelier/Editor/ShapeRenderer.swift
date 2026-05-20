import SwiftUI

enum ShapeRenderer {
    static func anyShape(for spec: ShapeSpec) -> AnyShape {
        switch spec {
        case let .polygon(preset, sides, roundness):
            return AnyShape(StarPolygonShape(
                sides: sides,
                bulge: 0,
                roundness: roundness,
                rotationDegrees: preset.defaultPolygonRotation(forSides: sides)
            ))
        case let .star(preset, points, innerDepth, roundness):
            return AnyShape(StarPolygonShape(
                sides: points,
                bulge: -max(0, min(1, innerDepth)),
                roundness: roundness,
                rotationDegrees: preset.canonical.rotationDegrees
            ))
        case let .drop(pointiness, bulbSize, tailOffset, bend, tipRoundness):
            return AnyShape(DropShape(
                pointiness: pointiness,
                bulbSize: bulbSize,
                tailOffset: tailOffset,
                bend: bend,
                tipRoundness: tipRoundness
            ))
        case let .ellipse(roundness, arcStart, arcSweep):
            return AnyShape(SuperellipseShape(
                roundness: roundness,
                arcStart: arcStart,
                arcSweep: arcSweep
            ))
        case .iosSquircle:
            return AnyShape(SquircleShape())
        case .customPath(let primitive):
            return AnyShape(CustomPathShape(primitive: primitive))
        case let .transform(base, sx, sy, rot):
            if case let .polygon(preset, sides, roundness) = base {
                return AnyShape(StarPolygonShape(
                    sides: sides,
                    bulge: 0,
                    roundness: roundness,
                    rotationDegrees: preset.defaultPolygonRotation(forSides: sides) + rot,
                    stretchX: sx,
                    stretchY: sy
                ))
            }
            if case let .star(preset, points, innerDepth, roundness) = base {
                return AnyShape(StarPolygonShape(
                    sides: points,
                    bulge: -max(0, min(1, innerDepth)),
                    roundness: roundness,
                    rotationDegrees: preset.canonical.rotationDegrees + rot,
                    stretchX: sx,
                    stretchY: sy
                ))
            }
            return AnyShape(TransformedShape(
                base: anyShape(for: base),
                stretchX: sx,
                stretchY: sy,
                rotationDegrees: rot
            ))
        case let .radialRepeat(base, count, centerHole, orientation):
            return AnyShape(RadialRepeat(
                base: anyShape(for: base),
                count: count,
                centerHole: centerHole,
                orientation: orientation
            ))
        }
    }

    static func path(for spec: ShapeSpec, in rect: CGRect) -> Path {
        anyShape(for: spec).path(in: rect)
    }
}
