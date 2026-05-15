import SwiftUI
import UIKit
import CoreText

struct IconCanvasView: View {
    @Bindable var project: IconProject
    let session: ProjectSession

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

    static func normalized(_ angle: Angle) -> Angle {
        let d = angle.degrees
        guard d.isFinite else { return .zero }
        let r = d.truncatingRemainder(dividingBy: 360)
        if r > 180 { return .degrees(r - 360) }
        if r <= -180 { return .degrees(r + 360) }
        return .degrees(r)
    }

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
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .geometryGroup()
            .contentShape(Rectangle())
            .highPriorityGesture(canvasGesture(side: canvasSide))
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
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
                    .transition(.scale(scale: 1.12).combined(with: .opacity))
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
                    .fill(Color.iaSelectionYellow)
                    .frame(width: 1, height: side)
                    .transition(.opacity)
            }
            if showHorizontal {
                Rectangle()
                    .fill(Color.iaSelectionYellow)
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
                guard side > 0,
                      value.translation.width.isFinite,
                      value.translation.height.isFinite
                else { return }
                project.recordUndo()
                let (effective, _) = Self.snapped(
                    translation: value.translation,
                    layerOffset: layer.offset,
                    side: side
                )
                let nextWidth = layer.offset.width + effective.width / side
                let nextHeight = layer.offset.height + effective.height / side
                guard nextWidth.isFinite, nextHeight.isFinite else { return }
                layer.offset = CGSize(
                    width: min(max(nextWidth, -0.5), 0.5),
                    height: min(max(nextHeight, -0.5), 0.5)
                )
            }

        let magnify = MagnifyGesture(minimumScaleDelta: 0.01)
            .updating($gestureScale) { value, state, _ in
                guard value.magnification.isFinite, value.magnification > 0 else { return }
                state = value.magnification
            }
            .onChanged { _ in promoteOverlaySelection() }
            .onEnded { value in
                guard let layer = selectedOverlay else { return }
                guard value.magnification.isFinite, value.magnification > 0 else { return }
                project.recordUndo()
                layer.scale = max(0.1, layer.scale * value.magnification)
            }

        let rotate = RotateGesture(minimumAngleDelta: .degrees(1))
            .updating($rotationSnap) { value, state, _ in
                guard value.rotation.degrees.isFinite else { return }
                guard let layer = selectedOverlay else {
                    state.delta = value.rotation
                    state.isSnapped = false
                    return
                }
                let (delta, isSnapped) = Self.snappedRotation(
                    layerRotation: layer.rotation,
                    rawDelta: value.rotation
                )
                guard delta.degrees.isFinite else { return }
                if isSnapped && !state.isSnapped {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                state.delta = delta
                state.isSnapped = isSnapped
            }
            .onChanged { _ in promoteOverlaySelection() }
            .onEnded { value in
                guard let layer = selectedOverlay else { return }
                guard value.rotation.degrees.isFinite else { return }
                project.recordUndo()
                let (delta, _) = Self.snappedRotation(
                    layerRotation: layer.rotation,
                    rawDelta: value.rotation
                )
                guard delta.degrees.isFinite else { return }
                layer.rotation = Self.normalized(layer.rotation + delta)
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
                    endRadius: side * CGFloat(background.radialSpread)
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
            let angle = background.meshRotationDegrees
            let rad = angle * .pi / 180
            let scale = abs(cos(rad)) + abs(sin(rad))
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
            .scaleEffect(scale)
            .rotationEffect(.degrees(angle))
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
        OverlayLayerRender(
            layer: layer,
            side: side,
            transientOffset: transientOffset,
            transientScale: transientScale,
            transientAngle: transientAngle
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

struct OverlayLayerRender: View {
    let layer: Layer
    let side: CGFloat
    var transientOffset: CGSize = .zero
    var transientScale: CGFloat = 1.0
    var transientAngle: Angle = .zero

    var body: some View {
        let effectiveScale = layer.scale * transientScale
        LayerContentView(layer: layer, side: side, scale: effectiveScale)
            .shadow(
                color: layer.shadowColor.opacity(layer.shadowOpacity),
                radius: side * layer.shadowRadius * effectiveScale,
                x: side * layer.shadowOffsetX * effectiveScale,
                y: side * layer.shadowOffsetY * effectiveScale
            )
            .rotationEffect(layer.rotation + transientAngle)
            .opacity(layer.opacity)
            .offset(
                x: layer.offset.width * side + transientOffset.width,
                y: layer.offset.height * side + transientOffset.height
            )
    }
}

struct LayerContentView: View {
    let layer: Layer
    let side: CGFloat
    var scale: CGFloat = 1.0

    var body: some View {
        content
            .scaleEffect(
                x: layer.isFlippedHorizontally ? -1 : 1,
                y: layer.isFlippedVertically ? -1 : 1
            )
    }

    @ViewBuilder
    private var content: some View {
        switch layer.kind {
        case .aiOverlay:
            let aiSide = side * 0.7 * scale
            if let image = layer.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: aiSide, height: aiSide)
                    .colorMultiply(layer.tintColor)
            } else {
                Color.clear
                    .frame(width: aiSide, height: aiSide)
            }
        case .symbol:
            Image(systemName: layer.symbolName)
                .font(.system(size: side * 0.5 * scale, weight: layer.fontWeight.swiftUI))
                .foregroundStyle(layer.tintColor)
        case .emoji:
            Text(layer.emoji)
                .font(.system(size: side * 0.5 * scale))
        case .text:
            let fontSize = side * 0.3 * scale
            let metrics = TextOverlayMetrics.measure(
                text: layer.text,
                size: fontSize,
                weight: layer.fontWeight,
                design: layer.fontDesign
            )
            Text(layer.text)
                .font(.system(size: fontSize, weight: layer.fontWeight.swiftUI))
                .fontDesign(layer.fontDesign.swiftUI)
                .foregroundStyle(layer.tintColor)
                .fixedSize()
                .offset(y: metrics.centerOffsetY)
                .frame(width: metrics.glyphWidth, height: metrics.glyphHeight)
        }
    }
}

private enum TextOverlayMetrics {
    struct Result {
        var glyphWidth: CGFloat
        var glyphHeight: CGFloat
        var centerOffsetY: CGFloat
    }

    static func measure(
        text: String,
        size: CGFloat,
        weight: LayerFontWeight,
        design: LayerFontDesign
    ) -> Result {
        let font = uiFont(size: size, weight: weight, design: design)
        guard !text.isEmpty else {
            return Result(glyphWidth: 0, glyphHeight: 0, centerOffsetY: 0)
        }
        let attr = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attr)
        let glyph = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let glyphCenterAboveBaseline = glyph.minY + glyph.height / 2
        let glyphCenterFromTop = font.ascender - glyphCenterAboveBaseline
        let frameCenterFromTop = font.lineHeight / 2
        return Result(
            glyphWidth: max(glyph.width, 1),
            glyphHeight: max(glyph.height, 1),
            centerOffsetY: frameCenterFromTop - glyphCenterFromTop
        )
    }

    private static func uiFont(
        size: CGFloat,
        weight: LayerFontWeight,
        design: LayerFontDesign
    ) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        if let descriptor = base.fontDescriptor.withDesign(uiDesign(design)) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    private static func uiWeight(_ w: LayerFontWeight) -> UIFont.Weight {
        switch w {
        case .regular:  return .regular
        case .medium:   return .medium
        case .semibold: return .semibold
        case .bold:     return .bold
        case .heavy:    return .heavy
        }
    }

    private static func uiDesign(_ d: LayerFontDesign) -> UIFontDescriptor.SystemDesign {
        switch d {
        case .default:    return .default
        case .serif:      return .serif
        case .rounded:    return .rounded
        case .monospaced: return .monospaced
        }
    }
}

// MARK: - Transparency checkerboard

struct TransparencyCheckerboard: View {
    let tile: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var lightTile: Color {
        colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.92)
    }

    private var darkTile: Color {
        colorScheme == .dark ? Color(white: 0.32) : Color(white: 0.78)
    }

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(lightTile))
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
            context.fill(path, with: .color(darkTile))
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}
