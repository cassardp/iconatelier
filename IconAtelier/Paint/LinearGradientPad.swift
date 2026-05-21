import SwiftUI
import UIKit

struct LinearGradientPad: View {
    @Binding var paint: Paint
    let onBeginEditing: () -> Void

    private static let coordinateSpace = "LinearGradientPad"
    private static let padSize: CGFloat = 140
    private static let handleSize: CGFloat = 26
    private static let dragMinimumDistance: CGFloat = 10

    private static let pointRange: ClosedRange<Double> = -0.25 ... 1.25

    var body: some View {
        let size = Self.padSize
        ZStack {
            padBackground
            connectingLine(size: size)
            handle(
                color: colorBinding(at: 0),
                point: startPointBinding,
                size: size
            )
            handle(
                color: colorBinding(at: max(paint.gradientColors.count - 1, 0)),
                point: endPointBinding,
                size: size
            )
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

    private func connectingLine(size: CGFloat) -> some View {
        let start = position(for: paint.linearStart.unitPoint, size: size)
        let end = position(for: paint.linearEnd.unitPoint, size: size)
        return Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
        .stroke(
            Color.primary.opacity(0.35),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3])
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func handle(
        color: Binding<Color>,
        point: Binding<StoredPoint>,
        size: CGFloat
    ) -> some View {
        let center = position(for: point.wrappedValue.unitPoint, size: size)

        ColorPicker(
            "",
            selection: Binding(
                get: { color.wrappedValue },
                set: { newColor in
                    onBeginEditing()
                    color.wrappedValue = newColor
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
        .position(center)
        .simultaneousGesture(dragGesture(for: point, size: size))
    }

    private func dragGesture(
        for point: Binding<StoredPoint>,
        size: CGFloat
    ) -> some Gesture {
        DragGesture(
            minimumDistance: Self.dragMinimumDistance,
            coordinateSpace: .named(Self.coordinateSpace)
        )
        .onChanged { value in
            guard size > 0 else { return }
            if !isDragging {
                isDragging = true
                onBeginEditing()
                UISelectionFeedbackGenerator().selectionChanged()
            }
            let nx = clamp(Double(value.location.x / size), Self.pointRange.lowerBound, Self.pointRange.upperBound)
            let ny = clamp(Double(value.location.y / size), Self.pointRange.lowerBound, Self.pointRange.upperBound)
            point.wrappedValue = StoredPoint(x: nx, y: ny)
        }
        .onEnded { _ in
            isDragging = false
        }
    }

    // MARK: - State (single drag-in-flight flag, shared by both handles

    @State private var isDragging = false

    // MARK: - Bindings

    private var startPointBinding: Binding<StoredPoint> {
        Binding(
            get: { paint.linearStart },
            set: { paint.linearStart = $0 }
        )
    }

    private var endPointBinding: Binding<StoredPoint> {
        Binding(
            get: { paint.linearEnd },
            set: { paint.linearEnd = $0 }
        )
    }

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

    private func position(for unit: UnitPoint, size: CGFloat) -> CGPoint {
        CGPoint(x: unit.x * size, y: unit.y * size)
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
