import SwiftUI
import UIKit

struct IconCanvasView: View {
    enum SwipeDirection { case left, right }

    @Bindable var project: IconProject
    let session: ProjectSession
    var onSwipe: (SwipeDirection) -> Void = { _ in }

    @GestureState private var dragSnap: DragSnapState = DragSnapState()
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var rotationSnap: RotationSnapState = RotationSnapState()

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

    private struct RotationSnapState: Equatable {
        var delta: Angle = .zero
        var isSnapped: Bool = false
    }

    private static let snapThreshold: CGFloat = 8
    private static let rotationSnapThreshold: Double = 5

    private static func snappedRotation(
        layerRotation: Angle,
        rawDelta: Angle
    ) -> (delta: Angle, isSnapped: Bool) {
        let total = (layerRotation + rawDelta).degrees
        let nearest = (total / 90).rounded() * 90
        if abs(total - nearest) < rotationSnapThreshold {
            return (.degrees(nearest) - layerRotation, true)
        }
        return (rawDelta, false)
    }

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
        project.layer(withID: session.selectedLayerUUID)
    }

    private func squircleIcon(side: CGFloat) -> some View {
        ZStack {
            if project.safeBackground.isHidden {
                TransparencyCheckerboard(tile: 14)
            } else {
                BackgroundView(background: project.safeBackground, side: side)
            }
            ForEach(project.layers) { layer in
                if !layer.isHidden {
                    let isSelected = layer.uuid == session.selectedLayerUUID
                    OverlayLayerView(
                        layer: layer,
                        side: side,
                        isSelected: isSelected,
                        transientOffset: isSelected ? dragSnap.translation : .zero,
                        transientScale: isSelected ? gestureScale : 1.0,
                        transientAngle: isSelected ? rotationSnap.delta : .zero,
                        onTap: { session.selectLayer(layer.uuid) }
                    )
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
            .onChanged { _ in promoteOverlaySelection() }
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
                layer.offset = CGSize(
                    width: min(max(nextWidth, -0.5), 0.5),
                    height: min(max(nextHeight, -0.5), 0.5)
                )
            }

        let magnify = MagnifyGesture(minimumScaleDelta: 0.01)
            .updating($gestureScale) { value, state, _ in
                state = value.magnification
            }
            .onChanged { _ in promoteOverlaySelection() }
            .onEnded { value in
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                layer.scale = max(0.1, layer.scale * value.magnification)
            }

        let rotate = RotateGesture(minimumAngleDelta: .degrees(1))
            .updating($rotationSnap) { value, state, _ in
                guard let layer = selectedOverlay else {
                    state.delta = value.rotation
                    state.isSnapped = false
                    return
                }
                let (delta, isSnapped) = Self.snappedRotation(
                    layerRotation: layer.rotation,
                    rawDelta: value.rotation
                )
                if isSnapped && !state.isSnapped {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                state.delta = delta
                state.isSnapped = isSnapped
            }
            .onChanged { _ in promoteOverlaySelection() }
            .onEnded { value in
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                let (delta, _) = Self.snappedRotation(
                    layerRotation: layer.rotation,
                    rawDelta: value.rotation
                )
                layer.rotation += delta
            }

        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
    }

    private func promoteOverlaySelection() {
        if session.isBackgroundSelected, selectedOverlay != nil {
            session.isBackgroundSelected = false
        }
    }
}

// MARK: - Background rendering

struct BackgroundView: View {
    let background: Background
    let side: CGFloat

    var body: some View {
        Group {
            switch background.kind {
            case .solid:
                background.solidColor
            case .linearGradient:
                LinearGradient(
                    colors: background.gradientColors,
                    startPoint: background.linearStart,
                    endPoint: background.linearEnd
                )
            case .radialGradient:
                RadialGradient(
                    colors: background.gradientColors,
                    center: background.gradientCenter,
                    startRadius: 0,
                    endRadius: side * 0.75
                )
            case .meshGradient:
                meshView
            case .ai:
                if let image = background.aiImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
        }
        .frame(width: side, height: side)
    }

    @ViewBuilder
    private var meshView: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0,   0  ], [0.5, 0  ], [1,   0  ],
                    [0,   0.5], [0.5, 0.5], [1,   0.5],
                    [0,   1  ], [0.5, 1  ], [1,   1  ]
                ],
                colors: background.meshColors
            )
        } else {
            // Pre-iOS 18 fallback: approximate with a linear gradient.
            LinearGradient(
                colors: [background.meshColors.first ?? .iaPurple,
                         background.meshColors.last ?? .iaOrange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Overlay rendering

private struct OverlayLayerView: View {
    let layer: Layer
    let side: CGFloat
    let isSelected: Bool
    let transientOffset: CGSize
    let transientScale: CGFloat
    let transientAngle: Angle
    let onTap: () -> Void

    var body: some View {
        LayerContentView(layer: layer, side: side)
            .shadow(
                color: .black.opacity(layer.shadowOpacity),
                radius: side * layer.shadowRadius,
                x: side * layer.shadowOffsetX,
                y: side * layer.shadowOffsetY
            )
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

struct LayerContentView: View {
    let layer: Layer
    let side: CGFloat

    var body: some View {
        switch layer.kind {
        case .aiOverlay:
            if let image = layer.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.7, height: side * 0.7)
            } else {
                Color.clear
                    .frame(width: side * 0.7, height: side * 0.7)
            }
        case .symbol:
            Image(systemName: layer.symbolName)
                .font(.system(size: side * 0.5, weight: layer.fontWeight.swiftUI))
                .foregroundStyle(layer.tintColor)
        case .emoji:
            Text(layer.emoji)
                .font(.system(size: side * 0.5))
        case .text:
            Text(layer.text)
                .font(.system(size: side * 0.3, weight: layer.fontWeight.swiftUI, design: .rounded))
                .foregroundStyle(layer.tintColor)
        }
    }
}

// MARK: - Transparency checkerboard

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
