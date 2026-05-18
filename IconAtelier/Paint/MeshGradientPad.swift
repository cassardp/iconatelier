import SwiftUI
import UIKit

/// Compact square editor for a 4-corner mesh gradient.
///
/// Same visual language as `LinearGradientPad` / `RadialGradientPad`:
/// a small gray pad whose only job is to convey *geometry* — the mesh
/// itself is already visible on the icon canvas above. Four handles
/// sit at the corners stored in `paint.meshCornerPoints` and can be
/// dragged freely, **including past the pad edges**. This matters
/// because SwiftUI's `MeshGradient` only covers the convex hull of its
/// points, so dragging a corner *inward* shrinks the mesh and leaves
/// uncovered area on the canvas; dragging *outward* expands the mesh
/// beyond the canvas with no cropping. Making the handles able to
/// float outside the pad is what makes outward warping a one-gesture
/// operation. A generous clamp keeps a runaway drag from sending a
/// handle into orbit.
///
/// Unlike the linear/radial pads, we deliberately don't draw any
/// connector between the 4 handles — they're autonomous in a mesh,
/// and outlining them as a quad makes them read as linked.
struct MeshGradientPad: View {
    @Binding var paint: Paint
    let onBeginEditing: () -> Void

    private static let coordinateSpace = "MeshGradientPad"
    /// Pad side, matching the linear/radial pads so the three editors
    /// read as siblings. The pad represents the canvas at 1:1 — a
    /// corner at unit `(0, 0)` sits at the pad's top-left.
    private static let padSize: CGFloat = 140
    private static let handleSize: CGFloat = 26
    private static let dragMinimumDistance: CGFloat = 10
    /// How far past the outer pad edge a handle is allowed to drift,
    /// in canvas-unit space. `0.25` lets the gradient soften noticeably
    /// while keeping each handle close enough to the fixed outer ring
    /// of the 5×5 mesh to avoid grid-pli artifacts.
    private static let overshoot: Double = 0.25
    /// The line that splits a handle from its neighbors. Each handle is
    /// clamped on its inner side at this midline so TL/TR/BL/BR can
    /// never cross one another — that's the *only* arrangement that
    /// twists the 5×5 mesh grid and produces visible folds.
    private static let midline: Double = 0.5

    /// Quadrant clamp for the corner at `idx` (TL/TR/BL/BR).
    /// - The outer side overshoots the pad by `overshoot`.
    /// - The inner side stops at `midline` so two handles can never
    ///   swap quadrants.
    private static func cornerRange(idx: Int) -> (x: ClosedRange<Double>, y: ClosedRange<Double>) {
        switch idx {
        case 0: // TL
            return (-overshoot ... midline, -overshoot ... midline)
        case 1: // TR
            return (midline ... 1 + overshoot, -overshoot ... midline)
        case 2: // BL
            return (-overshoot ... midline, midline ... 1 + overshoot)
        case 3: // BR
            return (midline ... 1 + overshoot, midline ... 1 + overshoot)
        default:
            return (0 ... 1, 0 ... 1)
        }
    }

    /// Index of the corner currently under a live drag — used to gate
    /// the single `onBeginEditing()` call per drag and the haptic.
    @State private var draggingCorner: Int? = nil

    /// 9-array indices of the 4 corner colors in `meshColors`.
    private static let cornerColorIndices: [Int] = [0, 2, 6, 8]

    var body: some View {
        ZStack {
            padBackground
            handlesLayer
        }
        .frame(width: Self.padSize, height: Self.padSize)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Sub-container that rotates with `meshRotationDegrees` so the pad
    /// visually mirrors the rotation applied to the live mesh on the
    /// canvas. The squircle background is kept *outside* this layer so
    /// only the handles spin.
    ///
    /// `.coordinateSpace` is intentionally placed *before*
    /// `.rotationEffect` in the modifier chain: drag locations are
    /// reported in the pre-rotation frame, which is exactly the frame in
    /// which `meshCornerPoints` are stored — no inverse-rotation math
    /// needed in the drag handler.
    private var handlesLayer: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { idx in
                cornerHandle(idx: idx)
            }
        }
        .frame(width: Self.padSize, height: Self.padSize)
        .coordinateSpace(name: Self.coordinateSpace)
        .rotationEffect(.degrees(paint.meshRotationDegrees))
    }

    // MARK: - Layers

    private var padBackground: some View {
        SquircleShape()
            .fill(PanelStyle.rowFill)
    }

    @ViewBuilder
    private func cornerHandle(idx: Int) -> some View {
        let corner = effectiveCorners[idx]
        let colorIdx = Self.cornerColorIndices[idx]
        ColorPicker(
            "",
            selection: Binding(
                get: { meshColor(at: colorIdx) },
                set: { newColor in
                    onBeginEditing()
                    setMeshColor(at: colorIdx, newColor)
                }
            ),
            supportsOpacity: false
        )
        .labelsHidden()
        .scaleEffect(Self.handleSize / 28)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .background(
            Circle()
                .stroke(Color.white, lineWidth: 2.5)
                .frame(width: Self.handleSize, height: Self.handleSize)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        )
        .position(position(for: corner))
        .simultaneousGesture(cornerDragGesture(idx: idx))
    }

    // MARK: - Gestures

    private func cornerDragGesture(idx: Int) -> some Gesture {
        DragGesture(
            minimumDistance: Self.dragMinimumDistance,
            coordinateSpace: .named(Self.coordinateSpace)
        )
        .onChanged { value in
            if draggingCorner != idx {
                draggingCorner = idx
                onBeginEditing()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            ensureCornerPoints()
            paint.meshCornerPoints[idx] = cornerPoint(from: value.location, idx: idx)
        }
        .onEnded { _ in draggingCorner = nil }
    }

    // MARK: - Model helpers

    /// Corner positions to render — uses the stored array when it has the
    /// right arity, otherwise the identity defaults (so handles appear
    /// at the canvas corners on first interaction).
    private var effectiveCorners: [StoredPoint] {
        paint.meshCornerPoints.count == 4
            ? paint.meshCornerPoints
            : Paint.defaultMeshCornerPoints
    }

    private func ensureCornerPoints() {
        if paint.meshCornerPoints.count != 4 {
            paint.meshCornerPoints = Paint.defaultMeshCornerPoints
        }
        if paint.meshColors.count != 9 {
            paint.meshColors = Paint.defaultMeshStoredColors
        }
    }

    private func meshColor(at index: Int) -> Color {
        guard paint.meshColors.indices.contains(index) else { return .clear }
        return paint.meshColors[index].color
    }

    /// Writes the new color to the targeted corner cell and re-interpolates
    /// the 5 non-corner cells so the visible mesh stays smooth — matches
    /// the convention used by the old corner color rows in `PaintEditor`.
    private func setMeshColor(at index: Int, _ newColor: Color) {
        ensureCornerPoints()
        paint.meshColors[index] = StoredColor(newColor)
        paint.meshColors = Color.mesh3x3(
            topLeft: paint.meshColors[0].color,
            topRight: paint.meshColors[2].color,
            bottomLeft: paint.meshColors[6].color,
            bottomRight: paint.meshColors[8].color
        ).map { StoredColor($0) }
    }

    // MARK: - Geometry

    /// Pad-space position for a canvas-relative corner point. `(0, 0)`
    /// lands at the pad's top-left (= canvas top-left). Returns
    /// positions outside the pad rect when the corner has been dragged
    /// past an edge — the handle floats in the panel space around the
    /// pad, which is the visual cue that the mesh is extending past
    /// the canvas.
    private func position(for point: StoredPoint) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) * Self.padSize,
            y: CGFloat(point.y) * Self.padSize
        )
    }

    /// Inverse of `position(for:)`. The corner is clamped into its
    /// own quadrant (see `cornerRange(idx:)`) so it can overshoot the
    /// pad outward but never cross into another corner's territory.
    private func cornerPoint(from location: CGPoint, idx: Int) -> StoredPoint {
        let range = Self.cornerRange(idx: idx)
        let rawX = Double(location.x / Self.padSize)
        let rawY = Double(location.y / Self.padSize)
        let x = min(max(rawX, range.x.lowerBound), range.x.upperBound)
        let y = min(max(rawY, range.y.lowerBound), range.y.upperBound)
        return StoredPoint(x: x, y: y)
    }
}
