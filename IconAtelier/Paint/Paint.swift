import SwiftUI

enum PaintKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case solid
    case meshGradient
    case linearGradient
    case radialGradient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solid:          return "Solid"
        case .linearGradient: return "Linear"
        case .radialGradient: return "Radial"
        case .meshGradient:   return "Mesh"
        }
    }
}

nonisolated struct Paint: Codable, Hashable, Sendable {
    var kind: PaintKind
    var solidColor: StoredColor
    var gradientColors: [StoredColor]
    var linearStart: StoredPoint
    var linearEnd: StoredPoint
    var gradientCenter: StoredPoint
    var radialSpread: Double
    var meshColors: [StoredColor]

    var meshCornerPoints: [StoredPoint]
    var meshRotationDegrees: Double

    static let canvasDefault = Paint(
        kind: .solid,
        solidColor: StoredColor(r: 0.92, g: 0.92, b: 0.94, a: 1.0),
        gradientColors: [],
        linearStart: StoredPoint(x: 0, y: 0),
        linearEnd: StoredPoint(x: 1, y: 1),
        gradientCenter: StoredPoint(x: 0.5, y: 0.5),
        radialSpread: 0.75,
        meshColors: [],
        meshCornerPoints: [],
        meshRotationDegrees: 0
    )

    static func solid(_ color: Color) -> Paint {
        Paint(
            kind: .solid,
            solidColor: StoredColor(color),
            gradientColors: [StoredColor(.iaBlue), StoredColor(.iaPurple)],
            linearStart: StoredPoint(x: 0, y: 0),
            linearEnd: StoredPoint(x: 1, y: 1),
            gradientCenter: StoredPoint(x: 0.5, y: 0.5),
            radialSpread: 0.75,
            meshColors: Paint.defaultMeshStoredColors,
            meshCornerPoints: Paint.defaultMeshCornerPoints,
            meshRotationDegrees: 0
        )
    }

    private enum CodingKeys: String, CodingKey {
        case kind, solidColor, gradientColors
        case linearStart, linearEnd, gradientCenter
        case radialSpread, meshColors, meshCornerPoints, meshRotationDegrees
    }

    init(
        kind: PaintKind,
        solidColor: StoredColor,
        gradientColors: [StoredColor],
        linearStart: StoredPoint,
        linearEnd: StoredPoint,
        gradientCenter: StoredPoint,
        radialSpread: Double,
        meshColors: [StoredColor],
        meshCornerPoints: [StoredPoint],
        meshRotationDegrees: Double
    ) {
        self.kind = kind
        self.solidColor = solidColor
        self.gradientColors = gradientColors
        self.linearStart = linearStart
        self.linearEnd = linearEnd
        self.gradientCenter = gradientCenter
        self.radialSpread = radialSpread
        self.meshColors = meshColors
        self.meshCornerPoints = meshCornerPoints
        self.meshRotationDegrees = meshRotationDegrees
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(PaintKind.self, forKey: .kind)
        solidColor = try c.decode(StoredColor.self, forKey: .solidColor)
        gradientColors = try c.decode([StoredColor].self, forKey: .gradientColors)
        linearStart = try c.decode(StoredPoint.self, forKey: .linearStart)
        linearEnd = try c.decode(StoredPoint.self, forKey: .linearEnd)
        gradientCenter = try c.decode(StoredPoint.self, forKey: .gradientCenter)
        radialSpread = try c.decode(Double.self, forKey: .radialSpread)
        meshColors = try c.decode([StoredColor].self, forKey: .meshColors)
        meshCornerPoints = try c.decodeIfPresent([StoredPoint].self, forKey: .meshCornerPoints) ?? []
        meshRotationDegrees = try c.decode(Double.self, forKey: .meshRotationDegrees)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encode(solidColor, forKey: .solidColor)
        try c.encode(gradientColors, forKey: .gradientColors)
        try c.encode(linearStart, forKey: .linearStart)
        try c.encode(linearEnd, forKey: .linearEnd)
        try c.encode(gradientCenter, forKey: .gradientCenter)
        try c.encode(radialSpread, forKey: .radialSpread)
        try c.encode(meshColors, forKey: .meshColors)
        try c.encode(meshCornerPoints, forKey: .meshCornerPoints)
        try c.encode(meshRotationDegrees, forKey: .meshRotationDegrees)
    }

    nonisolated static var defaultMeshStoredColors: [StoredColor] {
        Color.mesh3x3(
            topLeft: .iaPurple,
            topRight: .iaBlue,
            bottomLeft: .iaPink,
            bottomRight: .iaOrange
        ).map { StoredColor($0) }
    }

    nonisolated static let defaultMeshCornerPoints: [StoredPoint] = [
        StoredPoint(x: 0, y: 0),
        StoredPoint(x: 1, y: 0),
        StoredPoint(x: 0, y: 1),
        StoredPoint(x: 1, y: 1),
    ]

    nonisolated static func mesh9Points(corners: [StoredPoint]) -> [SIMD2<Float>] {
        let c = corners.count == 4 ? corners : defaultMeshCornerPoints
        let tl = c[0], tr = c[1], bl = c[2], br = c[3]
        func pt(_ p: StoredPoint) -> SIMD2<Float> {
            SIMD2(Float(p.x), Float(p.y))
        }
        func mid(_ a: StoredPoint, _ b: StoredPoint) -> SIMD2<Float> {
            SIMD2(Float((a.x + b.x) / 2), Float((a.y + b.y) / 2))
        }
        let center = SIMD2<Float>(
            Float((tl.x + tr.x + bl.x + br.x) / 4),
            Float((tl.y + tr.y + bl.y + br.y) / 4)
        )
        return [
            pt(tl),       mid(tl, tr),  pt(tr),
            mid(tl, bl),  center,       mid(tr, br),
            pt(bl),       mid(bl, br),  pt(br),
        ]
    }

    nonisolated static func mesh25Points(corners: [StoredPoint]) -> [SIMD2<Float>] {
        let c = corners.count == 4 ? corners : defaultMeshCornerPoints
        let tl = c[0], tr = c[1], bl = c[2], br = c[3]
        func pt(_ p: StoredPoint) -> SIMD2<Float> {
            SIMD2(Float(p.x), Float(p.y))
        }
        func mid(_ a: StoredPoint, _ b: StoredPoint) -> SIMD2<Float> {
            SIMD2(Float((a.x + b.x) / 2), Float((a.y + b.y) / 2))
        }
        let topMid = mid(tl, tr)
        let leftMid = mid(tl, bl)
        let rightMid = mid(tr, br)
        let bottomMid = mid(bl, br)
        let center = SIMD2<Float>(
            Float((tl.x + tr.x + bl.x + br.x) / 4),
            Float((tl.y + tr.y + bl.y + br.y) / 4)
        )
        return [
            SIMD2(0.0,  0.0),  SIMD2(0.25, 0.0),  SIMD2(0.5,  0.0),  SIMD2(0.75, 0.0),  SIMD2(1.0,  0.0),
            SIMD2(0.0,  0.25), pt(tl),            topMid,            pt(tr),            SIMD2(1.0,  0.25),
            SIMD2(0.0,  0.5),  leftMid,           center,            rightMid,          SIMD2(1.0,  0.5),
            SIMD2(0.0,  0.75), pt(bl),            bottomMid,         pt(br),            SIMD2(1.0,  0.75),
            SIMD2(0.0,  1.0),  SIMD2(0.25, 1.0),  SIMD2(0.5,  1.0),  SIMD2(0.75, 1.0),  SIMD2(1.0,  1.0),
        ]
    }

    nonisolated static func mesh25Colors(from colors9: [Color]) -> [Color] {
        guard colors9.count == 9 else {
            return mesh25Colors(from: Paint.defaultMeshStoredColors.map { $0.color })
        }
        let tl = colors9[0], top = colors9[1], tr = colors9[2]
        let left = colors9[3], center = colors9[4], right = colors9[5]
        let bl = colors9[6], bot = colors9[7], br = colors9[8]
        return [
            tl,  tl,  top,    tr,  tr,
            tl,  tl,  top,    tr,  tr,
            left, left, center, right, right,
            bl,  bl,  bot,    br,  br,
            bl,  bl,  bot,    br,  br,
        ]
    }
}
