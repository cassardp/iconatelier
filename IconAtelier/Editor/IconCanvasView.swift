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
        var snappedCircle: Int? = nil
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

    private static let keylineCircleRadii: [CGFloat] = [0.4, 0.3125, 0.125]

    private static func snappedMagnification(
        rawMagnification: CGFloat,
        layer: Layer,
        side: CGFloat
    ) -> (magnification: CGFloat, snappedLinesX: Set<Int>, snappedLinesY: Set<Int>, snappedCircle: Int?) {
        guard side > 0, rawMagnification.isFinite, rawMagnification > 0 else {
            return (rawMagnification, [], [], nil)
        }
        let baseHalf = layerHalfSize(layer)
        guard baseHalf > 0 else { return (rawMagnification, [], [], nil) }
        let currentHalf = baseHalf * rawMagnification
        let thresholdFraction = gridSnapThreshold / side

        var bestLine: (value: CGFloat, dist: CGFloat)?
        for value in snapHalfSizes {
            let dist = abs(value - currentHalf)
            if bestLine == nil || dist < bestLine!.dist {
                bestLine = (value, dist)
            }
        }
        var bestCircle: (value: CGFloat, idx: Int, dist: CGFloat)?
        for (idx, value) in keylineCircleRadii.enumerated() {
            let dist = abs(value - currentHalf)
            if bestCircle == nil || dist < bestCircle!.dist {
                bestCircle = (value, idx, dist)
            }
        }

        let lineDist = bestLine?.dist ?? .greatestFiniteMagnitude
        let circleDist = bestCircle?.dist ?? .greatestFiniteMagnitude

        if circleDist <= lineDist, let circle = bestCircle, circle.dist < thresholdFraction {
            return (circle.value / baseHalf, [], [], circle.idx)
        }

        guard let line = bestLine, line.dist < thresholdFraction else {
            return (rawMagnification, [], [], nil)
        }

        let half = line.value
        let centerX = layer.offset.width
        let centerY = layer.offset.height
        let matchTolerance: CGFloat = 0.001
        var snappedLinesX: Set<Int> = []
        var snappedLinesY: Set<Int> = []
        for (idx, gridLine) in gridOffsets.enumerated() {
            if abs(abs(gridLine - centerX) - half) < matchTolerance {
                snappedLinesX.insert(idx)
            }
            if abs(abs(gridLine - centerY) - half) < matchTolerance {
                snappedLinesY.insert(idx)
            }
        }
        return (half / baseHalf, snappedLinesX, snappedLinesY, nil)
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
        side: CGFloat,
        centerOnly: Bool = false
    ) -> (effective: CGSize, snappedLinesX: Set<Int>, snappedLinesY: Set<Int>) {
        guard side > 0 else { return (translation, [], []) }
        let thresholdFraction = gridSnapThreshold / side
        let matchTolerance: CGFloat = 0.001
        let centerX = layerOffset.width + translation.width / side
        let centerY = layerOffset.height + translation.height / side
        let activeOffsets: [CGFloat] = centerOnly ? [0] : gridOffsets

        func bestTarget(currentCenter: CGFloat) -> CGFloat? {
            var best: (target: CGFloat, dist: CGFloat)?
            for line in activeOffsets {
                let candidates: [CGFloat] = centerOnly
                    ? [line]
                    : [line, line - layerHalfSize, line + layerHalfSize]
                for candidate in candidates {
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
                let centerHit = abs(line - center) < matchTolerance
                let edgeHit = !centerOnly && (
                    abs(line - (center - layerHalfSize)) < matchTolerance
                    || abs(line - (center + layerHalfSize)) < matchTolerance
                )
                if centerHit || edgeHit {
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
        let activeX = dragSnap.snappedLinesX.union(magnifySnap.snappedLinesX)
        let activeY = dragSnap.snappedLinesY.union(magnifySnap.snappedLinesY)
        let activeCircle = magnifySnap.snappedCircle
        let showGrid = session.showGrid
        let neutralColor: Color = project.safeBackground.averageLuminance > 0.55
            ? Color.black.opacity(0.25)
            : Color.white.opacity(0.5)
        Canvas { context, size in
            let neutral = GraphicsContext.Shading.color(neutralColor)
            let active = GraphicsContext.Shading.color(Color.iaSelectionYellow)
            let step = size.width / CGFloat(Self.gridDivisions)
            let centerLineIndex = 3
            func strokeNeutral(_ path: Path) {
                context.stroke(path, with: neutral, lineWidth: 0.5)
            }
            for (slot, lineIndex) in Self.gridLineIndices.enumerated() {
                let isCenter = lineIndex == centerLineIndex
                let pos = step * CGFloat(lineIndex)
                let isXActive = activeX.contains(slot)
                let isYActive = activeY.contains(slot)
                let drawX = showGrid || (isCenter && isXActive)
                let drawY = showGrid || (isCenter && isYActive)
                if drawX {
                    var vertical = Path()
                    vertical.move(to: CGPoint(x: pos, y: 0))
                    vertical.addLine(to: CGPoint(x: pos, y: size.height))
                    if isXActive {
                        context.stroke(vertical, with: active, lineWidth: 1.0)
                    } else {
                        strokeNeutral(vertical)
                    }
                }
                if drawY {
                    var horizontal = Path()
                    horizontal.move(to: CGPoint(x: 0, y: pos))
                    horizontal.addLine(to: CGPoint(x: size.width, y: pos))
                    if isYActive {
                        context.stroke(horizontal, with: active, lineWidth: 1.0)
                    } else {
                        strokeNeutral(horizontal)
                    }
                }
            }
            if showGrid {
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for (idx, radius) in Self.keylineCircleRadii.enumerated() {
                    let r = radius * size.width
                    let rect = CGRect(
                        x: center.x - r,
                        y: center.y - r,
                        width: r * 2,
                        height: r * 2
                    )
                    let path = Path(ellipseIn: rect)
                    if activeCircle == idx {
                        context.stroke(path, with: active, lineWidth: 1.0)
                    } else {
                        strokeNeutral(path)
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func canvasGesture(side: CGFloat) -> some Gesture {
        let drag = DragGesture()
            .updating($dragSnap) { value, state, _ in
                if session.isMultiSelecting {
                    state.translation = value.translation
                    state.isActive = true
                    return
                }
                guard let layer = selectedOverlay else {
                    state.translation = value.translation
                    state.isActive = true
                    return
                }
                let result = Self.snappedToGrid(
                    translation: value.translation,
                    layerOffset: layer.offset,
                    layerHalfSize: Self.layerHalfSize(layer),
                    side: side,
                    centerOnly: !session.showGrid
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
                let effective = Self.snappedToGrid(
                    translation: value.translation,
                    layerOffset: layer.offset,
                    layerHalfSize: Self.layerHalfSize(layer),
                    side: side,
                    centerOnly: !session.showGrid
                ).effective
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
                let wasSnapped = !state.snappedLinesX.isEmpty
                    || !state.snappedLinesY.isEmpty
                    || state.snappedCircle != nil
                let isSnapped = !result.snappedLinesX.isEmpty
                    || !result.snappedLinesY.isEmpty
                    || result.snappedCircle != nil
                let circleChanged = state.snappedCircle != result.snappedCircle
                    && result.snappedCircle != nil
                if (isSnapped && !wasSnapped) || circleChanged {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                state.snappedLinesX = result.snappedLinesX
                state.snappedLinesY = result.snappedLinesY
                state.snappedCircle = result.snappedCircle
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

