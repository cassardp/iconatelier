import SwiftUI
import UIKit
import CoreText

struct IconCanvasView: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @GestureState private var dragSnap: DragSnapState = DragSnapState()
    @GestureState private var gestureScale: CGFloat = 1.0
    @GestureState private var rotationSnap: RotationSnapState = RotationSnapState()
    @State private var didDragHitTest: Bool = false

    enum SnapAxis: CaseIterable, Hashable {
        case vertical, horizontal, diagonal, antiDiagonal
    }

    private struct DragSnapState: Equatable {
        var translation: CGSize = .zero
        var activeAxes: Set<SnapAxis> = []
        var isActive: Bool = false
    }

    private struct RotationSnapState: Equatable {
        var delta: Angle = .zero
        var isSnapped: Bool = false
    }

    private static let rotationSnapThreshold: Double = 5
    private static let gridSnapThreshold: CGFloat = 8

    private static func signedDistance(of point: CGSize, to axis: SnapAxis) -> CGFloat {
        switch axis {
        case .vertical: return point.width
        case .horizontal: return point.height
        case .diagonal: return (point.height - point.width) / sqrt(2)
        case .antiDiagonal: return (point.height + point.width) / sqrt(2)
        }
    }

    private static func project(_ point: CGSize, onto axis: SnapAxis) -> CGSize {
        switch axis {
        case .vertical:
            return CGSize(width: 0, height: point.height)
        case .horizontal:
            return CGSize(width: point.width, height: 0)
        case .diagonal:
            let t = (point.width + point.height) / 2
            return CGSize(width: t, height: t)
        case .antiDiagonal:
            let t = (point.width - point.height) / 2
            return CGSize(width: t, height: -t)
        }
    }

    private static func snappedToAxes(
        translation: CGSize,
        layerOffset: CGSize,
        side: CGFloat
    ) -> (effective: CGSize, activeAxes: Set<SnapAxis>) {
        guard side > 0 else { return (translation, []) }
        let thresholdFraction = gridSnapThreshold / side
        let centerThresholdFraction = thresholdFraction * 1.5
        let candidate = CGSize(
            width: layerOffset.width + translation.width / side,
            height: layerOffset.height + translation.height / side
        )
        let distanceToCenter = hypot(candidate.width, candidate.height)
        if distanceToCenter < centerThresholdFraction {
            let effective = CGSize(
                width: -layerOffset.width * side,
                height: -layerOffset.height * side
            )
            return (effective, Set(SnapAxis.allCases))
        }
        var best: (axis: SnapAxis, dist: CGFloat)?
        for axis in SnapAxis.allCases {
            let dist = abs(signedDistance(of: candidate, to: axis))
            if best == nil || dist < best!.dist {
                best = (axis, dist)
            }
        }
        guard let chosen = best, chosen.dist < thresholdFraction else {
            return (translation, [])
        }
        let snapped = project(candidate, onto: chosen.axis)
        let effective = CGSize(
            width: (snapped.width - layerOffset.width) * side,
            height: (snapped.height - layerOffset.height) * side
        )
        return (effective, [chosen.axis])
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
            .highPriorityGesture(canvasGesture(side: canvasSide, canvasSize: geo.size))
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
            !$0.isLocked && session.lassoSelectedLayerUUIDs.contains($0.uuid)
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
        if layer.isLocked {
            return LayerTransient(offset: .zero, scale: 1, angle: .zero)
        }
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
            BackgroundView(background: project.safeBackground, side: side)
            let groupPivot = multiGroupCentroid()
            ForEach(project.layers) { layer in
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
            gridOverlay(side: side)
        }
        .frame(width: side, height: side)
        .clipShape(SquircleShape())
    }

    @ViewBuilder
    private func gridOverlay(side: CGFloat) -> some View {
        let showGrid = session.showGrid
        let activeAxes = dragSnap.activeAxes
        let neutralColor: Color = project.safeBackground.averageLuminance > 0.55
            ? Color.black.opacity(0.25)
            : Color.white.opacity(0.5)
        Canvas { context, size in
            let neutral = GraphicsContext.Shading.color(neutralColor)
            let active = GraphicsContext.Shading.color(Color.iaSelectionYellow)
            let cx = size.width / 2
            let cy = size.height / 2
            func endpoints(for axis: SnapAxis) -> (CGPoint, CGPoint) {
                switch axis {
                case .vertical:
                    return (CGPoint(x: cx, y: 0), CGPoint(x: cx, y: size.height))
                case .horizontal:
                    return (CGPoint(x: 0, y: cy), CGPoint(x: size.width, y: cy))
                case .diagonal:
                    return (CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: size.height))
                case .antiDiagonal:
                    return (CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: 0))
                }
            }
            for axis in SnapAxis.allCases {
                let isActive = activeAxes.contains(axis)
                guard showGrid || isActive else { continue }
                let (a, b) = endpoints(for: axis)
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                if isActive {
                    context.stroke(path, with: active, lineWidth: 1.0)
                } else {
                    context.stroke(path, with: neutral, lineWidth: 0.5)
                }
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func hitTestLayer(at point: CGPoint, side: CGFloat, canvasSize: CGSize) -> Layer? {
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        for layer in project.layers.reversed() {
            guard !layer.isLocked else { continue }
            let baseFactor: CGFloat
            switch layer.kind {
            case .image: baseFactor = 0.7
            case .text: baseFactor = 0.6
            case .parametricShape: baseFactor = 0.5
            }
            let halfSide = side * baseFactor * layer.scale / 2
            guard halfSide > 0 else { continue }
            let layerCenterX = centerX + layer.offset.width * side
            let layerCenterY = centerY + layer.offset.height * side
            let dx = point.x - layerCenterX
            let dy = point.y - layerCenterY
            let angle = -CGFloat(layer.rotation.radians)
            let cosA = cos(angle)
            let sinA = sin(angle)
            let rx = dx * cosA - dy * sinA
            let ry = dx * sinA + dy * cosA
            guard abs(rx) <= halfSide && abs(ry) <= halfSide else { continue }
            if layer.kind == .image {
                let frameSide = halfSide * 2
                if Self.imageHasOpaquePixel(in: layer, atLocal: CGPoint(x: rx, y: ry), frameSide: frameSide) {
                    return layer
                }
                continue
            }
            if layer.kind == .parametricShape {
                if Self.parametricShapeContains(layer: layer, localX: rx, localY: ry, halfSide: halfSide) {
                    return layer
                }
                continue
            }
            return layer
        }
        return nil
    }

    private static func parametricShapeContains(layer: Layer, localX: CGFloat, localY: CGFloat, halfSide: CGFloat) -> Bool {
        guard let spec = layer.shapeSpec, halfSide > 0 else { return true }
        if spec.isOpenPath { return true }
        let lx = layer.isFlippedHorizontally ? -localX : localX
        let ly = layer.isFlippedVertically ? -localY : localY
        let shapeSide = halfSide * 2
        let path = spec.anyShape().path(in: CGRect(x: 0, y: 0, width: shapeSide, height: shapeSide))
        let pathPoint = CGPoint(x: lx + halfSide, y: ly + halfSide)
        if path.contains(pathPoint) { return true }
        let borderWidth = shapeSide * CGFloat(layer.borderWidth)
        if borderWidth > 0 {
            let stroked = path.strokedPath(StrokeStyle(lineWidth: borderWidth * 2))
            return stroked.contains(pathPoint)
        }
        return false
    }

    private static func imageHasOpaquePixel(in layer: Layer, atLocal point: CGPoint, frameSide: CGFloat) -> Bool {
        guard let uiImage = layer.image, let cgImage = uiImage.cgImage else { return true }
        let lx = layer.isFlippedHorizontally ? -point.x : point.x
        let ly = layer.isFlippedVertically ? -point.y : point.y
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        guard w > 0, h > 0, frameSide > 0 else { return true }
        let aspect = w / h
        let renderedW: CGFloat
        let renderedH: CGFloat
        if aspect >= 1 {
            renderedW = frameSide
            renderedH = frameSide / aspect
        } else {
            renderedW = frameSide * aspect
            renderedH = frameSide
        }
        let imgX = lx + renderedW / 2
        let imgY = ly + renderedH / 2
        guard imgX >= 0, imgX < renderedW, imgY >= 0, imgY < renderedH else { return false }
        let px = Int((imgX / renderedW * w).rounded(.down))
        let py = Int((imgY / renderedH * h).rounded(.down))
        let clampedX = max(0, min(cgImage.width - 1, px))
        let clampedY = max(0, min(cgImage.height - 1, py))
        return sampleAlpha(cgImage: cgImage, x: clampedX, y: clampedY) > 0.05
    }

    private static func sampleAlpha(cgImage: CGImage, x: Int, y: Int) -> CGFloat {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return 1 }
        context.interpolationQuality = .none
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let drawRect = CGRect(
            x: -CGFloat(x),
            y: CGFloat(y) - height + 1,
            width: width,
            height: height
        )
        context.draw(cgImage, in: drawRect)
        return CGFloat(pixel[3]) / 255.0
    }

    private func canvasGesture(side: CGFloat, canvasSize: CGSize) -> some Gesture {
        let drag = DragGesture()
            .updating($dragSnap) { value, state, _ in
                let pivotOffset: CGSize?
                if session.isMultiSelecting {
                    pivotOffset = multiGroupCentroid()
                } else {
                    pivotOffset = selectedOverlay?.offset
                }
                guard session.showGrid, let pivot = pivotOffset else {
                    state.translation = value.translation
                    state.activeAxes = []
                    state.isActive = true
                    return
                }
                let result = Self.snappedToAxes(
                    translation: value.translation,
                    layerOffset: pivot,
                    side: side
                )
                let wasSnapped = !state.activeAxes.isEmpty
                let isSnapped = !result.activeAxes.isEmpty
                if (isSnapped && !wasSnapped) || (isSnapped && state.activeAxes != result.activeAxes) {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                state.translation = result.effective
                state.activeAxes = result.activeAxes
                state.isActive = true
            }
            .onChanged { value in
                if !didDragHitTest {
                    didDragHitTest = true
                    if !session.isMultiSelecting,
                       let hit = hitTestLayer(at: value.startLocation, side: side, canvasSize: canvasSize),
                       session.selectedLayerUUID != hit.uuid {
                        session.selectLayer(hit.uuid)
                    }
                }
                promoteOverlaySelection()
            }
            .onEnded { value in
                didDragHitTest = false
                guard side > 0,
                      value.translation.width.isFinite,
                      value.translation.height.isFinite
                else { return }
                if session.isMultiSelecting {
                    let effective: CGSize
                    if session.showGrid, let pivot = multiGroupCentroid() {
                        effective = Self.snappedToAxes(
                            translation: value.translation,
                            layerOffset: pivot,
                            side: side
                        ).effective
                    } else {
                        effective = value.translation
                    }
                    let dx = effective.width / side
                    let dy = effective.height / side
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
                guard let layer = selectedOverlay, !layer.isLocked else { return }
                project.recordUndo()
                let effective: CGSize
                if session.showGrid {
                    effective = Self.snappedToAxes(
                        translation: value.translation,
                        layerOffset: layer.offset,
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
                state = value.magnification
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
                guard let layer = selectedOverlay, !layer.isLocked else { return }
                project.recordUndo()
                layer.scale = max(0.1, layer.scale * value.magnification)
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
                guard let layer = selectedOverlay, !layer.isLocked else { return }
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

