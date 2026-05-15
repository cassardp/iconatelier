import SwiftUI

nonisolated enum ShapeSpec: Codable, Hashable, Equatable, Sendable {
    case polygon(sides: Int, rotation: Double)
    case star(points: Int, innerRatio: Double, rotation: Double)
    case squircle(cornerRadiusFraction: Double)

    static let defaultPolygon: ShapeSpec = .polygon(sides: 6, rotation: -90)
    static let defaultStar: ShapeSpec = .star(points: 5, innerRatio: 0.5, rotation: -90)
    static let defaultSquircle: ShapeSpec = .squircle(cornerRadiusFraction: 0.2237)

    var displayName: String {
        switch self {
        case .polygon:  return "Polygon"
        case .star:     return "Star"
        case .squircle: return "Squircle"
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
        }
    }
}
