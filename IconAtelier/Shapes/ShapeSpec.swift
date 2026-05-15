import SwiftUI

// RadialRepeat is stored as a wrapping case (`.radialRepeat(base:…)`). Layer
// creation always produces an unwrapped base shape — the radial form is an
// editor-side effect surfaced as a toggle in the EditSheet, which wraps the
// current spec when enabled and unwraps it when disabled.
nonisolated indirect enum ShapeSpec: Hashable, Equatable, Sendable {
    case polygon(sides: Int, innerRatio: Double, rotation: Double)
    case squircle
    case radialRepeat(
        base: ShapeSpec,
        count: Int,
        centerHole: Double,
        phaseDegrees: Double,
        alternateScale: Double
    )

    static let defaultPolygon: ShapeSpec = .polygon(sides: 6, innerRatio: 1.0, rotation: -90)
    static let defaultStar: ShapeSpec = .polygon(sides: 5, innerRatio: 0.5, rotation: -90)
    static let defaultSquircle: ShapeSpec = .squircle

    /// Exact iPhone app-icon corner ratio. SquircleShape uses this directly;
    /// it isn't user-tweakable (the slider is hidden via `hasIntrinsicCornerRadius`).
    static let defaultSquircleCornerRadius: Double = 0.2237

    static let defaultRadialRepeat = RadialRepeatParams(
        count: 8,
        centerHole: 0.0,
        phaseDegrees: -90,
        alternateScale: 1.0
    )

    var displayName: String {
        switch self {
        case .polygon: return "Polygon"
        case .squircle: return "Squircle"
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

    /// Build the SwiftUI Shape, optionally rounding corners.
    func anyShape(cornerRadiusFraction: Double = 0) -> AnyShape {
        switch self {
        case let .polygon(sides, innerRatio, rotation):
            return AnyShape(Polygon(
                sides: sides,
                innerRatio: innerRatio,
                rotationDegrees: rotation,
                cornerRadiusFraction: cornerRadiusFraction
            ))
        case .squircle:
            return AnyShape(SquircleShape())
        case let .radialRepeat(base, count, centerHole, phaseDegrees, alternateScale):
            return AnyShape(RadialRepeat(
                base: base.anyShape(cornerRadiusFraction: cornerRadiusFraction),
                count: count,
                centerHole: centerHole,
                phaseDegrees: phaseDegrees,
                alternateScale: alternateScale
            ))
        }
    }

    /// True when the shape's corner radius is fixed by the preset and the
    /// user shouldn't see the Layer-level cornerRadius slider. Currently only
    /// the squircle preset (locked to the iPhone app-icon ratio).
    var hasIntrinsicCornerRadius: Bool {
        if case .squircle = self { return true }
        return false
    }
}

struct RadialRepeatParams: Hashable, Sendable {
    var count: Int
    var centerHole: Double
    var phaseDegrees: Double
    var alternateScale: Double
}

// MARK: - Codable

// Custom Codable conformance to migrate legacy `.star` JSON produced by
// earlier versions of the app:
//   - `.star(points, innerRatio, rotation)` → `.polygon(sides: points, …)`
// The legacy `.squircle(cornerRadiusFraction)` payload is also accepted and
// mapped to the parameterless `.squircle` case (its corner radius is now
// intrinsic — locked to the iPhone app-icon ratio).
extension ShapeSpec: Codable {
    private enum CaseKey: String, CodingKey {
        case polygon, star, squircle, radialRepeat
    }
    private enum PolygonKeys: String, CodingKey { case sides, innerRatio, rotation }
    private enum LegacyStarKeys: String, CodingKey { case points, innerRatio, rotation }
    private enum LegacySquircleKeys: String, CodingKey { case cornerRadiusFraction }
    private enum RadialKeys: String, CodingKey {
        case base, count, centerHole, phaseDegrees, alternateScale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CaseKey.self)

        if container.contains(.polygon) {
            let nested = try container.nestedContainer(keyedBy: PolygonKeys.self, forKey: .polygon)
            let sides = try nested.decode(Int.self, forKey: .sides)
            let innerRatio = try nested.decodeIfPresent(Double.self, forKey: .innerRatio) ?? 1.0
            let rotation = try nested.decode(Double.self, forKey: .rotation)
            self = .polygon(sides: sides, innerRatio: innerRatio, rotation: rotation)
            return
        }
        if container.contains(.star) {
            let nested = try container.nestedContainer(keyedBy: LegacyStarKeys.self, forKey: .star)
            let points = try nested.decode(Int.self, forKey: .points)
            let innerRatio = try nested.decode(Double.self, forKey: .innerRatio)
            let rotation = try nested.decode(Double.self, forKey: .rotation)
            self = .polygon(sides: points, innerRatio: innerRatio, rotation: rotation)
            return
        }
        if container.contains(.squircle) {
            // Accepts both legacy `{ cornerRadiusFraction: … }` payloads and
            // the new empty marker — the radius is intrinsic now.
            self = .squircle
            return
        }
        if container.contains(.radialRepeat) {
            let nested = try container.nestedContainer(keyedBy: RadialKeys.self, forKey: .radialRepeat)
            let base = try nested.decode(ShapeSpec.self, forKey: .base)
            let count = try nested.decode(Int.self, forKey: .count)
            let centerHole = try nested.decode(Double.self, forKey: .centerHole)
            let phaseDegrees = try nested.decode(Double.self, forKey: .phaseDegrees)
            let alternateScale = try nested.decode(Double.self, forKey: .alternateScale)
            self = .radialRepeat(
                base: base,
                count: count,
                centerHole: centerHole,
                phaseDegrees: phaseDegrees,
                alternateScale: alternateScale
            )
            return
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: container.codingPath,
            debugDescription: "Unknown ShapeSpec case"
        ))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CaseKey.self)
        switch self {
        case let .polygon(sides, innerRatio, rotation):
            var nested = container.nestedContainer(keyedBy: PolygonKeys.self, forKey: .polygon)
            try nested.encode(sides, forKey: .sides)
            try nested.encode(innerRatio, forKey: .innerRatio)
            try nested.encode(rotation, forKey: .rotation)
        case .squircle:
            _ = container.nestedContainer(keyedBy: LegacySquircleKeys.self, forKey: .squircle)
        case let .radialRepeat(base, count, centerHole, phaseDegrees, alternateScale):
            var nested = container.nestedContainer(keyedBy: RadialKeys.self, forKey: .radialRepeat)
            try nested.encode(base, forKey: .base)
            try nested.encode(count, forKey: .count)
            try nested.encode(centerHole, forKey: .centerHole)
            try nested.encode(phaseDegrees, forKey: .phaseDegrees)
            try nested.encode(alternateScale, forKey: .alternateScale)
        }
    }
}
