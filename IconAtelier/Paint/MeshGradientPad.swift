import SwiftUI
import UIKit

struct MeshGradientPad: View {
    @Binding var paint: Paint
    let onBeginEditing: () -> Void

    private static let coordinateSpace = "MeshGradientPad"

    private static let padSize: CGFloat = 140
    private static let handleSize: CGFloat = 26
    private static let dragMinimumDistance: CGFloat = 10

    private static let overshoot: Double = 0.25

    private static let midline: Double = 0.5

    private static func cornerRange(idx: Int) -> (x: ClosedRange<Double>, y: ClosedRange<Double>) {
        switch idx {
        case 0:
            return (-overshoot ... midline, -overshoot ... midline)
        case 1:
            return (midline ... 1 + overshoot, -overshoot ... midline)
        case 2:
            return (-overshoot ... midline, midline ... 1 + overshoot)
        case 3:
            return (midline ... 1 + overshoot, midline ... 1 + overshoot)
        default:
            return (0 ... 1, 0 ... 1)
        }
    }

    @State private var draggingCorner: Int? = nil

    private static let cornerColorIndices: [Int] = [0, 2, 6, 8]

    var body: some View {
        ZStack {
            padBackground
            handlesLayer
        }
        .frame(width: Self.padSize, height: Self.padSize)
        .frame(maxWidth: .infinity, alignment: .center)
    }

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
            supportsOpacity: true
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

    private func position(for point: StoredPoint) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) * Self.padSize,
            y: CGFloat(point.y) * Self.padSize
        )
    }

    private func cornerPoint(from location: CGPoint, idx: Int) -> StoredPoint {
        let range = Self.cornerRange(idx: idx)
        let rawX = Double(location.x / Self.padSize)
        let rawY = Double(location.y / Self.padSize)
        let x = min(max(rawX, range.x.lowerBound), range.x.upperBound)
        let y = min(max(rawY, range.y.lowerBound), range.y.upperBound)
        return StoredPoint(x: x, y: y)
    }
}
