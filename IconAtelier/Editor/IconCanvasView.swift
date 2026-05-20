import SwiftUI
import UIKit
import CoreText

struct IconCanvasView: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @GestureState private var dragSnap: DragSnapState = DragSnapState()
    @GestureState private var magnifySnap: MagnifySnapState = MagnifySnapState()
    @GestureState private var rotationSnap: RotationSnapState = RotationSnapState()
    @State private var didDragHitTest: Bool = false
    @State private var pendingDragEffective: CGSize = .zero
    @State private var pendingMagnifyEffective: CGFloat = 1.0

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
                scale: magnifySnap.scale,
                angle: rotationSnap.delta
            )
        }
        guard isInMultiDrag, let pivot else {
            return LayerTransient(offset: .zero, scale: 1, angle: .zero)
        }
        let m = magnifySnap.scale
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
            for guide in dragSnap.objectGuides + magnifySnap.objectGuides {
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

    private func snapTargets() -> (draggedBounds: CGRect, others: [Layer])? {
        if session.isMultiSelecting {
            let ids = session.lassoSelectedLayerUUIDs
            let selected = project.layers.filter { !$0.isLocked && ids.contains($0.uuid) }
            guard !selected.isEmpty else { return nil }
            var union: CGRect = .null
            for l in selected { union = union.union(CanvasSnapping.layerNormalizedBounds(l)) }
            let others = project.layers.filter { !ids.contains($0.uuid) }
            return (union, others)
        }
        guard let layer = selectedOverlay, !layer.isLocked else { return nil }
        let bounds = CanvasSnapping.layerNormalizedBounds(layer)
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
                let result = CanvasSnapping.snappedToLayerGuides(
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
                       let hit = CanvasHitTester.hitTestLayer(
                            in: project,
                            at: value.startLocation,
                            side: side,
                            canvasSize: canvasSize
                       ),
                       session.selectedLayerUUID != hit.uuid {
                        session.selectLayer(hit.uuid)
                    }
                }
                promoteOverlaySelection()
                if session.showGrid, let targets = snapTargets() {
                    pendingDragEffective = CanvasSnapping.snappedToLayerGuides(
                        translation: value.translation,
                        draggedBounds: targets.draggedBounds,
                        others: targets.others,
                        side: side
                    ).effective
                } else {
                    pendingDragEffective = value.translation
                }
            }
            .onEnded { _ in
                didDragHitTest = false
                let effective = pendingDragEffective
                pendingDragEffective = .zero
                guard side > 0,
                      effective.width.isFinite,
                      effective.height.isFinite
                else { return }
                if session.isMultiSelecting {
                    let dx = effective.width / side
                    let dy = effective.height / side
                    let ids = session.lassoSelectedLayerUUIDs
                    let movedLayers = project.layers.filter { ids.contains($0.uuid) }
                    guard !movedLayers.isEmpty else { return }
                    project.recordUndo()
                    project.mutateLayers(ids: ids) { layer in
                        let nx = layer.offset.width + dx
                        let ny = layer.offset.height + dy
                        guard nx.isFinite, ny.isFinite else { return }
                        layer.offset = CGSize(
                            width: min(max(nx, -0.5), 0.5),
                            height: min(max(ny, -0.5), 0.5)
                        )
                    }
                    return
                }
                guard let layer = selectedOverlay, !layer.isLocked else { return }
                project.recordUndo()
                let nextWidth = layer.offset.width + effective.width / side
                let nextHeight = layer.offset.height + effective.height / side
                guard nextWidth.isFinite, nextHeight.isFinite else { return }
                project.mutate(id: layer.uuid) {
                    $0.offset = CGSize(
                        width: min(max(nextWidth, -0.5), 0.5),
                        height: min(max(nextHeight, -0.5), 0.5)
                    )
                }
            }

        let magnify = MagnifyGesture(minimumScaleDelta: 0.01)
            .updating($magnifySnap) { value, state, _ in
                guard value.magnification.isFinite, value.magnification > 0 else { return }
                if session.showGrid,
                   !session.isMultiSelecting,
                   let layer = selectedOverlay,
                   !layer.isLocked {
                    let others = project.layers.filter { $0.uuid != layer.uuid }
                    let result = CanvasSnapping.snappedMagnification(
                        magnification: value.magnification,
                        layer: layer,
                        others: others,
                        side: side
                    )
                    let guidesEnter = !result.guides.isEmpty
                        && state.objectGuides.count != result.guides.count
                    if guidesEnter {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    state.scale = result.effective
                    state.objectGuides = result.guides
                } else {
                    state.scale = value.magnification
                    state.objectGuides = []
                }
            }
            .onChanged { value in
                promoteOverlaySelection()
                guard value.magnification.isFinite, value.magnification > 0 else { return }
                if session.showGrid,
                   !session.isMultiSelecting,
                   let layer = selectedOverlay,
                   !layer.isLocked {
                    let others = project.layers.filter { $0.uuid != layer.uuid }
                    pendingMagnifyEffective = CanvasSnapping.snappedMagnification(
                        magnification: value.magnification,
                        layer: layer,
                        others: others,
                        side: side
                    ).effective
                } else {
                    pendingMagnifyEffective = value.magnification
                }
            }
            .onEnded { _ in
                let effective = pendingMagnifyEffective
                pendingMagnifyEffective = 1.0
                guard effective.isFinite, effective > 0 else { return }
                if session.isMultiSelecting, let pivot = multiGroupCentroid() {
                    let m = effective
                    let ids = session.lassoSelectedLayerUUIDs
                    let targets = project.layers.filter { ids.contains($0.uuid) }
                    guard !targets.isEmpty else { return }
                    project.recordUndo()
                    project.mutateLayers(ids: ids) { layer in
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
                project.mutate(id: layer.uuid) {
                    $0.scale = max(0.1, $0.scale * effective)
                }
            }

        let rotate = RotateGesture(minimumAngleDelta: .degrees(1))
            .updating($rotationSnap) { value, state, _ in
                guard value.rotation.degrees.isFinite else { return }
                if session.isMultiSelecting {
                    let (delta, isSnapped) = CanvasSnapping.snappedRotationDelta(
                        rawDelta: value.rotation
                    )
                    guard delta.degrees.isFinite else { return }
                    if isSnapped && !state.isSnapped {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    state.delta = delta
                    state.isSnapped = isSnapped
                    return
                }
                guard let layer = selectedOverlay else {
                    state.delta = value.rotation
                    state.isSnapped = false
                    return
                }
                let (delta, isSnapped) = CanvasSnapping.snappedRotation(
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
                    let (snappedDelta, _) = CanvasSnapping.snappedRotationDelta(
                        rawDelta: value.rotation
                    )
                    guard snappedDelta.degrees.isFinite else { return }
                    let theta = CGFloat(snappedDelta.radians)
                    let ids = session.lassoSelectedLayerUUIDs
                    let targets = project.layers.filter { ids.contains($0.uuid) }
                    guard !targets.isEmpty else { return }
                    project.recordUndo()
                    project.mutateLayers(ids: ids) { layer in
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
                        layer.rotation = CanvasSnapping.normalized(layer.rotation + snappedDelta)
                    }
                    return
                }
                guard let layer = selectedOverlay, !layer.isLocked else { return }
                project.recordUndo()
                let (delta, _) = CanvasSnapping.snappedRotation(
                    layerRotation: layer.rotation,
                    rawDelta: value.rotation
                )
                guard delta.degrees.isFinite else { return }
                project.mutate(id: layer.uuid) {
                    $0.rotation = CanvasSnapping.normalized(layer.rotation + delta)
                }
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
        LayerView(
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
