import SwiftUI

// The single parametric primitive: every shape layer is a `StarPolygonShape`
// instance. A `preset` field carries the user-visible label and lets the
// editor highlight the active tile in the preset picker — touching a slider
// flips `preset` to `.free` so the layer no longer claims to match a
// canonical preset.
//
// `RadialRepeat` is stored as a wrapping case. Layer creation always
// produces an unwrapped polygon layer — the radial form is an editor-side
// effect surfaced as a toggle, which wraps the current spec when enabled
// and unwraps it when disabled.
nonisolated indirect enum ShapeSpec: Hashable, Equatable, Sendable {
    case polygon(
        preset: PolygonPreset,
        sides: Int,
        bulge: Double,      // -1...+1 — pinch (toward star) ↔ puff (toward 2N-gon)
        roundness: Double,  // 0...1 — corner fillet fraction
        stretchX: Double,   // 0.3...3 — per-axis stretch (dominant axis fits)
        stretchY: Double,
        rotation: Double    // degrees
    )
    // The true Apple icon squircle (Lamé curve, n ≈ 5.2). Intentionally
    // parameter-less: it must stay pixel-identical to the iOS-icon mask
    // used by the canvas, gallery, and layer thumbnails. Users get this
    // case by tapping the Squircle preset tile.
    case iosSquircle
    case radialRepeat(
        base: ShapeSpec,
        count: Int,
        centerHole: Double,
        phaseDegrees: Double,
        alternateScale: Double
    )

    // The default shape used when a user taps "Shape" in the toolbar.
    static let defaultShape: ShapeSpec = .iosSquircle

    static let defaultRadialRepeat = RadialRepeatParams(
        count: 8,
        centerHole: 0.0,
        phaseDegrees: -90,
        alternateScale: 1.0
    )

    // Build a ShapeSpec from a named preset. `.free` collapses to a neutral
    // squircle-shaped parameter set so the user has something to tweak.
    static func preset(_ p: PolygonPreset) -> ShapeSpec {
        // The Squircle tile is special: it produces the true Lamé curve,
        // not a fillet-approximated PolygonShape. This is what keeps the
        // layer pixel-identical to the iOS-icon silhouette of the app.
        if p == .squircle { return .iosSquircle }
        let c = p.canonical
        return .polygon(
            preset: p,
            sides: c.sides,
            bulge: c.bulge,
            roundness: c.roundness,
            stretchX: c.stretchX,
            stretchY: c.stretchY,
            rotation: c.rotationDegrees
        )
    }

    var displayName: String {
        switch self {
        case .polygon(let preset, _, _, _, _, _, _):
            return preset.displayName
        case .iosSquircle:
            return "Squircle"
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

    /// Build the SwiftUI Shape. `cornerRadiusFraction` is kept on the
    /// signature for compatibility but unused: corner curvature is
    /// controlled intrinsically by `roundness`.
    func anyShape(cornerRadiusFraction: Double = 0) -> AnyShape {
        switch self {
        case let .polygon(_, sides, bulge, roundness, stretchX, stretchY, rotation):
            return AnyShape(StarPolygonShape(
                sides: sides,
                bulge: bulge,
                roundness: roundness,
                rotationDegrees: rotation,
                stretchX: stretchX,
                stretchY: stretchY
            ))
        case .iosSquircle:
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

    /// Parametric shapes carry their own corner curvature (`roundness`) —
    /// the Layer-level cornerRadius slider is therefore hidden for them.
    var hasIntrinsicCornerRadius: Bool { true }
}

struct RadialRepeatParams: Hashable, Sendable {
    var count: Int
    var centerHole: Double
    var phaseDegrees: Double
    var alternateScale: Double
}

// MARK: - PolygonPreset

// User-facing preset catalog. Each preset maps to a canonical
// `StarPolygonShape` parameter cell. `.free` signals the layer was
// customized away from any canonical preset and sliders should drive
// the parameters freely.
nonisolated enum PolygonPreset: String, CaseIterable, Hashable, Sendable, Codable {
    case circle, squircle, roundedSquare, square
    case triangle, pentagon, hexagon, octagon
    case star4, star5, star6, star8
    case flower6, flower8
    case free

    var displayName: String {
        switch self {
        case .circle: return "Circle"
        case .squircle: return "Squircle"
        case .roundedSquare: return "Rounded Square"
        case .square: return "Square"
        case .triangle: return "Triangle"
        case .pentagon: return "Pentagon"
        case .hexagon: return "Hexagon"
        case .octagon: return "Octagon"
        case .star4: return "Star 4"
        case .star5: return "Star 5"
        case .star6: return "Star 6"
        case .star8: return "Star 8"
        case .flower6: return "Flower 6"
        case .flower8: return "Flower 8"
        case .free: return "Custom"
        }
    }

    // Canonical parameter cell. Note on rotation: the polygon's first
    // vertex sits at the top by construction, so even-sided shapes
    // (square, octagon) need an explicit rotation to land axis-aligned
    // ("flat side up") rather than diamond-oriented.
    var canonical: StarPolygonShape {
        switch self {
        case .circle:        return .init(sides: 4, bulge: 0,     roundness: 1.0,  rotationDegrees: 45)
        case .squircle:      return .init(sides: 4, bulge: 0,     roundness: 0.6,  rotationDegrees: 45)
        case .roundedSquare: return .init(sides: 4, bulge: 0,     roundness: 0.3,  rotationDegrees: 45)
        case .square:        return .init(sides: 4, bulge: 0,     roundness: 0,    rotationDegrees: 45)
        case .triangle:      return .init(sides: 3, bulge: 0,     roundness: 0)
        case .pentagon:      return .init(sides: 5, bulge: 0,     roundness: 0)
        case .hexagon:       return .init(sides: 6, bulge: 0,     roundness: 0)
        case .octagon:       return .init(sides: 8, bulge: 0,     roundness: 0,    rotationDegrees: 22.5)
        case .star4:         return .init(sides: 4, bulge: -0.55, roundness: 0,    rotationDegrees: 45)
        case .star5:         return .init(sides: 5, bulge: -0.5,  roundness: 0)
        case .star6:         return .init(sides: 6, bulge: -0.5,  roundness: 0)
        case .star8:         return .init(sides: 8, bulge: -0.45, roundness: 0)
        case .flower6:       return .init(sides: 6, bulge: -0.5,  roundness: 0.85)
        case .flower8:       return .init(sides: 8, bulge: -0.45, roundness: 0.85)
        case .free:          return .init(sides: 4, bulge: 0,     roundness: 0,    rotationDegrees: 45)
        }
    }

    // The minimal "family" tiles shown in the picker. Variations (rounded
    // square, soft star, more sides…) are reached through the sliders, not
    // through additional tiles. `.free` isn't a tile — the editor falls
    // into that state automatically when any slider is touched.
    static let pickerOrder: [PolygonPreset] = [
        .squircle, .circle, .square, .triangle, .star5, .flower6
    ]
}

// MARK: - Codable

nonisolated extension ShapeSpec: Codable {
    private enum CaseKey: String, CodingKey {
        case polygon, iosSquircle, radialRepeat
    }
    private enum PolygonKeys: String, CodingKey {
        case preset, sides, bulge, roundness, stretchX, stretchY, rotation
    }
    private enum RadialKeys: String, CodingKey {
        case base, count, centerHole, phaseDegrees, alternateScale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CaseKey.self)

        if container.contains(.iosSquircle) {
            self = .iosSquircle
            return
        }
        if container.contains(.polygon) {
            let nested = try container.nestedContainer(keyedBy: PolygonKeys.self, forKey: .polygon)
            let preset = try nested.decode(PolygonPreset.self, forKey: .preset)
            let sides = try nested.decode(Int.self, forKey: .sides)
            let bulge = try nested.decode(Double.self, forKey: .bulge)
            let roundness = try nested.decode(Double.self, forKey: .roundness)
            let stretchX = try nested.decode(Double.self, forKey: .stretchX)
            let stretchY = try nested.decode(Double.self, forKey: .stretchY)
            let rotation = try nested.decode(Double.self, forKey: .rotation)
            self = .polygon(
                preset: preset,
                sides: sides,
                bulge: bulge,
                roundness: roundness,
                stretchX: stretchX,
                stretchY: stretchY,
                rotation: rotation
            )
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
        case .iosSquircle:
            try container.encode(true, forKey: .iosSquircle)
        case let .polygon(preset, sides, bulge, roundness, stretchX, stretchY, rotation):
            var nested = container.nestedContainer(keyedBy: PolygonKeys.self, forKey: .polygon)
            try nested.encode(preset, forKey: .preset)
            try nested.encode(sides, forKey: .sides)
            try nested.encode(bulge, forKey: .bulge)
            try nested.encode(roundness, forKey: .roundness)
            try nested.encode(stretchX, forKey: .stretchX)
            try nested.encode(stretchY, forKey: .stretchY)
            try nested.encode(rotation, forKey: .rotation)
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
