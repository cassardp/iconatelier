import SwiftUI
import UIKit

struct IconCanvasView: View {
    let project: IconProject
    var onTapLayer: (Layer) -> Void = { _ in }

    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .overlay {
                GeometryReader { geo in
                    let canvasSide = min(geo.size.width, geo.size.height) * 0.78
                    ZStack {
                        halo(side: canvasSide)
                        squircleIcon(side: canvasSide)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
    }

    private func halo(side: CGFloat) -> some View {
        RadialGradient(
            colors: [Color.accentColor.opacity(0.18), .clear],
            center: .center,
            startRadius: 0,
            endRadius: side * 0.65
        )
        .frame(width: side * 1.5, height: side * 1.5)
        .blur(radius: 28)
        .allowsHitTesting(false)
    }

    private func squircleIcon(side: CGFloat) -> some View {
        ZStack {
            if project.layers.isEmpty {
                Color(.secondarySystemBackground)
            }
            ForEach(project.layers) { layer in
                if !layer.isHidden, let image = layer.image {
                    if layer.fillsCanvas {
                        BackgroundLayerView(
                            layer: layer,
                            image: image,
                            side: side,
                            onTap: { onTapLayer(layer) }
                        )
                    } else {
                        OverlayLayerView(
                            layer: layer,
                            image: image,
                            side: side,
                            isSelected: layer.id == project.selectedLayerID,
                            onTap: { onTapLayer(layer) }
                        )
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(.rect(cornerRadius: side * 0.2237, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 14)
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
    let onTap: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var gestureAngle: Angle = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: side * 0.7, height: side * 0.7)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .padding(-4)
                }
            }
            .scaleEffect(layer.scale * gestureScale)
            .rotationEffect(layer.rotation + gestureAngle)
            .opacity(layer.opacity)
            .offset(
                x: layer.offset.width * side + dragOffset.width,
                y: layer.offset.height * side + dragOffset.height
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .gesture(combinedGesture, including: isSelected ? .all : .subviews)
    }

    private var combinedGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                layer.offset.width += value.translation.width / side
                layer.offset.height += value.translation.height / side
            }
            .simultaneously(
                with: MagnifyGesture(minimumScaleDelta: 0.01)
                    .updating($gestureScale) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        let next = layer.scale * value.magnification
                        layer.scale = max(0.1, min(next, 4.0))
                    }
            )
            .simultaneously(
                with: RotateGesture(minimumAngleDelta: .degrees(1))
                    .updating($gestureAngle) { value, state, _ in
                        state = value.rotation
                    }
                    .onEnded { value in
                        layer.rotation += value.rotation
                    }
            )
    }
}
