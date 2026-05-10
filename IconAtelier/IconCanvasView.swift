import SwiftUI
import UIKit

struct IconCanvasView: View {
    enum SwipeDirection { case left, right }

    @Bindable var project: IconProject
    var onSwipe: (SwipeDirection) -> Void = { _ in }

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureAngle: Angle = .zero

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
                project.selectedLayerID = nil
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
            if project.background == nil {
                Color(.secondarySystemBackground)
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
                            transientOffset: isSelected ? dragOffset : .zero,
                            transientScale: isSelected ? gestureScale : 1.0,
                            transientAngle: isSelected ? gestureAngle : .zero,
                            onTap: { project.selectedLayerID = layer.id }
                        )
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(.rect(cornerRadius: side * 0.2237, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 18)
    }

    private func canvasGesture(side: CGFloat) -> some Gesture {
        let drag = DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                let nextWidth = layer.offset.width + value.translation.width / side
                let nextHeight = layer.offset.height + value.translation.height / side
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
                let next = layer.scale * value.magnification
                layer.scale = max(0.1, min(next, 4.0))
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
