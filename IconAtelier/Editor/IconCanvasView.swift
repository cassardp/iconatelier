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

    struct SnapGuide: Equatable {
        enum Orientation: Hashable { case vertical, horizontal }
        let orientation: Orientation
        let position: CGFloat
        let extentStart: CGFloat
        let extentEnd: CGFloat
    }

    private struct DragSnapState: Equatable {
        var translation: CGSize = .zero
        var objectGuides: [SnapGuide] = []
        var isActive: Bool = false
    }

    private struct RotationSnapState: Equatable {
        var delta: Angle = .zero
        var isSnapped: Bool = false
    }

    private static let rotationSnapThreshold: Double = 5
    private static let objectSnapThreshold: CGFloat = 6

    private static func layerNormalizedBounds(_ layer: Layer) -> CGRect {
        let baseFactor: CGFloat
        switch layer.kind {
        case .image: baseFactor = 0.7
        case .text: baseFactor = 0.6
        case .parametricShape: baseFactor = 0.5
        }
        let frame = baseFactor * layer.scale
        var unitCenterX: CGFloat = 0
        var unitCenterY: CGFloat = 0
        var unitHalfW: CGFloat = 0.5
        var unitHalfH: CGFloat = 0.5
        if layer.kind == .image,
           let img = layer.image,
           img.size.width > 0, img.size.height > 0 {
            let aspect = img.size.width / img.size.height
            if aspect >= 1 {
                unitHalfH = 0.5 / aspect
            } else {
                unitHalfW = 0.5 * aspect
            }
        } else if layer.kind == .parametricShape, let spec = layer.shapeSpec {
            let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
            let path = spec.anyShape().path(in: unit)
            let pathRect = path.boundingRect
            if pathRect.width > 0, pathRect.height > 0 {
                unitCenterX = pathRect.midX - 0.5
                unitCenterY = pathRect.midY - 0.5
                unitHalfW = pathRect.width / 2
                unitHalfH = pathRect.height / 2
            }
        }
        if layer.isFlippedHorizontally { unitCenterX = -unitCenterX }
        if layer.isFlippedVertically { unitCenterY = -unitCenterY }
        let theta = CGFloat(layer.rotation.radians)
        let cosT = cos(theta)
        let sinT = sin(theta)
        let corners: [(CGFloat, CGFloat)] = [
            (unitCenterX - unitHalfW, unitCenterY - unitHalfH),
            (unitCenterX + unitHalfW, unitCenterY - unitHalfH),
            (unitCenterX - unitHalfW, unitCenterY + unitHalfH),
            (unitCenterX + unitHalfW, unitCenterY + unitHalfH)
        ]
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        for (x, y) in corners {
            let rx = x * cosT - y * sinT
            let ry = x * sinT + y * cosT
            minX = min(minX, rx)
            maxX = max(maxX, rx)
            minY = min(minY, ry)
            maxY = max(maxY, ry)
        }
        let width = (maxX - minX) * frame
        let height = (maxY - minY) * frame
        let centerOffsetX = (minX + maxX) / 2 * frame
        let centerOffsetY = (minY + maxY) / 2 * frame
        return CGRect(
            x: layer.offset.width + centerOffsetX - width / 2,
            y: layer.offset.height + centerOffsetY - height / 2,
            width: width,
            height: height
        )
    }

    private static func snappedToLayerGuides(
        translation: CGSize,
        draggedBounds: CGRect,
        others: [Layer],
        side: CGFloat
    ) -> (effective: CGSize, guides: [SnapGuide]) {
        guard side > 0 else { return (translation, []) }
        let threshold = objectSnapThreshold / side
        let dx = translation.width / side
        let dy = translation.height / side
        let candidate = draggedBounds.offsetBy(dx: dx, dy: dy)
        var xTargets: [(pos: CGFloat, source: CGRect, isLayerCenter: Bool)] = [
            (-0.5, CGRect(x: -0.5, y: -0.5, width: 0, height: 1), false),
            (0,    CGRect(x: 0,    y: -0.5, width: 0, height: 1), false),
            (0.5,  CGRect(x: 0.5,  y: -0.5, width: 0, height: 1), false)
        ]
        var yTargets: [(pos: CGFloat, source: CGRect, isLayerCenter: Bool)] = [
            (-0.5, CGRect(x: -0.5, y: -0.5, width: 1, height: 0), false),
            (0,    CGRect(x: -0.5, y: 0,    width: 1, height: 0), false),
            (0.5,  CGRect(x: -0.5, y: 0.5,  width: 1, height: 0), false)
        ]
        for other in others {
            let b = layerNormalizedBounds(other)
            xTargets.append((b.minX, b, false))
            xTargets.append((b.midX, b, true))
            xTargets.append((b.maxX, b, false))
            yTargets.append((b.minY, b, false))
            yTargets.append((b.midY, b, true))
            yTargets.append((b.maxY, b, false))
        }
        let candXs: [CGFloat] = [candidate.minX, candidate.midX, candidate.maxX]
        let candYs: [CGFloat] = [candidate.minY, candidate.midY, candidate.maxY]
        func bestSnap(
            candidates: [CGFloat],
            targets: [(pos: CGFloat, source: CGRect, isLayerCenter: Bool)]
        ) -> (delta: CGFloat, guideAt: CGFloat, source: CGRect)? {
            var best: (delta: CGFloat, guideAt: CGFloat, source: CGRect)?
            for c in candidates {
                for t in targets where !t.isLayerCenter {
                    let d = t.pos - c
                    if abs(d) < threshold,
                       best == nil || abs(d) < abs(best!.delta) {
                        best = (d, t.pos, t.source)
                    }
                }
            }
            if best != nil { return best }
            for c in candidates {
                for t in targets where t.isLayerCenter {
                    let d = t.pos - c
                    if abs(d) < threshold,
                       best == nil || abs(d) < abs(best!.delta) {
                        best = (d, t.pos, t.source)
                    }
                }
            }
            return best
        }
        let bestX = bestSnap(candidates: candXs, targets: xTargets)
        let bestY = bestSnap(candidates: candYs, targets: yTargets)
        var effective = translation
        var guides: [SnapGuide] = []
        if let bx = bestX {
            effective.width += bx.delta * side
            let yMin = min(candidate.minY, bx.source.minY)
            let yMax = max(candidate.maxY, bx.source.maxY)
            guides.append(SnapGuide(
                orientation: .vertical,
                position: bx.guideAt,
                extentStart: yMin,
                extentEnd: yMax
            ))
        }
        if let by = bestY {
            effective.height += by.delta * side
            let xMin = min(candidate.minX, by.source.minX)
            let xMax = max(candidate.maxX, by.source.maxX)
            guides.append(SnapGuide(
                orientation: .horizontal,
                position: by.guideAt,
                extentStart: xMin,
                extentEnd: xMax
            ))
        }
        return (effective, guides)
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
        Canvas { context, size in
            let active = GraphicsContext.Shading.color(Color.iaSelectionYellow)
            for guide in dragSnap.objectGuides {
                var path = Path()
                switch guide.orientation {
                case .vertical:
                    let x = size.width * (0.5 + guide.position)
                    let y1 = size.height * (0.5 + guide.extentStart)
                    let y2 = size.height * (0.5 + guide.extentEnd)
                    path.move(to: CGPoint(x: x, y: y1))
                    path.addLine(to: CGPoint(x: x, y: y2))
                case .horizontal:
                    let y = size.height * (0.5 + guide.position)
                    let x1 = size.width * (0.5 + guide.extentStart)
                    let x2 = size.width * (0.5 + guide.extentEnd)
                    path.move(to: CGPoint(x: x1, y: y))
                    path.addLine(to: CGPoint(x: x2, y: y))
                }
                context.stroke(path, with: active, lineWidth: 1.0)
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

    private func snapTargets() -> (draggedBounds: CGRect, others: [Layer])? {
        if session.isMultiSelecting {
            let ids = session.lassoSelectedLayerUUIDs
            let selected = project.layers.filter { !$0.isLocked && ids.contains($0.uuid) }
            guard !selected.isEmpty else { return nil }
            var union: CGRect = .null
            for l in selected { union = union.union(Self.layerNormalizedBounds(l)) }
            let others = project.layers.filter { !ids.contains($0.uuid) }
            return (union, others)
        }
        guard let layer = selectedOverlay, !layer.isLocked else { return nil }
        let bounds = Self.layerNormalizedBounds(layer)
        let others = project.layers.filter { $0.uuid != layer.uuid }
        return (bounds, others)
    }

    private func canvasGesture(side: CGFloat, canvasSize: CGSize) -> some Gesture {
        let drag = DragGesture()
            .updating($dragSnap) { value, state, _ in
                guard session.showGrid, let targets = snapTargets() else {
                    state.translation = value.translation
                    state.objectGuides = []
                    state.isActive = true
                    return
                }
                let result = Self.snappedToLayerGuides(
                    translation: value.translation,
                    draggedBounds: targets.draggedBounds,
                    others: targets.others,
                    side: side
                )
                let guidesEnter = !result.guides.isEmpty
                    && state.objectGuides.count != result.guides.count
                if guidesEnter {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                state.translation = result.effective
                state.objectGuides = result.guides
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
                    if session.showGrid, let targets = snapTargets() {
                        effective = Self.snappedToLayerGuides(
                            translation: value.translation,
                            draggedBounds: targets.draggedBounds,
                            others: targets.others,
                            side: side
                        ).effective
                    } else {
                        effective = value.translation
                    }
                    let dx = effective.width / side
                    let dy = effective.height / side
                    let ids = session.lassoSelectedLayerUUIDs
                    let movedLayers = project.layers.filter { ids.contains($0.uuid) }
                    guard !movedLayers.isEmpty else { return }
                    project.recordUndo()
                    for layer in movedLayers {
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
                if session.showGrid, let targets = snapTargets() {
                    effective = Self.snappedToLayerGuides(
                        translation: value.translation,
                        draggedBounds: targets.draggedBounds,
                        others: targets.others,
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

