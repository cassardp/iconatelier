import SwiftUI
import UIKit
import CoreText

struct IconCanvasView: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @GestureState private var dragSnap: DragSnapState = DragSnapState()
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var magnifySnap: MagnifySnapState = MagnifySnapState()
    @GestureState private var rotationSnap: RotationSnapState = RotationSnapState()

    private struct DragSnapState: Equatable {
        var translation: CGSize = .zero
        var snappedLinesX: Set<Int> = []
        var snappedLinesY: Set<Int> = []
        var isActive: Bool = false
    }

    private struct MagnifySnapState: Equatable {
        var snappedLinesX: Set<Int> = []
        var snappedLinesY: Set<Int> = []
    }

    private struct RotationSnapState: Equatable {
        var delta: Angle = .zero
        var isSnapped: Bool = false
    }

    private static let rotationSnapThreshold: Double = 5
    private static let gridSnapThreshold: CGFloat = 8

    private static let gridLineIndices: [Int] = [1, 3, 5]
    private static let gridDivisions: Int = 6

    private static let gridOffsets: [CGFloat] = {
        let step = 1.0 / CGFloat(gridDivisions)
        return gridLineIndices.map { step * CGFloat($0) - 0.5 }
    }()

    private static let snapHalfSizes: [CGFloat] = [1.0 / 6.0, 1.0 / 3.0, 0.5]

    private static func snappedMagnification(
        rawMagnification: CGFloat,
        layer: Layer,
        side: CGFloat
    ) -> (magnification: CGFloat, snappedLinesX: Set<Int>, snappedLinesY: Set<Int>) {
        guard side > 0, rawMagnification.isFinite, rawMagnification > 0 else {
            return (rawMagnification, [], [])
        }
        let baseHalf = layerHalfSize(layer)
        guard baseHalf > 0 else { return (rawMagnification, [], []) }
        let currentHalf = baseHalf * rawMagnification
        let thresholdFraction = gridSnapThreshold / side

        guard let nearest = snapHalfSizes.min(by: { abs($0 - currentHalf) < abs($1 - currentHalf) }),
              abs(nearest - currentHalf) < thresholdFraction
        else {
            return (rawMagnification, [], [])
        }

        let half = nearest
        let centerX = layer.offset.width
        let centerY = layer.offset.height
        let matchTolerance: CGFloat = 0.001
        var snappedLinesX: Set<Int> = []
        var snappedLinesY: Set<Int> = []
        for (idx, line) in gridOffsets.enumerated() {
            if abs(abs(line - centerX) - half) < matchTolerance {
                snappedLinesX.insert(idx)
            }
            if abs(abs(line - centerY) - half) < matchTolerance {
                snappedLinesY.insert(idx)
            }
        }
        return (half / baseHalf, snappedLinesX, snappedLinesY)
    }

    private static func layerHalfSize(_ layer: Layer) -> CGFloat {
        let base: CGFloat
        switch layer.kind {
        case .image: base = 0.7
        case .text: base = 0.6
        case .parametricShape: base = 0.5
        }
        return base * layer.scale / 2
    }

    private static func snappedToGrid(
        translation: CGSize,
        layerOffset: CGSize,
        layerHalfSize: CGFloat,
        side: CGFloat
    ) -> (effective: CGSize, snappedLinesX: Set<Int>, snappedLinesY: Set<Int>) {
        guard side > 0 else { return (translation, [], []) }
        let thresholdFraction = gridSnapThreshold / side
        let matchTolerance: CGFloat = 0.001
        let centerX = layerOffset.width + translation.width / side
        let centerY = layerOffset.height + translation.height / side

        func bestTarget(currentCenter: CGFloat) -> CGFloat? {
            var best: (target: CGFloat, dist: CGFloat)?
            for line in gridOffsets {
                for candidate in [line, line - layerHalfSize, line + layerHalfSize] {
                    let dist = abs(candidate - currentCenter)
                    if best == nil || dist < best!.dist {
                        best = (candidate, dist)
                    }
                }
            }
            guard let b = best, b.dist < thresholdFraction else { return nil }
            return b.target
        }

        func touchedLines(center: CGFloat) -> Set<Int> {
            var lines: Set<Int> = []
            for (idx, line) in gridOffsets.enumerated() {
                if abs(line - center) < matchTolerance
                    || abs(line - (center - layerHalfSize)) < matchTolerance
                    || abs(line - (center + layerHalfSize)) < matchTolerance {
                    lines.insert(idx)
                }
            }
            return lines
        }

        var effective = translation
        var snappedLinesX: Set<Int> = []
        var snappedLinesY: Set<Int> = []
        if let targetX = bestTarget(currentCenter: centerX) {
            effective.width = (targetX - layerOffset.width) * side
            snappedLinesX = touchedLines(center: targetX)
        }
        if let targetY = bestTarget(currentCenter: centerY) {
            effective.height = (targetY - layerOffset.height) * side
            snappedLinesY = touchedLines(center: targetY)
        }
        return (effective, snappedLinesX, snappedLinesY)
    }

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

    private func multiGroupCentroid() -> CGSize? {
        guard session.isMultiSelecting else { return nil }
        let selected = project.layers.filter {
            !$0.isHidden && session.lassoSelectedLayerUUIDs.contains($0.uuid)
        }
        guard !selected.isEmpty else { return nil }
        let count = CGFloat(selected.count)
        let cx = selected.map(\.offset.width).reduce(0, +) / count
        let cy = selected.map(\.offset.height).reduce(0, +) / count
        return CGSize(width: cx, height: cy)
    }

    private struct LayerTransient {
        var offset: CGSize
        var scale: CGFloat
        var angle: Angle
    }

    private func transientForRender(
        layer: Layer,
        isSelected: Bool,
        isInMultiDrag: Bool,
        pivot: CGSize?,
        side: CGFloat
    ) -> LayerTransient {
        if isSelected {
            return LayerTransient(
                offset: dragSnap.translation,
                scale: gestureScale,
                angle: rotationSnap.delta
            )
        }
        guard isInMultiDrag, let pivot else {
            return LayerTransient(offset: .zero, scale: 1, angle: .zero)
        }
        let m = gestureScale
        let theta = CGFloat(rotationSnap.delta.radians)
        let dx = layer.offset.width - pivot.width
        let dy = layer.offset.height - pivot.height
        let rx = dx * cos(theta) - dy * sin(theta)
        let ry = dx * sin(theta) + dy * cos(theta)
        let nx = pivot.width + rx * m
        let ny = pivot.height + ry * m
        let pivotShiftX = (nx - layer.offset.width) * side
        let pivotShiftY = (ny - layer.offset.height) * side
        return LayerTransient(
            offset: CGSize(
                width: pivotShiftX + dragSnap.translation.width,
                height: pivotShiftY + dragSnap.translation.height
            ),
            scale: m,
            angle: rotationSnap.delta
        )
    }

    private func squircleIcon(side: CGFloat) -> some View {
        ZStack {
            if project.safeBackground.isHidden {
                TransparencyCheckerboard(tile: 14)
            } else {
                BackgroundView(background: project.safeBackground, side: side)
            }
            let groupPivot = multiGroupCentroid()
            ForEach(project.layers) { layer in
                if !layer.isHidden {
                    let isSelected = layer.uuid == session.selectedLayerUUID
                    let isInMultiDrag = session.isMultiSelecting
                        && session.lassoSelectedLayerUUIDs.contains(layer.uuid)
                    let transient = transientForRender(
                        layer: layer,
                        isSelected: isSelected,
                        isInMultiDrag: isInMultiDrag,
                        pivot: groupPivot,
                        side: side
                    )
                    OverlayLayerView(
                        layer: layer,
                        side: side,
                        isSelected: isSelected,
                        transientOffset: transient.offset,
                        transientScale: transient.scale,
                        transientAngle: transient.angle,
                        onTap: { session.selectLayer(layer.uuid) }
                    )
                    .transition(.scale(scale: 1.12).combined(with: .opacity))
                }
            }
            gridOverlay(side: side)
        }
        .frame(width: side, height: side)
        .clipShape(SquircleShape())
    }

    @ViewBuilder
    private func gridOverlay(side: CGFloat) -> some View {
        if session.showGrid {
            let activeX = dragSnap.snappedLinesX.union(magnifySnap.snappedLinesX)
            let activeY = dragSnap.snappedLinesY.union(magnifySnap.snappedLinesY)
            Canvas { context, size in
                let neutral = GraphicsContext.Shading.color(Color.gray.opacity(0.6))
                let active = GraphicsContext.Shading.color(Color.iaSelectionYellow)
                let step = size.width / CGFloat(Self.gridDivisions)
                for (slot, lineIndex) in Self.gridLineIndices.enumerated() {
                    let pos = step * CGFloat(lineIndex)
                    let isXActive = activeX.contains(slot)
                    let isYActive = activeY.contains(slot)
                    var vertical = Path()
                    vertical.move(to: CGPoint(x: pos, y: 0))
                    vertical.addLine(to: CGPoint(x: pos, y: size.height))
                    context.stroke(
                        vertical,
                        with: isXActive ? active : neutral,
                        lineWidth: isXActive ? 1.0 : 0.5
                    )
                    var horizontal = Path()
                    horizontal.move(to: CGPoint(x: 0, y: pos))
                    horizontal.addLine(to: CGPoint(x: size.width, y: pos))
                    context.stroke(
                        horizontal,
                        with: isYActive ? active : neutral,
                        lineWidth: isYActive ? 1.0 : 0.5
                    )
                }
            }
            .frame(width: side, height: side)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func canvasGesture(side: CGFloat) -> some Gesture {
        let drag = DragGesture()
            .updating($dragSnap) { value, state, _ in
                if session.isMultiSelecting {
                    state.translation = value.translation
                    state.isActive = true
                    return
                }
                guard session.showGrid, let layer = selectedOverlay else {
                    state.translation = value.translation
                    state.isActive = true
                    return
                }
                let result = Self.snappedToGrid(
                    translation: value.translation,
                    layerOffset: layer.offset,
                    layerHalfSize: Self.layerHalfSize(layer),
                    side: side
                )
                let wasSnapped = !state.snappedLinesX.isEmpty || !state.snappedLinesY.isEmpty
                let isSnapped = !result.snappedLinesX.isEmpty || !result.snappedLinesY.isEmpty
                let changedX = state.snappedLinesX != result.snappedLinesX && !result.snappedLinesX.isEmpty
                let changedY = state.snappedLinesY != result.snappedLinesY && !result.snappedLinesY.isEmpty
                if (isSnapped && !wasSnapped) || changedX || changedY {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                state.translation = result.effective
                state.snappedLinesX = result.snappedLinesX
                state.snappedLinesY = result.snappedLinesY
                state.isActive = true
            }
            .onChanged { _ in promoteOverlaySelection() }
            .onEnded { value in
                guard side > 0,
                      value.translation.width.isFinite,
                      value.translation.height.isFinite
                else { return }
                if session.isMultiSelecting {
                    let dx = value.translation.width / side
                    let dy = value.translation.height / side
                    let ids = session.lassoSelectedLayerUUIDs
                    let targets = project.layers.filter { ids.contains($0.uuid) }
                    guard !targets.isEmpty else { return }
                    project.recordUndo()
                    for layer in targets {
                        let nx = layer.offset.width + dx
                        let ny = layer.offset.height + dy
                        guard nx.isFinite, ny.isFinite else { continue }
                        layer.offset = CGSize(
                            width: min(max(nx, -0.5), 0.5),
                            height: min(max(ny, -0.5), 0.5)
                        )
                    }
                    return
                }
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                let effective: CGSize
                if session.showGrid {
                    effective = Self.snappedToGrid(
                        translation: value.translation,
                        layerOffset: layer.offset,
                        layerHalfSize: Self.layerHalfSize(layer),
                        side: side
                    ).effective
                } else {
                    effective = value.translation
                }
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
                if session.isMultiSelecting || !session.showGrid {
                    state = value.magnification
                    return
                }
                guard let layer = selectedOverlay else {
                    state = value.magnification
                    return
                }
                let result = Self.snappedMagnification(
                    rawMagnification: value.magnification,
                    layer: layer,
                    side: side
                )
                state = result.magnification
            }
            .updating($magnifySnap) { value, state, _ in
                guard value.magnification.isFinite, value.magnification > 0,
                      session.showGrid, !session.isMultiSelecting,
                      let layer = selectedOverlay else {
                    state = MagnifySnapState()
                    return
                }
                let result = Self.snappedMagnification(
                    rawMagnification: value.magnification,
                    layer: layer,
                    side: side
                )
                let wasSnapped = !state.snappedLinesX.isEmpty || !state.snappedLinesY.isEmpty
                let isSnapped = !result.snappedLinesX.isEmpty || !result.snappedLinesY.isEmpty
                if isSnapped && !wasSnapped {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                state.snappedLinesX = result.snappedLinesX
                state.snappedLinesY = result.snappedLinesY
            }
            .onChanged { _ in promoteOverlaySelection() }
            .onEnded { value in
                guard value.magnification.isFinite, value.magnification > 0 else { return }
                if session.isMultiSelecting, let pivot = multiGroupCentroid() {
                    let m = value.magnification
                    let ids = session.lassoSelectedLayerUUIDs
                    let targets = project.layers.filter { ids.contains($0.uuid) }
                    guard !targets.isEmpty else { return }
                    project.recordUndo()
                    for layer in targets {
                        let dx = layer.offset.width - pivot.width
                        let dy = layer.offset.height - pivot.height
                        let nx = pivot.width + dx * m
                        let ny = pivot.height + dy * m
                        layer.offset = CGSize(
                            width: min(max(nx, -0.5), 0.5),
                            height: min(max(ny, -0.5), 0.5)
                        )
                        layer.scale = max(0.1, layer.scale * m)
                    }
                    return
                }
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                let effectiveMagnification: CGFloat
                if session.showGrid {
                    effectiveMagnification = Self.snappedMagnification(
                        rawMagnification: value.magnification,
                        layer: layer,
                        side: side
                    ).magnification
                } else {
                    effectiveMagnification = value.magnification
                }
                layer.scale = max(0.1, layer.scale * effectiveMagnification)
            }

        let rotate = RotateGesture(minimumAngleDelta: .degrees(1))
            .updating($rotationSnap) { value, state, _ in
                guard value.rotation.degrees.isFinite else { return }
                if session.isMultiSelecting {

                    state.delta = value.rotation
                    state.isSnapped = false
                    return
                }
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
                guard value.rotation.degrees.isFinite else { return }
                if session.isMultiSelecting, let pivot = multiGroupCentroid() {
                    let theta = CGFloat(value.rotation.radians)
                    let ids = session.lassoSelectedLayerUUIDs
                    let targets = project.layers.filter { ids.contains($0.uuid) }
                    guard !targets.isEmpty else { return }
                    project.recordUndo()
                    for layer in targets {
                        let dx = layer.offset.width - pivot.width
                        let dy = layer.offset.height - pivot.height
                        let rx = dx * cos(theta) - dy * sin(theta)
                        let ry = dx * sin(theta) + dy * cos(theta)
                        let nx = pivot.width + rx
                        let ny = pivot.height + ry
                        layer.offset = CGSize(
                            width: min(max(nx, -0.5), 0.5),
                            height: min(max(ny, -0.5), 0.5)
                        )
                        layer.rotation = Self.normalized(layer.rotation + value.rotation)
                    }
                    return
                }
                guard let layer = selectedOverlay else { return }
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
                width: 5,
                height: 5,
                points: Paint.mesh25Points(corners: background.storedMeshCornerPoints),
                colors: Paint.mesh25Colors(from: background.meshColors)
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(angle))
        } else {

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

        .onTapGesture {
            if !isSelected {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            onTap()
        }
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
        case .image:
            let imageSide = side * 0.7 * scale
            if let image = layer.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: imageSide, height: imageSide)
                    .colorMultiply(layer.tintColor)
                    .contentShape(Rectangle())
            } else {
                Color.clear
                    .frame(width: imageSide, height: imageSide)
                    .contentShape(Rectangle())
            }
        case .text:

            let textSide = side * 0.6 * scale
            let glyphShape = TextGlyphShape(
                text: layer.text,
                weight: layer.fontWeight,
                design: layer.fontDesign
            )
            let renderShape: AnyShape = {
                if let params = layer.shapeSpec?.radialRepeatParams {
                    return AnyShape(RadialRepeat(
                        base: glyphShape,
                        count: params.count,
                        centerHole: params.centerHole
                    ))
                }
                return AnyShape(glyphShape)
            }()
            let strokeWidth = textSide * CGFloat(layer.borderWidth)
            ZStack {
                if layer.fillEnabled {
                    PaintFill(renderShape, paint: layer.fillPaint, side: textSide)
                }
                if strokeWidth > 0 {
                    borderView(
                        shape: renderShape,
                        width: strokeWidth,
                        color: layer.borderColor,
                        position: layer.borderPosition,
                        lineCap: layer.lineCap.cgLineCap
                    )
                }
            }
            .frame(width: textSide, height: textSide)

            .contentShape(renderShape)
        case .parametricShape:
            let shapeSide = side * 0.5 * scale
            if let spec = layer.shapeSpec {
                let shape = spec.anyShape()
                let strokeWidth = shapeSide * CGFloat(layer.borderWidth)
                ZStack {
                    if layer.fillEnabled {
                        PaintFill(shape, paint: layer.fillPaint, side: shapeSide)
                    }
                    if strokeWidth > 0 {
                        borderView(
                            shape: shape,
                            width: strokeWidth,

                            color: layer.borderColor,
                            position: spec.isOpenPath ? .center : layer.borderPosition,
                            lineCap: layer.lineCap.cgLineCap
                        )
                    }
                }
                .frame(width: shapeSide, height: shapeSide)

                .contentShape(spec.isOpenPath ? AnyShape(Rectangle()) : shape)
            } else {
                Color.clear
                    .frame(width: shapeSide, height: shapeSide)
                    .contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private func borderView(shape: AnyShape, width: CGFloat, color: Color, position: BorderPosition, lineCap: CGLineCap) -> some View {

        switch position {
        case .center:
            shape.stroke(color, style: StrokeStyle(lineWidth: width, lineCap: lineCap, lineJoin: .round))
        case .inner:
            shape.stroke(color, style: StrokeStyle(lineWidth: width * 2, lineCap: lineCap, lineJoin: .round))
                .clipShape(shape)
        case .outer:
            shape.stroke(color, style: StrokeStyle(lineWidth: width * 2, lineCap: lineCap, lineJoin: .round))
                .overlay(shape.fill(.black).blendMode(.destinationOut))
                .compositingGroup()
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
