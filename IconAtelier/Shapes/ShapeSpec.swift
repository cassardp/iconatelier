import SwiftUI

// RadialRepeat is stored as a wrapping case (`.radialRepeat(base:…)`). Layer
// creation always produces an unwrapped base shape — the radial form is an
// editor-side effect surfaced as a toggle in the EditSheet, which wraps the
// current spec when enabled and unwraps it when disabled.
nonisolated indirect enum ShapeSpec: Codable, Hashable, Equatable, Sendable {
    case polygon(sides: Int, rotation: Double)
    case star(points: Int, innerRatio: Double, rotation: Double)
    case squircle(cornerRadiusFraction: Double)
    case radialRepeat(
        base: ShapeSpec,
        count: Int,
        centerHole: Double,
        phaseDegrees: Double,
        alternateScale: Double
    )

    static let defaultPolygon: ShapeSpec = .polygon(sides: 6, rotation: -90)
    static let defaultStar: ShapeSpec = .star(points: 5, innerRatio: 0.5, rotation: -90)
    static let defaultSquircle: ShapeSpec = .squircle(cornerRadiusFraction: 0.2237)

    static let defaultRadialRepeat = RadialRepeatParams(
        count: 8,
        centerHole: 0.0,
        phaseDegrees: -90,
        alternateScale: 1.0
    )

    var displayName: String {
        switch self {
        case .polygon:      return "Polygon"
        case .star:         return "Star"
        case .squircle:     return "Squircle"
        case .radialRepeat(let base, _, _, _, _):
            return base.displayName
        }
    }

    /// The non-wrapped underlying shape — the spec itself unless it is a
    /// `.radialRepeat`, in which case it returns its `base`.
    var unwrapped: ShapeSpec {
        if case .radialRepeat(let base, _, _, _, _) = self { return base }
        return self
    }

    var radialRepeatParams: RadialRepeatParams? {
        if case let .radialRepeat(_, count, hole, phase, alt) = self {
            return RadialRepeatParams(
                count: count,
                centerHole: hole,
                phaseDegrees: phase,
                alternateScale: alt
            )
        }
        return nil
    }

    func wrappingInRadialRepeat(_ params: RadialRepeatParams) -> ShapeSpec {
        let base = self.unwrapped
        return .radialRepeat(
            base: base,
            count: params.count,
            centerHole: params.centerHole,
            phaseDegrees: params.phaseDegrees,
            alternateScale: params.alternateScale
        )
    }

    /// Replace the base shape while preserving any radial-repeat wrap.
    func replacingBase(with newBase: ShapeSpec) -> ShapeSpec {
        if case let .radialRepeat(_, count, hole, phase, alt) = self {
            return .radialRepeat(
                base: newBase,
                count: count,
                centerHole: hole,
                phaseDegrees: phase,
                alternateScale: alt
            )
        }
        return newBase
    }

    func anyShape() -> AnyShape {
        switch self {
        case let .polygon(sides, rotation):
            return AnyShape(Polygon(sides: sides, rotationDegrees: rotation))
        case let .star(points, innerRatio, rotation):
            return AnyShape(Star(points: points, innerRatio: innerRatio, rotationDegrees: rotation))
        case let .squircle(crf):
            return AnyShape(Squircle(cornerRadiusFraction: crf))
        case let .radialRepeat(base, count, centerHole, phaseDegrees, alternateScale):
            return AnyShape(RadialRepeat(
                base: base.anyShape(),
                count: count,
                centerHole: centerHole,
                phaseDegrees: phaseDegrees,
                alternateScale: alternateScale
            ))
        }
    }
}

struct RadialRepeatParams: Hashable, Sendable {
    var count: Int
    var centerHole: Double
    var phaseDegrees: Double
    var alternateScale: Double
}
