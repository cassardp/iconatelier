import Foundation

nonisolated indirect enum ShapeSpec: Hashable, Equatable, Sendable {
    case polygon(
        preset: PolygonPreset,
        sides: Int,
        roundness: Double
    )
    case star(
        preset: PolygonPreset,
        points: Int,
        innerDepth: Double,
        roundness: Double
    )
    case drop(
        pointiness: Double,
        bulbSize: Double,
        tailOffset: Double,
        bend: Double,
        tipRoundness: Double
    )

    case ellipse(
        roundness: Double,
        arcStart: Double,
        arcSweep: Double
    )

    case iosSquircle

    case customPath(PathPrimitive)

    case transform(
        base: ShapeSpec,
        stretchX: Double,
        stretchY: Double,
        rotation: Double
    )
    case radialRepeat(
        base: ShapeSpec,
        count: Int,
        centerHole: Double,
        orientation: Double
    )

    static let defaultShape: ShapeSpec = .preset(.square)

    static let defaultRadialRepeat = RadialRepeatParams(
        count: 8, centerHole: 0.0, orientation: 0.0
    )

    static let identityTransform = TransformParams(
        stretchX: 1.0, stretchY: 1.0, rotation: 0.0
    )

    static func preset(_ p: PolygonPreset) -> ShapeSpec {
        switch p.family {
        case .special:
            if p == .squircle { return .iosSquircle }
            if p == .drop {
                let d = DropParams.canonical
                return .drop(
                    pointiness: d.pointiness,
                    bulbSize: d.bulbSize,
                    tailOffset: d.tailOffset,
                    bend: d.bend,
                    tipRoundness: d.tipRoundness
                )
            }

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
        case .radialRepeat(let base, _, _, _):
            return base.displayName
        }
    }

    var unwrapped: ShapeSpec {
        if case .radialRepeat(let base, _, _, _) = self { return base }
        return self
    }

    var deepestBase: ShapeSpec {
        switch self {
        case .transform(let base, _, _, _): return base.deepestBase
        case .radialRepeat(let base, _, _, _): return base.deepestBase
        default: return self
        }
    }

    var radialRepeatParams: RadialRepeatParams? {
        if case let .radialRepeat(_, count, hole, orientation) = self {
            return RadialRepeatParams(
                count: count,
                centerHole: hole,
                orientation: orientation
            )
        }
        return nil
    }

    var transformParams: TransformParams? {
        switch self {
        case let .transform(_, sx, sy, rot):
            return TransformParams(stretchX: sx, stretchY: sy, rotation: rot)
        case .radialRepeat(let base, _, _, _):
            return base.transformParams
        default:
            return nil
        }
    }

    func wrappingInRadialRepeat(_ params: RadialRepeatParams) -> ShapeSpec {
        let base: ShapeSpec
        if case .radialRepeat(let b, _, _, _) = self {
            base = b
        } else {
            base = self
        }
        return .radialRepeat(
            base: base,
            count: params.count,
            centerHole: params.centerHole,
            orientation: params.orientation
        )
    }

    func applyingTransform(_ params: TransformParams) -> ShapeSpec {
        if case let .radialRepeat(base, count, hole, orientation) = self {
            return .radialRepeat(
                base: base.applyingTransform(params),
                count: count, centerHole: hole, orientation: orientation
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

    func replacingBase(with newBase: ShapeSpec) -> ShapeSpec {
        switch self {
        case let .radialRepeat(base, count, hole, orientation):
            return .radialRepeat(
                base: base.replacingBase(with: newBase),
                count: count, centerHole: hole, orientation: orientation
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

    var hasIntrinsicCornerRadius: Bool { true }

    var supportsTransform: Bool {
        switch deepestBase {
        case .polygon, .star, .ellipse, .drop: return true
        case .iosSquircle, .customPath: return false
        case .transform, .radialRepeat: return false
        }
    }

    var isOpenPath: Bool {
        switch self {
        case let .ellipse(_, _, arcSweep):
            return arcSweep < 1.0 - 1e-6
        case let .polygon(_, sides, _):
            return sides < 3
        case .transform(let base, _, _, _):
            return base.isOpenPath
        case .radialRepeat(let base, _, _, _):
            return base.isOpenPath
        default:
            return false
        }
    }
}

nonisolated struct RadialRepeatParams: Hashable, Sendable, Codable {
    var count: Int
    var centerHole: Double
    var orientation: Double
}

nonisolated struct TransformParams: Hashable, Sendable {
    var stretchX: Double
    var stretchY: Double
    var rotation: Double

    var isIdentity: Bool {
        let eps = 1e-6
        return abs(stretchX - 1) < eps
            && abs(stretchY - 1) < eps
            && abs(rotation) < eps
    }
}

// MARK: - PolygonPreset

nonisolated enum PolygonPreset: String, CaseIterable, Hashable, Sendable, Codable {
    case circle, squircle, roundedSquare, square
    case triangle, pentagon, hexagon, octagon
    case star4, star5, star6, star8
    case flower6, flower8
    case drop
    case free

    enum Family { case polygon, star, ellipse, special }

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

    var canonical: StarPolygonCanonical {
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
        case .star6:         return .init(sides: 6, bulge: -0.5,  roundness: 0,    rotationDegrees: 30)
        case .star8:         return .init(sides: 8, bulge: -0.45, roundness: 0,    rotationDegrees: 22.5)
        case .flower6:       return .init(sides: 6, bulge: -0.5,  roundness: 0.85, rotationDegrees: 30)
        case .flower8:       return .init(sides: 8, bulge: -0.45, roundness: 0.85, rotationDegrees: 22.5)

        case .drop:          return .init(sides: 4, bulge: 0,     roundness: 0,    rotationDegrees: 45)
        case .free:          return .init(sides: 4, bulge: 0,     roundness: 0,    rotationDegrees: 45)
        }
    }

    static let pickerOrder: [PolygonPreset] = [
        .square, .circle, .triangle, .star5, .flower6, .drop, .squircle
    ]

    func defaultPolygonRotation(forSides sides: Int) -> Double {
        guard family == .polygon, sides >= 2 else { return canonical.rotationDegrees }
        return sides.isMultiple(of: 2) ? 180.0 / Double(sides) : 0
    }
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

        case pointiness, bulbSize, tailOffset, bend, tipRoundness
    }
    private enum EllipseKeys: String, CodingKey {
        case roundness, arcStart, arcSweep
    }
    private enum RadialKeys: String, CodingKey {

        case base, count, centerHole, orientation
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
            let tipRoundness = try nested.decodeIfPresent(Double.self, forKey: .tipRoundness) ?? 0
            self = .drop(
                pointiness: pointiness, bulbSize: bulbSize,
                tailOffset: tailOffset, bend: bend,
                tipRoundness: tipRoundness
            )
            return
        }
        if container.contains(.ellipse) {
            let nested = try container.nestedContainer(keyedBy: EllipseKeys.self, forKey: .ellipse)
            let roundness = try nested.decode(Double.self, forKey: .roundness)

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
            let orientation = try nested.decodeIfPresent(Double.self, forKey: .orientation) ?? 0
            self = .radialRepeat(
                base: base,
                count: count,
                centerHole: centerHole,
                orientation: orientation
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
        case let .drop(pointiness, bulbSize, tailOffset, bend, tipRoundness):
            var nested = container.nestedContainer(keyedBy: DropKeys.self, forKey: .drop)
            try nested.encode(pointiness, forKey: .pointiness)
            try nested.encode(bulbSize, forKey: .bulbSize)
            try nested.encode(tailOffset, forKey: .tailOffset)
            try nested.encode(bend, forKey: .bend)
            try nested.encode(tipRoundness, forKey: .tipRoundness)
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
        case let .radialRepeat(base, count, centerHole, orientation):
            var nested = container.nestedContainer(keyedBy: RadialKeys.self, forKey: .radialRepeat)
            try nested.encode(base, forKey: .base)
            try nested.encode(count, forKey: .count)
            try nested.encode(centerHole, forKey: .centerHole)
            try nested.encode(orientation, forKey: .orientation)
        }
    }
}
