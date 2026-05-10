import SwiftUI
import UIKit

struct IconCanvasView: View {
    enum SwipeDirection { case left, right }

    @Bindable var project: IconProject
    var onSwipe: (SwipeDirection) -> Void = { _ in }

    @GestureState private var dragSnap: DragSnapState = DragSnapState()
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureAngle: Angle = .zero

    private struct SnapAxes: OptionSet, Equatable {
        let rawValue: Int
        static let horizontal = SnapAxes(rawValue: 1 << 0)
        static let vertical = SnapAxes(rawValue: 1 << 1)
    }

    private struct DragSnapState: Equatable {
        var translation: CGSize = .zero
        var axes: SnapAxes = []
        var isActive: Bool = false
    }

    private static let snapThreshold: CGFloat = 8

    private static func snapped(
        translation: CGSize,
        layerOffset: CGSize,
        side: CGFloat
    ) -> (effective: CGSize, axes: SnapAxes) {
        let baseX = layerOffset.width * side
        let baseY = layerOffset.height * side
        let absX = baseX + translation.width
        let absY = baseY + translation.height
        var axes: SnapAxes = []
        var effective = translation
        if abs(absX) < snapThreshold {
            axes.insert(.horizontal)
            effective.width = -baseX
        }
        if abs(absY) < snapThreshold {
            axes.insert(.vertical)
            effective.height = -baseY
        }
        return (effective, axes)
    }

    var body: some View {
        GeometryReader { geo in
            let canvasSide = min(geo.size.width, geo.size.height)
            ZStack {
                squircleIcon(side: canvasSide)
                    .contentShape(Rectangle())
                    .gesture(canvasGesture(side: canvasSide))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(swipeGesture)
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                guard abs(h) > abs(v), abs(h) > 60 else { return }
                onSwipe(h > 0 ? .right : .left)
            }
    }

    private var selectedOverlay: Layer? {
        guard let layer = project.selectedLayer, !layer.fillsCanvas else { return nil }
        return layer
    }

    private func squircleIcon(side: CGFloat) -> some View {
        ZStack {
            if project.background?.isHidden ?? true {
                TransparencyCheckerboard(tile: 14)
            }
            ForEach(project.layers) { layer in
                if !layer.isHidden, let image = layer.image {
                    if layer.fillsCanvas {
                        BackgroundLayerView(
                            layer: layer,
                            image: image,
                            side: side,
                            onTap: { project.selectedLayerID = layer.id }
                        )
                    } else {
                        let isSelected = layer.id == project.selectedLayerID
                        OverlayLayerView(
                            layer: layer,
                            image: image,
                            side: side,
                            isSelected: isSelected,
                            transientOffset: isSelected ? dragSnap.translation : .zero,
                            transientScale: isSelected ? gestureScale : 1.0,
                            transientAngle: isSelected ? gestureAngle : .zero,
                            onTap: { project.selectedLayerID = layer.id }
                        )
                    }
                }
            }
            centerGuides(side: side)
        }
        .frame(width: side, height: side)
        .clipShape(.rect(cornerRadius: side * 0.2237, style: .continuous))
    }

    @ViewBuilder
    private func centerGuides(side: CGFloat) -> some View {
        let showVertical = dragSnap.isActive && dragSnap.axes.contains(.horizontal)
        let showHorizontal = dragSnap.isActive && dragSnap.axes.contains(.vertical)
        ZStack {
            if showVertical {
                Rectangle()
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.0))
                    .frame(width: 1, height: side)
                    .transition(.opacity)
            }
            if showHorizontal {
                Rectangle()
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.0))
                    .frame(width: side, height: 1)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: dragSnap)
    }

    private func canvasGesture(side: CGFloat) -> some Gesture {
        let drag = DragGesture()
            .updating($dragSnap) { value, state, _ in
                guard let layer = selectedOverlay else { return }
                let (effective, nextAxes) = Self.snapped(
                    translation: value.translation,
                    layerOffset: layer.offset,
                    side: side
                )
                let entered = nextAxes.subtracting(state.axes)
                if !entered.isEmpty {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                state.translation = effective
                state.axes = nextAxes
                state.isActive = true
            }
            .onEnded { value in
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                let (effective, _) = Self.snapped(
                    translation: value.translation,
                    layerOffset: layer.offset,
                    side: side
                )
                let nextWidth = layer.offset.width + effective.width / side
                let nextHeight = layer.offset.height + effective.height / side
                layer.offset.width = min(max(nextWidth, -0.5), 0.5)
                layer.offset.height = min(max(nextHeight, -0.5), 0.5)
            }

        let magnify = MagnifyGesture(minimumScaleDelta: 0.01)
            .updating($gestureScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                layer.scale = max(0.1, layer.scale * value.magnification)
            }

        let rotate = RotateGesture(minimumAngleDelta: .degrees(1))
            .updating($gestureAngle) { value, state, _ in
                state = value.rotation
            }
            .onEnded { value in
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                layer.rotation += value.rotation
            }

        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
    }
}

private struct BackgroundLayerView: View {
    let layer: Layer
    let image: UIImage
    let side: CGFloat
    let onTap: () -> Void

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: side, height: side)
            .opacity(layer.opacity)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}

private struct OverlayLayerView: View {
    let layer: Layer
    let image: UIImage
    let side: CGFloat
    let isSelected: Bool
    let transientOffset: CGSize
    let transientScale: CGFloat
    let transientAngle: Angle
    let onTap: () -> Void

    var body: some View {
        let displaySide = side * 0.7
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: displaySide, height: displaySide)
        .scaleEffect(layer.scale * transientScale)
        .rotationEffect(layer.rotation + transientAngle)
        .opacity(layer.opacity)
        .offset(
            x: layer.offset.width * side + transientOffset.width,
            y: layer.offset.height * side + transientOffset.height
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

struct TransparencyCheckerboard: View {
    let tile: CGFloat
    var light: Color = Color(white: 0.92)
    var dark: Color = Color(white: 0.78)

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(light))
            let cols = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            var path = Path()
            for row in 0..<rows {
                for col in 0..<cols where (row + col).isMultiple(of: 2) {
                    path.addRect(CGRect(
                        x: CGFloat(col) * tile,
                        y: CGFloat(row) * tile,
                        width: tile,
                        height: tile
                    ))
                }
            }
            context.fill(path, with: .color(dark))
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}
