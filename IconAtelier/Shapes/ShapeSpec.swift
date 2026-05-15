import SwiftUI

nonisolated indirect enum ShapeSpec: Codable, Hashable, Equatable, Sendable {
    case polygon(sides: Int, rotation: Double)
    case star(points: Int, innerRatio: Double, rotation: Double)
    case squircle(cornerRadiusFraction: Double)
    case petal(length: Double, width: Double, pointiness: Double, curvature: Double)
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
    static let defaultPetal: ShapeSpec = .petal(length: 0.9, width: 0.45, pointiness: 0.5, curvature: 0.4)
    static let defaultFlower: ShapeSpec = .radialRepeat(
        base: .defaultPetal,
        count: 6,
        centerHole: 0.1,
        phaseDegrees: -90,
        alternateScale: 1.0
    )

    var displayName: String {
        switch self {
        case .polygon:       return "Polygon"
        case .star:          return "Star"
        case .squircle:      return "Squircle"
        case .petal:         return "Petal"
        case .radialRepeat:  return "Radial Repeat"
        }
    }

    func anyShape() -> AnyShape {
        switch self {
        case let .polygon(sides, rotation):
            return AnyShape(Polygon(sides: sides, rotationDegrees: rotation))
        case let .star(points, innerRatio, rotation):
            return AnyShape(Star(points: points, innerRatio: innerRatio, rotationDegrees: rotation))
        case let .squircle(crf):
            return AnyShape(Squircle(cornerRadiusFraction: crf))
        case let .petal(length, width, pointiness, curvature):
            return AnyShape(Petal(
                length: length,
                width: width,
                pointiness: pointiness,
                curvature: curvature
            ))
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
