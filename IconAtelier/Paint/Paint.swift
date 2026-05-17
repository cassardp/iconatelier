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
            meshRotationDegrees: 0
        )
    }

    nonisolated static var defaultMeshStoredColors: [StoredColor] {
        Color.mesh3x3(
            topLeft: .iaPurple,
            topRight: .iaBlue,
            bottomLeft: .iaPink,
            bottomRight: .iaOrange
        ).map { StoredColor($0) }
    }
}
