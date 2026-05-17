import SwiftUI

/// Renders a `Paint` value as a fill over the given shape. Used by
/// `LayerContentView` for shape and text fills so a layer can take any
/// background-style paint (solid, linear, radial, mesh).
///
/// `side` is the drawing rect's side length — used by `radialGradient`
/// to convert the unit `radialSpread` into a pixel radius, and to size
/// the masked mesh layer so its scale/rotation match the canvas mesh
/// rendering convention.
///
/// Mesh fills go through a view-level `mask(shape)` instead of
/// `shape.fill(mesh)` so `meshRotationDegrees` works the same way as in
/// `BackgroundView` — `MeshGradient` is a `ShapeStyle` but a fill style
/// can't be rotated independently from the shape it fills, so we render
/// the rotated mesh in a sized frame and clip it through the shape.
@ViewBuilder
func PaintFill<S: Shape>(_ shape: S, paint: Paint, side: CGFloat) -> some View {
    switch paint.kind {
    case .solid:
        shape.fill(paint.solidColor.color)
    case .linearGradient:
        shape.fill(
            LinearGradient(
                colors: paint.gradientColors.map { $0.color },
                startPoint: paint.linearStart.unitPoint,
                endPoint: paint.linearEnd.unitPoint
            )
        )
    case .radialGradient:
        shape.fill(
            RadialGradient(
                colors: paint.gradientColors.map { $0.color },
                center: paint.gradientCenter.unitPoint,
                startRadius: 0,
                endRadius: side * CGFloat(paint.radialSpread)
            )
        )
    case .meshGradient:
        let colors = paint.meshColors.map { $0.color }
        let safeColors = colors.count == 9
            ? colors
            : Paint.defaultMeshStoredColors.map { $0.color }
        // Same scale-then-rotate trick as BackgroundView: scaling by
        // |cos|+|sin| ensures the rotated mesh still covers the full
        // side×side frame at any angle without exposing transparent
        // corners.
        let angle = paint.meshRotationDegrees
        let rad = angle * .pi / 180
        let cover = abs(cos(rad)) + abs(sin(rad))
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0,   0  ], [0.5, 0  ], [1,   0  ],
                [0,   0.5], [0.5, 0.5], [1,   0.5],
                [0,   1  ], [0.5, 1  ], [1,   1  ]
            ],
            colors: safeColors
        )
        .scaleEffect(cover)
        .rotationEffect(.degrees(angle))
        .frame(width: side, height: side)
        .mask { shape }
    }
}
