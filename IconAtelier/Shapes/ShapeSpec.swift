import SwiftUI

// Shapes are built from a small set of parametric families plus a couple
// of wrappers. Each family case carries ONLY the parameters that matter
// for that family; transformations (stretch + extra rotation) and radial
// repeat are factored out into wrapper cases so the editor can surface
// family-specific sliders without case-by-case branching.
//
//   Family cases (always a base, never a wrapper):
//     .polygon(preset, sides, roundness)     // regular N-gons
//     .star(preset, points, innerDepth, roundness)   // stars + flowers
//     .ellipse(roundness)                    // true circle / superellipse
//     .drop(pointiness, bulbSize, tailOffset, bend)  // parametric teardrop
//     .iosSquircle
//     .customPath(PathPrimitive)
//
//   Wrapper cases (carry a base):
//     .transform(base, stretchX, stretchY, rotation)
//     .radialRepeat(base, count, centerHole)
//
// Wrappers can stack: `.radialRepeat(.transform(.polygon))` is valid.
// They are applied outside-in at render time — the outermost wrapper is
// the last transformation.
//
// `.polygon` and `.star` share `StarPolygonShape` as their internal render
// engine; the split is purely API-side so each family exposes only the
// sliders that make sense for it (a regular hexagon has no "inner depth";
// a 5-point star has no "puff toward 2N-gon").
nonisolated indirect enum ShapeSpec: Hashable, Equatable, Sendable {
    case polygon(
        preset: PolygonPreset,
        sides: Int,
        roundness: Double   // 0...1 — corner fillet fraction
    )
    case star(
        preset: PolygonPreset,
        points: Int,        // tip count
        innerDepth: Double, // 0...1 — how far the indents pull toward the center
        roundness: Double   // 0...1 — same fillet as polygon (flowers = high roundness)
    )
    case drop(
        pointiness: Double, // 0...1 — tip sharpness
        bulbSize: Double,   // 0...1 — bulb width
        tailOffset: Double, // 0...1 — shoulder Y position
        bend: Double        // -1...1 — lateral tip drift
    )
    // Ellipse / circle family — true Lamé curve rather than a high-sided
    // polygon, so a circle stays a circle (no visible facets) at any size.
    // `roundness` controls the squircle-style continuum: 1 = perfect
    // circle/ellipse, 0 = very square corners. Aspect ratio (oval vs round)
    // is layered on via the outer `.transform` wrapper, same as every other
    // parametric family.
    // `arcSweep` < 1 produces an OPEN path (an arc) — combined with a
    // stroke this draws partial rings (half-moon, three-quarter, etc.).
    case ellipse(
        roundness: Double,  // 0...1 — 1 = pure circle, 0 = near-rectangle
        arcStart: Double,   // degrees, -180...180. 0 = right (3 o'clock), -90 = top.
        arcSweep: Double    // 0...1 — fraction of the full revolution to draw. 1 = closed loop.
    )
    // The true Apple icon squircle (Lamé curve, n ≈ 5.2). Parameter-less by
    // design — it must stay pixel-identical to the iOS-icon mask used by
    // the canvas, gallery, and layer thumbnails.
    case iosSquircle
    // Arbitrary frozen silhouette — currently produced by boolean ops and
    // built-in path presets (drop, shield). Flows through the same
    // border/repeat pipeline as any parametric shape.
    case customPath(PathPrimitive)
    // Per-axis stretch and additional rotation, layered over ANY base.
    // For `.polygon` bases the parameters are pushed into the underlying
    // `StarPolygonShape` to reuse its intrinsic bbox-fit; for other bases
    // the wrapper falls back to a Path-level transform-and-refit.
    case transform(
        base: ShapeSpec,
        stretchX: Double,   // 0.3...3 (typical range; clamped at render)
        stretchY: Double,
        rotation: Double    // degrees, ADDITIONAL to any intrinsic rotation
    )
    case radialRepeat(
        base: ShapeSpec,
        count: Int,
        centerHole: Double
    )

    // Plain square is the neutral starting point — the iOS squircle is
    // deliberately NOT the default (it's a fixed primitive, not a
    // parametric polygon).
    static let defaultShape: ShapeSpec = .preset(.square)

    static let defaultRadialRepeat = RadialRepeatParams(
        count: 8, centerHole: 0.0
    )

    static let identityTransform = TransformParams(
        stretchX: 1.0, stretchY: 1.0, rotation: 0.0
    )

    // Build a ShapeSpec from a named preset. Squircle, drop, and shield
    // route to their non-parametric specializations; star-family presets
    // route to `.star`; everything else becomes a `.polygon` with the
    // preset's canonical parameter cell.
    static func preset(_ p: PolygonPreset) -> ShapeSpec {
        switch p.family {
        case .special:
            if p == .squircle { return .iosSquircle }
            if p == .drop {
                let d = DropShape.canonical
                return .drop(
                    pointiness: d.pointiness,
                    bulbSize: d.bulbSize,
                    tailOffset: d.tailOffset,
                    bend: d.bend
                )
            }
            // .free without a family is uncommon — fall back to a squircle-
            // shaped default so the user has something visible to tweak.
            return .iosSquircle
        case .star:
            let c = p.canonical
            return .star(
                preset: p,
                points: c.sides,
                innerDepth: max(0, min(1, -c.bulge)),
                roundness: c.roundness
            )
        case .ellipse:
            return .ellipse(roundness: 1.0, arcStart: -90, arcSweep: 1.0)
        case .polygon:
            let c = p.canonical
            return .polygon(
                preset: p, sides: c.sides, roundness: c.roundness
            )
        }
    }

    var displayName: String {
        switch self {
        case .polygon(let preset, _, _):
            return preset.displayName
        case .star(let preset, _, _, _):
            return preset.displayName
        case .ellipse:
            return "Circle"
        case .drop:
            return "Drop"
        case .iosSquircle:
            return "App Silhouette"
        case .customPath:
            return "Custom"
        case .transform(let base, _, _, _):
            return base.displayName
        case .radialRepeat(let base, _, _):
            return base.displayName
        }
    }

    /// Peel one level of radial-repeat. For peeling every wrapper down to
    /// the underlying family case, see `deepestBase`.
    var unwrapped: ShapeSpec {
        if case .radialRepeat(let base, _, _) = self { return base }
        return self
    }

    /// Recursively peel every wrapper, returning the underlying family case
    /// (`.polygon` / `.iosSquircle` / `.customPath`).
    var deepestBase: ShapeSpec {
        switch self {
        case .transform(let base, _, _, _): return base.deepestBase
        case .radialRepeat(let base, _, _): return base.deepestBase
        default: return self
        }
    }

    var radialRepeatParams: RadialRepeatParams? {
        if case let .radialRepeat(_, count, hole) = self {
            return RadialRepeatParams(count: count, centerHole: hole)
        }
        return nil
    }

    /// The transform params if this spec or its radial-repeat wrap carries
    /// any. Identity (no stretch, no extra rotation) is never present — we
    /// normalize the wrapper away when params collapse to identity.
    var transformParams: TransformParams? {
        switch self {
        case let .transform(_, sx, sy, rot):
            return TransformParams(stretchX: sx, stretchY: sy, rotation: rot)
        case .radialRepeat(let base, _, _):
            return base.transformParams
        default:
            return nil
        }
    }

    func wrappingInRadialRepeat(_ params: RadialRepeatParams) -> ShapeSpec {
        let base: ShapeSpec
        if case .radialRepeat(let b, _, _) = self {
            base = b
        } else {
            base = self
        }
        return .radialRepeat(
            base: base,
            count: params.count,
            centerHole: params.centerHole
        )
    }

    /// Apply (or strip) transform parameters. Identity params remove the
    /// `.transform` wrapper entirely so encoded specs stay minimal.
    /// Any outer `.radialRepeat` wrap is preserved.
    func applyingTransform(_ params: TransformParams) -> ShapeSpec {
        if case let .radialRepeat(base, count, hole) = self {
            return .radialRepeat(
                base: base.applyingTransform(params),
                count: count, centerHole: hole
            )
        }
        let strippedBase: ShapeSpec
        if case .transform(let b, _, _, _) = self {
            strippedBase = b
        } else {
            strippedBase = self
        }
        if params.isIdentity {
            return strippedBase
        }
        return .transform(
            base: strippedBase,
            stretchX: params.stretchX,
            stretchY: params.stretchY,
            rotation: params.rotation
        )
    }

    /// Replace the deepest family base while preserving every wrapper
    /// stacked over it (transform, radial-repeat).
    func replacingBase(with newBase: ShapeSpec) -> ShapeSpec {
        switch self {
        case let .radialRepeat(base, count, hole):
            return .radialRepeat(
                base: base.replacingBase(with: newBase),
                count: count, centerHole: hole
            )
        case let .transform(base, sx, sy, rot):
            return .transform(
                base: base.replacingBase(with: newBase),
                stretchX: sx, stretchY: sy, rotation: rot
            )
        default:
            return newBase
        }
    }

    /// Build the SwiftUI Shape. Corner curvature is controlled intrinsically
    /// by `roundness` on each family case.
    func anyShape() -> AnyShape {
        switch self {
        case let .polygon(preset, sides, roundness):
            return AnyShape(StarPolygonShape(
                sides: sides,
                bulge: 0,
                roundness: roundness,
                rotationDegrees: preset.canonical.rotationDegrees
            ))
        case let .star(preset, points, innerDepth, roundness):
            return AnyShape(StarPolygonShape(
                sides: points,
                bulge: -max(0, min(1, innerDepth)),
                roundness: roundness,
                rotationDegrees: preset.canonical.rotationDegrees
            ))
        case let .drop(pointiness, bulbSize, tailOffset, bend):
            return AnyShape(DropShape(
                pointiness: pointiness,
                bulbSize: bulbSize,
                tailOffset: tailOffset,
                bend: bend
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
            // Polygon and star bases reuse StarPolygonShape's intrinsic
            // stretch and bbox-fit — same vertex math as before the wrapper
            // existed, so projects that drift through this code path keep
            // rendering pixel-identically. Other bases go through
            // TransformedShape, which performs an equivalent Path-level
            // transform.
            if case let .polygon(preset, sides, roundness) = base {
                return AnyShape(StarPolygonShape(
                    sides: sides,
                    bulge: 0,
                    roundness: roundness,
                    rotationDegrees: preset.canonical.rotationDegrees + rot,
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
                base: base.anyShape(),
                stretchX: sx,
                stretchY: sy,
                rotationDegrees: rot
            ))
        case let .radialRepeat(base, count, centerHole):
            return AnyShape(RadialRepeat(
                base: base.anyShape(),
                count: count,
                centerHole: centerHole
            ))
        }
    }

    /// Parametric shapes carry their own corner curvature (`roundness`) —
    /// the Layer-level cornerRadius slider is therefore hidden for them.
    var hasIntrinsicCornerRadius: Bool { true }

    /// True when the deepest family supports per-axis Stretch (and the
    /// `.transform` wrapper). Parameter-less primitives (Squircle, Custom
    /// path) don't expose stretch in the editor.
    var supportsTransform: Bool {
        switch deepestBase {
        case .polygon, .star, .ellipse, .drop: return true
        case .iosSquircle, .customPath: return false
        case .transform, .radialRepeat: return false // unreachable via deepestBase
        }
    }

    /// True when the rendered path is open (an arc, not a closed loop).
    /// Open paths can't be reliably hit-tested via `Path.contains`, so the
    /// renderer falls back to a Rectangle content shape for these.
    var isOpenPath: Bool {
        switch self {
        case let .ellipse(_, _, arcSweep):
            return arcSweep < 1.0 - 1e-6
        case .transform(let base, _, _, _):
            return base.isOpenPath
        case .radialRepeat(let base, _, _):
            return base.isOpenPath
        default:
            return false
        }
    }
}

nonisolated struct RadialRepeatParams: Hashable, Sendable {
    var count: Int
    var centerHole: Double
}

nonisolated struct TransformParams: Hashable, Sendable {
    var stretchX: Double
    var stretchY: Double
    var rotation: Double

    /// True when this set of parameters would render identically to the
    /// untransformed base — used to collapse the `.transform` wrapper away
    /// so it never serializes a useless identity.
    var isIdentity: Bool {
        let eps = 1e-6
        return abs(stretchX - 1) < eps
            && abs(stretchY - 1) < eps
            && abs(rotation) < eps
    }
}

// MARK: - PolygonPreset

// User-facing preset catalog. Each preset maps to a canonical
// `StarPolygonShape` parameter cell, plus a `family` that tells the
// editor which ShapeSpec case to instantiate (polygon, star, or one of
// the non-parametric specials).
nonisolated enum PolygonPreset: String, CaseIterable, Hashable, Sendable, Codable {
    case circle, squircle, roundedSquare, square
    case triangle, pentagon, hexagon, octagon
    case star4, star5, star6, star8
    case flower6, flower8
    case drop
    case free

    enum Family { case polygon, star, ellipse, special }

    /// Routes a preset to the matching ShapeSpec case at construction time.
    /// `.free` is bucketed as polygon by default — when the user drifts
    /// away from a star preset, the editor keeps the spec a `.star` (the
    /// preset just flips to `.free`); the family of `.free` is only
    /// consulted when the picker spawns a fresh shape from it.
    var family: Family {
        switch self {
        case .star4, .star5, .star6, .star8, .flower6, .flower8:
            return .star
        case .circle:
            return .ellipse
        case .squircle, .drop:
            return .special
        default:
            return .polygon
        }
    }

    var displayName: String {
        switch self {
        case .circle: return "Circle"
        case .squircle: return "App Silhouette"
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
        case .drop: return "Drop"
        case .free: return "Custom"
        }
    }

    // Canonical parameter cell. The first vertex of a StarPolygonShape sits
    // at the top by construction, so even-sided shapes (square, octagon)
    // need an explicit rotation to land axis-aligned ("flat side up")
    // rather than diamond-oriented.
    var canonical: StarPolygonShape {
        switch self {
        case .circle:        return .init(sides: 24, bulge: 1,    roundness: 1,    rotationDegrees: 0)
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
        // Drop routes through its own parametric `DropShape` — this slot
        // only exists to satisfy the exhaustive switch.
        case .drop:          return .init(sides: 4, bulge: 0,     roundness: 0,    rotationDegrees: 45)
        case .free:          return .init(sides: 4, bulge: 0,     roundness: 0,    rotationDegrees: 45)
        }
    }

    static let pickerOrder: [PolygonPreset] = [
        .square, .circle, .triangle, .star5, .flower6, .drop, .squircle
    ]
}

// MARK: - Codable

nonisolated extension ShapeSpec: Codable {
    private enum CaseKey: String, CodingKey {
        case polygon, star, drop, ellipse, iosSquircle, radialRepeat, customPath, transform
    }
    private enum PolygonKeys: String, CodingKey {
        case preset, sides, roundness
    }
    private enum StarKeys: String, CodingKey {
        case preset, points, innerDepth, roundness
    }
    private enum DropKeys: String, CodingKey {
        case pointiness, bulbSize, tailOffset, bend
    }
    private enum EllipseKeys: String, CodingKey {
        case roundness, arcStart, arcSweep
    }
    private enum RadialKeys: String, CodingKey {
        // `phaseDegrees` and `alternateScale` were removed; the decoder
        // silently ignores them so legacy project JSON keeps loading.
        case base, count, centerHole
    }
    private enum TransformKeys: String, CodingKey {
        case base, stretchX, stretchY, rotation
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
            let roundness = try nested.decode(Double.self, forKey: .roundness)
            self = .polygon(preset: preset, sides: sides, roundness: roundness)
            return
        }
        if container.contains(.star) {
            let nested = try container.nestedContainer(keyedBy: StarKeys.self, forKey: .star)
            let preset = try nested.decode(PolygonPreset.self, forKey: .preset)
            let points = try nested.decode(Int.self, forKey: .points)
            let innerDepth = try nested.decode(Double.self, forKey: .innerDepth)
            let roundness = try nested.decode(Double.self, forKey: .roundness)
            self = .star(
                preset: preset, points: points,
                innerDepth: innerDepth, roundness: roundness
            )
            return
        }
        if container.contains(.drop) {
            let nested = try container.nestedContainer(keyedBy: DropKeys.self, forKey: .drop)
            let pointiness = try nested.decode(Double.self, forKey: .pointiness)
            let bulbSize = try nested.decode(Double.self, forKey: .bulbSize)
            let tailOffset = try nested.decode(Double.self, forKey: .tailOffset)
            let bend = try nested.decode(Double.self, forKey: .bend)
            self = .drop(
                pointiness: pointiness, bulbSize: bulbSize,
                tailOffset: tailOffset, bend: bend
            )
            return
        }
        if container.contains(.ellipse) {
            let nested = try container.nestedContainer(keyedBy: EllipseKeys.self, forKey: .ellipse)
            let roundness = try nested.decode(Double.self, forKey: .roundness)
            // Arc params added later — default to a full closed ellipse so
            // pre-arc projects decode unchanged.
            let arcStart = try nested.decodeIfPresent(Double.self, forKey: .arcStart) ?? -90
            let arcSweep = try nested.decodeIfPresent(Double.self, forKey: .arcSweep) ?? 1.0
            self = .ellipse(roundness: roundness, arcStart: arcStart, arcSweep: arcSweep)
            return
        }
        if container.contains(.customPath) {
            let primitive = try container.decode(PathPrimitive.self, forKey: .customPath)
            self = .customPath(primitive)
            return
        }
        if container.contains(.transform) {
            let nested = try container.nestedContainer(keyedBy: TransformKeys.self, forKey: .transform)
            let base = try nested.decode(ShapeSpec.self, forKey: .base)
            let sx = try nested.decode(Double.self, forKey: .stretchX)
            let sy = try nested.decode(Double.self, forKey: .stretchY)
            let rot = try nested.decode(Double.self, forKey: .rotation)
            self = .transform(base: base, stretchX: sx, stretchY: sy, rotation: rot)
            return
        }
        if container.contains(.radialRepeat) {
            let nested = try container.nestedContainer(keyedBy: RadialKeys.self, forKey: .radialRepeat)
            let base = try nested.decode(ShapeSpec.self, forKey: .base)
            let count = try nested.decode(Int.self, forKey: .count)
            let centerHole = try nested.decode(Double.self, forKey: .centerHole)
            self = .radialRepeat(
                base: base,
                count: count,
                centerHole: centerHole
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
        case .customPath(let primitive):
            try container.encode(primitive, forKey: .customPath)
        case let .polygon(preset, sides, roundness):
            var nested = container.nestedContainer(keyedBy: PolygonKeys.self, forKey: .polygon)
            try nested.encode(preset, forKey: .preset)
            try nested.encode(sides, forKey: .sides)
            try nested.encode(roundness, forKey: .roundness)
        case let .star(preset, points, innerDepth, roundness):
            var nested = container.nestedContainer(keyedBy: StarKeys.self, forKey: .star)
            try nested.encode(preset, forKey: .preset)
            try nested.encode(points, forKey: .points)
            try nested.encode(innerDepth, forKey: .innerDepth)
            try nested.encode(roundness, forKey: .roundness)
        case let .drop(pointiness, bulbSize, tailOffset, bend):
            var nested = container.nestedContainer(keyedBy: DropKeys.self, forKey: .drop)
            try nested.encode(pointiness, forKey: .pointiness)
            try nested.encode(bulbSize, forKey: .bulbSize)
            try nested.encode(tailOffset, forKey: .tailOffset)
            try nested.encode(bend, forKey: .bend)
        case let .ellipse(roundness, arcStart, arcSweep):
            var nested = container.nestedContainer(keyedBy: EllipseKeys.self, forKey: .ellipse)
            try nested.encode(roundness, forKey: .roundness)
            try nested.encode(arcStart, forKey: .arcStart)
            try nested.encode(arcSweep, forKey: .arcSweep)
        case let .transform(base, sx, sy, rot):
            var nested = container.nestedContainer(keyedBy: TransformKeys.self, forKey: .transform)
            try nested.encode(base, forKey: .base)
            try nested.encode(sx, forKey: .stretchX)
            try nested.encode(sy, forKey: .stretchY)
            try nested.encode(rot, forKey: .rotation)
        case let .radialRepeat(base, count, centerHole):
            var nested = container.nestedContainer(keyedBy: RadialKeys.self, forKey: .radialRepeat)
            try nested.encode(base, forKey: .base)
            try nested.encode(count, forKey: .count)
            try nested.encode(centerHole, forKey: .centerHole)
        }
    }
}
