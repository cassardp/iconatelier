import SwiftUI

struct ParametricShapeContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        PanelSection(title: "Shape") {
            ColorPickerRow(title: "Color", color: $layer.tintColor, onChange: { project.recordUndo() })
            if isPolygonFamily {
                polygonSliders
            } else if isStarFamily {
                starSliders
            } else if isEllipseFamily {
                ellipseSliders
            } else if isDropFamily {
                dropSliders
            }
            if isPolygonFamily || isStarFamily || isEllipseFamily || isDropFamily {
                stretchSliders
            }
            OpacitySlider(layer: layer, project: project)
        }

        SectionDivider()
        PanelSection(title: "Border") {
            BorderPanelContent(
                layer: layer,
                project: project,
                widthRange: 0 ... 0.5,
                widthDefault: BorderDefaults.shapeWidth,
                widthValueText: { String(format: "%.0f%%", $0 * 200) }
            )
        }

        SectionDivider()
        PanelSection(title: "Repeat") {
            RadialRepeatPanelContent(
                layer: layer,
                project: project,
                // Wrap the live parametric base when enabling, and unwrap
                // back to it (preserving the polygon) when disabling.
                wrapBase: { layer.shapeSpec ?? .defaultShape },
                disabledShapeSpec: { layer.shapeSpec?.unwrapped }
            )
        }
    }

    // True iOS-icon squircle is parameter-less by design — polygon sliders
    // hidden so the user can't drift away from the pixel-identical mask.
    private var isIosSquircle: Bool {
        if case .iosSquircle = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    // Boolean-op result: opaque path, no sides/roundness to tune. The
    // preset picker stays interactive so the user can opt out of the
    // result by tapping a normal preset tile.
    private var isCustomPath: Bool {
        if case .customPath = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isPolygonFamily: Bool {
        if case .polygon = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isStarFamily: Bool {
        if case .star = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isDropFamily: Bool {
        if case .drop = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isEllipseFamily: Bool {
        if case .ellipse = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    // MARK: - Family-specific sliders

    @ViewBuilder
    private var polygonSliders: some View {
        DialSliderRow(
            label: "Sides",
            value: polygonSidesBinding,
            range: 3 ... 24,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 4,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Roundness",
            value: polygonRoundnessBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private var starSliders: some View {
        DialSliderRow(
            label: "Points",
            value: starPointsBinding,
            range: 3 ... 24,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 5,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Inner Depth",
            value: starInnerDepthBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 50,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Roundness",
            value: starRoundnessBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private var ellipseSliders: some View {
        DialSliderRow(
            label: "Roundness",
            value: ellipseRoundnessBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 100,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private var dropSliders: some View {
        DialSliderRow(
            label: "Pointiness",
            value: dropBinding(\.pointiness, scale: 100),
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropShape.canonical.pointiness * 100,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Bulb Size",
            value: dropBinding(\.bulbSize, scale: 100),
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropShape.canonical.bulbSize * 100,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Tail Offset",
            value: dropBinding(\.tailOffset, scale: 100),
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropShape.canonical.tailOffset * 100,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Bend",
            value: dropBinding(\.bend, scale: 100),
            range: -100 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropShape.canonical.bend * 100,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private var stretchSliders: some View {
        DialSliderRow(
            label: "Stretch X",
            value: stretchBinding(\.stretchX),
            range: 0.3 ... 3,
            valueText: { String(format: "%.2f×", $0) },
            defaultValue: 1,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Stretch Y",
            value: stretchBinding(\.stretchY),
            range: 0.3 ... 3,
            valueText: { String(format: "%.2f×", $0) },
            defaultValue: 1,
            onBeginEditing: { project.recordUndo() }
        )
    }

    // MARK: - Polygon parameter plumbing

    private struct PolygonParams: Equatable {
        var preset: PolygonPreset
        var sides: Int
        var roundness: Double  // 0...1

        static let fallback = PolygonParams(
            preset: .square, sides: 4, roundness: 0
        )
    }

    private var currentPolygonParams: PolygonParams {
        if case let .polygon(preset, sides, roundness)
            = layer.shapeSpec?.deepestBase {
            return PolygonParams(preset: preset, sides: sides, roundness: roundness)
        }
        return .fallback
    }

    private func applyPolygonParams(_ p: PolygonParams) {
        let newBase = ShapeSpec.polygon(
            preset: p.preset, sides: p.sides, roundness: p.roundness
        )
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    private var polygonSidesBinding: Binding<Double> {
        Binding(
            get: { Double(currentPolygonParams.sides) },
            set: { newVal in
                var p = currentPolygonParams
                p.sides = max(3, min(24, Int(newVal.rounded())))
                p.preset = .free
                applyPolygonParams(p)
            }
        )
    }

    private var polygonRoundnessBinding: Binding<Double> {
        Binding(
            get: { currentPolygonParams.roundness * 100 },
            set: { newPercent in
                var p = currentPolygonParams
                p.roundness = min(1, max(0, newPercent / 100))
                p.preset = .free
                applyPolygonParams(p)
            }
        )
    }

    // MARK: - Star parameter plumbing

    private struct StarParams: Equatable {
        var preset: PolygonPreset
        var points: Int
        var innerDepth: Double  // 0...1
        var roundness: Double   // 0...1

        static let fallback = StarParams(
            preset: .star5, points: 5, innerDepth: 0.5, roundness: 0
        )
    }

    private var currentStarParams: StarParams {
        if case let .star(preset, points, innerDepth, roundness)
            = layer.shapeSpec?.deepestBase {
            return StarParams(
                preset: preset, points: points,
                innerDepth: innerDepth, roundness: roundness
            )
        }
        return .fallback
    }

    private func applyStarParams(_ p: StarParams) {
        let newBase = ShapeSpec.star(
            preset: p.preset, points: p.points,
            innerDepth: p.innerDepth, roundness: p.roundness
        )
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    private var starPointsBinding: Binding<Double> {
        Binding(
            get: { Double(currentStarParams.points) },
            set: { newVal in
                var p = currentStarParams
                p.points = max(3, min(24, Int(newVal.rounded())))
                p.preset = .free
                applyStarParams(p)
            }
        )
    }

    private var starInnerDepthBinding: Binding<Double> {
        Binding(
            get: { currentStarParams.innerDepth * 100 },
            set: { newPercent in
                var p = currentStarParams
                p.innerDepth = min(1, max(0, newPercent / 100))
                p.preset = .free
                applyStarParams(p)
            }
        )
    }

    private var starRoundnessBinding: Binding<Double> {
        Binding(
            get: { currentStarParams.roundness * 100 },
            set: { newPercent in
                var p = currentStarParams
                p.roundness = min(1, max(0, newPercent / 100))
                p.preset = .free
                applyStarParams(p)
            }
        )
    }

    // MARK: - Ellipse parameter plumbing

    private var currentEllipseRoundness: Double {
        if case let .ellipse(roundness) = layer.shapeSpec?.deepestBase {
            return roundness
        }
        return 1.0
    }

    private func applyEllipseRoundness(_ r: Double) {
        let newBase = ShapeSpec.ellipse(roundness: r)
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    private var ellipseRoundnessBinding: Binding<Double> {
        Binding(
            get: { currentEllipseRoundness * 100 },
            set: { newPercent in
                let clamped = min(1, max(0, newPercent / 100))
                applyEllipseRoundness(clamped)
            }
        )
    }

    // MARK: - Drop parameter plumbing

    private var currentDropParams: DropParams {
        if case let .drop(pointiness, bulbSize, tailOffset, bend)
            = layer.shapeSpec?.deepestBase {
            return DropParams(
                pointiness: pointiness, bulbSize: bulbSize,
                tailOffset: tailOffset, bend: bend
            )
        }
        return DropShape.canonical
    }

    private func applyDropParams(_ p: DropParams) {
        let newBase = ShapeSpec.drop(
            pointiness: p.pointiness, bulbSize: p.bulbSize,
            tailOffset: p.tailOffset, bend: p.bend
        )
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    /// All four drop sliders share the same shape: read a Double through a
    /// keyPath, scale it for the UI (×100 → percent), clamp on write.
    /// `pointiness`, `bulbSize`, `tailOffset` clamp to 0...1; `bend` to -1...1
    /// — detected from the slider's symmetric vs asymmetric range upstream
    /// (the binding just clamps to the natural domain of the keyPath value).
    private func dropBinding(
        _ keyPath: WritableKeyPath<DropParams, Double>,
        scale: Double
    ) -> Binding<Double> {
        Binding(
            get: { currentDropParams[keyPath: keyPath] * scale },
            set: { newScaled in
                var p = currentDropParams
                let raw = newScaled / scale
                // `bend` is the only param with a signed domain — everything
                // else is 0...1. Clamp accordingly so the slider can't push
                // pointiness/bulbSize/tailOffset negative.
                if keyPath == \DropParams.bend {
                    p[keyPath: keyPath] = max(-1, min(1, raw))
                } else {
                    p[keyPath: keyPath] = max(0, min(1, raw))
                }
                applyDropParams(p)
            }
        )
    }

    // MARK: - Transform plumbing (shared between polygon, star, and drop)

    /// Live transform params from the layer's `.transform` wrapper. Returns
    /// identity when no wrapper is present — slider getters read this and
    /// setters wrap/unwrap the spec via `applyingTransform`.
    private var currentTransform: TransformParams {
        layer.shapeSpec?.transformParams ?? ShapeSpec.identityTransform
    }

    private func applyTransform(_ t: TransformParams) {
        let spec = layer.shapeSpec ?? .defaultShape
        layer.shapeSpec = spec.applyingTransform(t)
    }

    // StretchX/StretchY live on the `.transform` wrapper, which is added
    // on the fly when a slider first leaves identity and stripped back
    // when both axes return to 1 (handled by `applyingTransform`).
    private func stretchBinding(
        _ keyPath: WritableKeyPath<TransformParams, Double>
    ) -> Binding<Double> {
        Binding(
            get: { currentTransform[keyPath: keyPath] },
            set: { newVal in
                var t = currentTransform
                t[keyPath: keyPath] = max(0.3, min(3, newVal))
                applyTransform(t)
            }
        )
    }
}

