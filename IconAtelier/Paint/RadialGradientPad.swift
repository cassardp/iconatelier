import SwiftUI
import UIKit

struct RadialGradientPad: View {
    @Binding var paint: Paint
    let onBeginEditing: () -> Void

    private static let coordinateSpace = "RadialGradientPad"
    private static let padSize: CGFloat = 140
    private static let handleSize: CGFloat = 26
    private static let dragMinimumDistance: CGFloat = 10

    @State private var edgeAngle: Double = 0

    @State private var isDraggingCenter = false
    @State private var isDraggingEdge = false

    var body: some View {
        let size = Self.padSize
        ZStack {
            padBackground
            spreadCircle(size: size)
            centerHandle(size: size)
            edgeHandle(size: size)
        }
        .frame(width: size, height: size)
        .coordinateSpace(name: Self.coordinateSpace)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Layers

    private var padBackground: some View {
        SquircleShape()
            .fill(PanelStyle.rowFill)
    }

    private func spreadCircle(size: CGFloat) -> some View {
        let radius = CGFloat(paint.radialSpread) * size
        return Circle()
            .stroke(
                Color.primary.opacity(0.35),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3])
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(centerPoint(size: size))
            .clipShape(SquircleShape())
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func centerHandle(size: CGFloat) -> some View {
        handle(
            color: colorBinding(at: 0),
            at: centerPoint(size: size),
            dragGesture: centerDragGesture(size: size)
        )
    }

    @ViewBuilder
    private func edgeHandle(size: CGFloat) -> some View {
        handle(
            color: colorBinding(at: max(paint.gradientColors.count - 1, 0)),
            at: edgePoint(size: size),
            dragGesture: edgeDragGesture(size: size)
        )
    }

    private func handle(
        color: Binding<Color>,
        at center: CGPoint,
        dragGesture: some Gesture
    ) -> some View {
        ColorPicker(
            "",
            selection: Binding(
                get: { color.wrappedValue },
                set: { newColor in
                    onBeginEditing()
                    color.wrappedValue = newColor
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
        .position(center)
        .simultaneousGesture(dragGesture)
    }

    // MARK: - Gestures

    private func centerDragGesture(size: CGFloat) -> some Gesture {
        DragGesture(
            minimumDistance: Self.dragMinimumDistance,
            coordinateSpace: .named(Self.coordinateSpace)
        )
        .onChanged { value in
            guard size > 0 else { return }
            if !isDraggingCenter {
                isDraggingCenter = true
                onBeginEditing()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            let nx = clamp(Double(value.location.x / size), 0, 1)
            let ny = clamp(Double(value.location.y / size), 0, 1)
            paint.gradientCenter = StoredPoint(x: nx, y: ny)
        }
        .onEnded { _ in isDraggingCenter = false }
    }

    private func edgeDragGesture(size: CGFloat) -> some Gesture {
        DragGesture(
            minimumDistance: Self.dragMinimumDistance,
            coordinateSpace: .named(Self.coordinateSpace)
        )
        .onChanged { value in
            guard size > 0 else { return }
            if !isDraggingEdge {
                isDraggingEdge = true
                onBeginEditing()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            let center = centerPoint(size: size)
            let dx = Double(value.location.x - center.x)
            let dy = Double(value.location.y - center.y)
            let distance = (dx * dx + dy * dy).squareRoot()
            edgeAngle = atan2(dy, dx)

            paint.radialSpread = clamp(distance / Double(size), 0.2, 1.5)
        }
        .onEnded { _ in isDraggingEdge = false }
    }

    // MARK: - Bindings

    private func colorBinding(at index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard paint.gradientColors.indices.contains(index) else { return .clear }
                return paint.gradientColors[index].color
            },
            set: { newColor in
                guard paint.gradientColors.indices.contains(index) else { return }
                paint.gradientColors[index] = StoredColor(newColor)
            }
        )
    }

    // MARK: - Geometry

    private func centerPoint(size: CGFloat) -> CGPoint {
        let unit = paint.gradientCenter.unitPoint
        return CGPoint(x: unit.x * size, y: unit.y * size)
    }

    private func edgePoint(size: CGFloat) -> CGPoint {
        let center = centerPoint(size: size)
        let radius = CGFloat(paint.radialSpread) * size
        return CGPoint(
            x: center.x + radius * CGFloat(cos(edgeAngle)),
            y: center.y + radius * CGFloat(sin(edgeAngle))
        )
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
