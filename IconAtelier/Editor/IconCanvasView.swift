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
    @State private var didDragHitTest: Bool = false

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
        let visual = visualHalfSize(layer)
        let baseHalf = max(visual.width, visual.height)
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

    private static func visualHalfSize(_ layer: Layer) -> CGSize {
        let frameFactor: CGFloat
        switch layer.kind {
        case .image: frameFactor = 0.7
        case .text: frameFactor = 0.6
        case .parametricShape: frameFactor = 0.5
        }
        let frameHalf = frameFactor * layer.scale / 2

        switch layer.kind {
        case .text:
            return CGSize(width: frameHalf, height: frameHalf)
        case .parametricShape:
            guard let spec = layer.shapeSpec, !spec.isOpenPath else {
                return CGSize(width: frameHalf, height: frameHalf)
            }
            let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
            let bbox = spec.anyShape().path(in: unit).boundingRect
            guard bbox.width > 0, bbox.height > 0 else {
                return CGSize(width: frameHalf, height: frameHalf)
            }
            let hw = max(0.5 - bbox.minX, bbox.maxX - 0.5)
            let hh = max(0.5 - bbox.minY, bbox.maxY - 0.5)
            let span = frameHalf * 2
            return CGSize(width: hw * span, height: hh * span)
        case .image:
            guard let img = layer.image, let cg = img.cgImage else {
                return CGSize(width: frameHalf, height: frameHalf)
            }
            let w = CGFloat(cg.width)
            let h = CGFloat(cg.height)
            guard w > 0, h > 0 else { return CGSize(width: frameHalf, height: frameHalf) }
            let frameSide = frameHalf * 2
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
            let bbox = opaqueUnitBounds(of: img)
            let hw = max(0.5 - bbox.minX, bbox.maxX - 0.5)
            let hh = max(0.5 - bbox.minY, bbox.maxY - 0.5)
            return CGSize(width: hw * renderedW, height: hh * renderedH)
        }
    }

    private static let opaqueBoundsCache = NSCache<UIImage, NSValue>()

    private static func opaqueUnitBounds(of image: UIImage) -> CGRect {
        if let cached = opaqueBoundsCache.object(forKey: image) {
            return cached.cgRectValue
        }
        let fallback = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard let cg = image.cgImage else { return fallback }
        let maxDim: CGFloat = 96
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        guard w > 0, h > 0 else { return fallback }
        let scale = min(1, maxDim / max(w, h))
        let sw = max(1, Int(w * scale))
        let sh = max(1, Int(h * scale))
        var bytes = [UInt8](repeating: 0, count: sw * sh * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &bytes,
            width: sw,
            height: sh,
            bitsPerComponent: 8,
            bytesPerRow: sw * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return fallback }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: sw, height: sh))
        var minX = sw, minY = sh, maxX = -1, maxY = -1
        let threshold: UInt8 = 12
        for y in 0..<sh {
            let rowBase = y * sw * 4
            for x in 0..<sw {
                if bytes[rowBase + x * 4 + 3] > threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        let rect: CGRect
        if maxX >= 0 {
            rect = CGRect(
                x: CGFloat(minX) / CGFloat(sw),
                y: CGFloat(minY) / CGFloat(sh),
                width: CGFloat(maxX - minX + 1) / CGFloat(sw),
                height: CGFloat(maxY - minY + 1) / CGFloat(sh)
            )
        } else {
            rect = fallback
        }
        opaqueBoundsCache.setObject(NSValue(cgRect: rect), forKey: image)
        return rect
    }

    private static func snappedToGrid(
        translation: CGSize,
        layerOffset: CGSize,
        layerHalfSize: CGSize,
        side: CGFloat,
        centerOnly: Bool = false
    ) -> (effective: CGSize, snappedLinesX: Set<Int>, snappedLinesY: Set<Int>) {
        guard side > 0 else { return (translation, [], []) }
        let thresholdFraction = gridSnapThreshold / side
        let matchTolerance: CGFloat = 0.001
        let centerX = layerOffset.width + translation.width / side
        let centerY = layerOffset.height + translation.height / side
        let activeOffsets: [CGFloat] = centerOnly ? [0] : gridOffsets

        func bestTarget(currentCenter: CGFloat, half: CGFloat) -> CGFloat? {
            var best: (target: CGFloat, dist: CGFloat)?
            for line in activeOffsets {
                let candidates: [CGFloat] = centerOnly
                    ? [line]
                    : [line, line - half, line + half]
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

        func touchedLines(center: CGFloat, half: CGFloat) -> Set<Int> {
            var lines: Set<Int> = []
            for (idx, line) in gridOffsets.enumerated() {
                let centerHit = abs(line - center) < matchTolerance
                let edgeHit = !centerOnly && (
                    abs(line - (center - half)) < matchTolerance
                    || abs(line - (center + half)) < matchTolerance
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
        if let targetX = bestTarget(currentCenter: centerX, half: layerHalfSize.width) {
            effective.width = (targetX - layerOffset.width) * side
            snappedLinesX = touchedLines(center: targetX, half: layerHalfSize.width)
        }
        if let targetY = bestTarget(currentCenter: centerY, half: layerHalfSize.height) {
            effective.height = (targetY - layerOffset.height) * side
            snappedLinesY = touchedLines(center: targetY, half: layerHalfSize.height)
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

    private func hitTestLayer(at point: CGPoint, side: CGFloat, canvasSize: CGSize) -> Layer? {
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        for layer in project.layers.reversed() {
            guard !layer.isHidden else { continue }
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
                if session.isMultiSelecting {
                    guard let pivot = multiGroupCentroid() else {
                        state.translation = value.translation
                        state.isActive = true
                        return
                    }
                    let result = Self.snappedToGrid(
                        translation: value.translation,
                        layerOffset: pivot,
                        layerHalfSize: .zero,
                        side: side,
                        centerOnly: true
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
                    layerHalfSize: Self.visualHalfSize(layer),
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
                    if let pivot = multiGroupCentroid() {
                        effective = Self.snappedToGrid(
                            translation: value.translation,
                            layerOffset: pivot,
                            layerHalfSize: .zero,
                            side: side,
                            centerOnly: true
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
                guard let layer = selectedOverlay else { return }
                project.recordUndo()
                let effective = Self.snappedToGrid(
                    translation: value.translation,
                    layerOffset: layer.offset,
                    layerHalfSize: Self.visualHalfSize(layer),
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

