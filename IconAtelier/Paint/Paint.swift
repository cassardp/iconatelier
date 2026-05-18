import SwiftUI

/// Kind discriminator for `Paint`. Identical raw values to the legacy
/// `BackgroundKind` (kept as a typealias in `Background.swift` for source
/// compatibility).
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

/// Shared paint description used by both `Background` (whole-canvas fill)
/// and shape/text layer `fillPaint`. Stored as JSON on `Layer` and as
/// flat columns on `Background` — `Paint` is the in-memory shape the
/// `PaintEditor` and the renderer both operate on.
///
/// All fields are kept regardless of `kind` so switching between kinds
/// (solid → linear → mesh → …) preserves whatever the user already
/// configured — same convention as `Background`.
nonisolated struct Paint: Codable, Hashable, Sendable {
    var kind: PaintKind
    var solidColor: StoredColor
    var gradientColors: [StoredColor]
    var linearStart: StoredPoint
    var linearEnd: StoredPoint
    var gradientCenter: StoredPoint
    var radialSpread: Double
    var meshColors: [StoredColor]
    /// Positions of the 4 mesh corners in canvas-unit space, in TL/TR/BL/BR
    /// order. Empty when the field is missing on disk — the renderer and
    /// editor fall back to `defaultMeshCornerPoints` (identity grid).
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

    // Decode without the new field for projects saved before the
    // draggable-mesh feature: meshCornerPoints defaults to [] and the
    // renderer/editor fall back to `defaultMeshCornerPoints`.
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
        StoredPoint(x: 0, y: 0),  // top-left
        StoredPoint(x: 1, y: 0),  // top-right
        StoredPoint(x: 0, y: 1),  // bottom-left
        StoredPoint(x: 1, y: 1),  // bottom-right
    ]

    /// Builds the 9 SwiftUI `MeshGradient` points (row-major 3×3) from the
    /// 4 stored corners. Mid-row, mid-column, and center cells are linearly
    /// interpolated. Falls back to the identity grid when `corners` has the
    /// wrong arity (legacy projects, accidental clears).
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

    /// Builds a 5×5 `MeshGradient` points grid where the 4 user-controlled
    /// corners sit at the *inner* positions [6, 8, 16, 18] (row-major),
    /// surrounded by an outer ring pinned to the unit-frame edges. This is
    /// what lets the gradient *always cover the full canvas* even when a
    /// corner handle is dragged inward — the outer ring carries the corner
    /// color out to the frame edge, eliminating the convex-hull holes that
    /// the bare 3×3 grid produces.
    ///
    /// Inner positions (handles, mid-edges, center) are computed exactly
    /// like `mesh9Points`. Outer ring positions are fixed at quarters of
    /// the unit frame.
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

    /// Expands the 9 stored mesh colors (3×3) into the 25 colors needed by
    /// `mesh25Points`. The outer ring cells repeat the nearest corner /
    /// mid-edge color so the gradient color *extends* from the user corner
    /// out to the frame edge instead of fading to transparent.
    ///
    /// Stored 3×3 indices: 0=TL, 1=top-mid, 2=TR, 3=mid-left, 4=center,
    /// 5=mid-right, 6=BL, 7=bottom-mid, 8=BR.
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
