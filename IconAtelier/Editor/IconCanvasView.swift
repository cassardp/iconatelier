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

    /// Centroid of the lasso-selected layers' offsets, used as the pivot for
    /// group pinch and rotate. Returns nil when there's no multi-selection.
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

    /// Computes the transient (in-flight) transform applied to a layer's
    /// rendering. For a single selection it just forwards the gesture state.
    /// For a multi-selection it rotates/scales each layer's position around
    /// the group pivot so the group transforms as a rigid body.
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
            centerGuides(side: side)
        }
        .frame(width: side, height: side)
        .clipShape(SquircleShape())
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
                if session.isMultiSelecting {
                    // Group drag: translate every lasso-selected layer in
                    // lockstep. Snap-to-center is intentionally disabled —
                    // there is no single anchor to snap on a group.
                    state.translation = value.translation
                    state.axes = []
                    state.isActive = true
                    return
                }
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
                layer.scale = max(0.1, layer.scale * value.magnification)
            }

        let rotate = RotateGesture(minimumAngleDelta: .degrees(1))
            .updating($rotationSnap) { value, state, _ in
                guard value.rotation.degrees.isFinite else { return }
                if session.isMultiSelecting {
                    // 90° snap doesn't really fit a group — skip it and let
                    // the user rotate freely.
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
        // No `.contentShape(Rectangle())` here on purpose — LayerContentView
        // sets a per-kind content shape (the actual Path for parametric
        // shapes, Rectangle for image/emoji/text) so taps on transparent
        // areas of a star or polygon no longer select the layer.
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
            // Render the text as a glyph-derived Path so it plugs into the
            // same fill + stroke + radial-repeat pipeline as parametric
            // shapes. The optional radial-repeat is read from
            // `layer.shapeSpec` — for text layers only the wrap's params
            // matter, the base is ignored (the glyph path is the base).
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
            // Same path-aware hit-testing as parametric shapes: taps in the
            // negative space of a glyph (or between repeated copies) fall
            // through instead of selecting the text layer.
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
                            // Open paths can't use .inner / .outer — those
                            // clip / punch-out via the shape's fill, which
                            // implicitly closes the arc and chops off the
                            // stroke endpoints. Force .center so caps stay
                            // intact.
                            color: layer.borderColor,
                            position: spec.isOpenPath ? .center : layer.borderPosition,
                            lineCap: layer.lineCap.cgLineCap
                        )
                    }
                }
                .frame(width: shapeSide, height: shapeSide)
                // Precise hit-testing via Path.contains for closed paths.
                // Open paths (e.g. partial-arc ellipse) can't be hit-tested
                // that way, so fall back to a Rectangle content shape.
                .contentShape(spec.isOpenPath ? AnyShape(Rectangle()) : shape)
            } else {
                Color.clear
                    .frame(width: shapeSide, height: shapeSide)
                    .contentShape(Rectangle())
            }
        }
    }

    // Three border positions:
    //  - .center: SwiftUI's default stroke, centered on the path. Bleeds inward
    //    and outward; self-intersects on concave shapes at large widths.
    //  - .inner:  doubled stroke clipped to the shape's interior. Effective
    //    width = `width`, fully inside, no overflow.
    //  - .outer:  doubled stroke with the shape's interior punched out via
    //    `destinationOut`. Effective width = `width`, fully outside.
    //
    // `lineCap` is the user-selected cap — visible only on open paths
    // (partial arcs). Closed loops join back into themselves so cap style
    // is invisible there.
    @ViewBuilder
    private func borderView(shape: AnyShape, width: CGFloat, color: Color, position: BorderPosition, lineCap: CGLineCap) -> some View {
        // Use rounded joins everywhere — at large render sizes the default
        // .miter join produces long spikes wherever a glyph or path has an
        // acute angle. Invisible on a 56pt thumbnail, very visible at full
        // canvas size as a stray "tail" outside the shape.
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
