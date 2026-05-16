import SwiftUI

// MARK: - Per-kind content sections

struct ImageContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        PanelSection(title: "Color") {
            ColorPickerRow(title: "Tint", color: $layer.tintColor, project: project)
            OpacitySlider(layer: layer, project: project)
        }
    }
}

struct ParametricShapeContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        PanelSection(title: "Preset") {
            PresetPickerRow(
                selectedPreset: selectedPreset,
                onSelect: { preset in
                    project.recordUndo()
                    let newBase = ShapeSpec.preset(preset)
                    layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
                        .replacingBase(with: newBase)
                }
            )
        }

        SectionDivider()
        PanelSection(title: "Shape") {
            ColorPickerRow(title: "Color", color: $layer.tintColor, project: project)
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
        PanelSection(title: "Border", defaultExpanded: false) {
            DialSliderRow(
                label: "Width",
                value: $layer.borderWidth,
                range: 0 ... 0.5,
                valueText: { String(format: "%.0f%%", $0 * 200) },
                defaultValue: 0,
                onBeginEditing: { project.recordUndo() }
            )
            BorderPositionRow(position: $layer.borderPosition, project: project)
            ColorPickerRow(title: "Color", color: $layer.borderColor, project: project)
        }

        SectionDivider()
        PanelSection(title: "Repeat", defaultExpanded: false) {
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

    // Picker selection. iosSquircle maps back to the .squircle tile;
    // polygon/star/drop surface their stored preset for tile highlighting.
    // Boolean-op results land in `.customPath` and have no matching tile,
    // so they surface as the inert `.free` selection.
    private var selectedPreset: PolygonPreset {
        switch layer.shapeSpec?.deepestBase {
        case .iosSquircle: return .squircle
        case .customPath: return .free
        case .polygon(let preset, _, _): return preset
        case .star(let preset, _, _, _): return preset
        case .ellipse: return .circle
        case .drop: return .drop
        default: return .free
        }
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

// MARK: - Reusable radial-repeat panel content

/// Toggle + 4 sliders for the radial-repeat wrap, driven through
/// `layer.shapeSpec`. Used by both parametric shapes (where the spec also
/// carries the base polygon) and text layers (where the base is a sentinel
/// — only the repeat params matter; the actual base is the live
/// `TextGlyphShape` at render time).
///
/// `wrapBase` provides the base to wrap when enabling the toggle.
/// `disabledShapeSpec` decides what `shapeSpec` becomes when disabling —
/// for parametric shapes it returns the unwrapped polygon; for text it
/// returns nil so the layer goes back to "no spec at all".
struct RadialRepeatPanelContent: View {
    @Bindable var layer: Layer
    let project: IconProject
    let wrapBase: () -> ShapeSpec
    let disabledShapeSpec: () -> ShapeSpec?

    var body: some View {
        repeatToggleRow
        if layer.shapeSpec?.radialRepeatParams != nil {
            sliders
        }
    }

    private var repeatToggleRow: some View {
        let isOn = layer.shapeSpec?.radialRepeatParams != nil
        return HStack(spacing: 8) {
            Text("Apply")
                .foregroundStyle(.primary.opacity(0.72))
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newVal in toggleRepeat(to: newVal) }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, PanelStyle.rowInsetH)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }

    @ViewBuilder
    private var sliders: some View {
        DialSliderRow(
            label: "Count",
            value: doubleBinding(
                get: { Double($0.count) },
                set: { p, v in var p = p; p.count = Int(v.rounded()); return p }
            ),
            range: 2 ... 24,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: Double(ShapeSpec.defaultRadialRepeat.count),
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Center Hole",
            value: doubleBinding(
                get: { $0.centerHole },
                set: { p, v in var p = p; p.centerHole = v; return p }
            ),
            range: -0.5 ... 0.5,
            valueText: { String(format: "%.0f%%", $0 * 200) },
            defaultValue: ShapeSpec.defaultRadialRepeat.centerHole,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Phase",
            value: doubleBinding(
                get: { $0.phaseDegrees },
                set: { p, v in var p = p; p.phaseDegrees = v; return p }
            ),
            range: -180 ... 180,
            valueText: { String(format: "%.0f°", $0) },
            defaultValue: ShapeSpec.defaultRadialRepeat.phaseDegrees,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Alternate",
            value: doubleBinding(
                get: { $0.alternateScale },
                set: { p, v in var p = p; p.alternateScale = v; return p }
            ),
            range: 0.2 ... 1.0,
            valueText: { String(format: "%.2f", $0) },
            defaultValue: ShapeSpec.defaultRadialRepeat.alternateScale,
            onBeginEditing: { project.recordUndo() }
        )
    }

    private func toggleRepeat(to enable: Bool) {
        project.recordUndo()
        if enable {
            let base = layer.shapeSpec ?? wrapBase()
            layer.shapeSpec = base.wrappingInRadialRepeat(ShapeSpec.defaultRadialRepeat)
        } else {
            layer.shapeSpec = disabledShapeSpec()
        }
    }

    private func doubleBinding(
        get: @escaping (RadialRepeatParams) -> Double,
        set: @escaping (RadialRepeatParams, Double) -> RadialRepeatParams
    ) -> Binding<Double> {
        Binding(
            get: {
                layer.shapeSpec?.radialRepeatParams.map(get) ?? 0
            },
            set: { newVal in
                guard let spec = layer.shapeSpec,
                      let params = spec.radialRepeatParams else { return }
                let updated = set(params, newVal)
                layer.shapeSpec = spec.wrappingInRadialRepeat(updated)
            }
        )
    }
}

struct EmojiContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    @FocusState private var emojiFocused: Bool

    var body: some View {
        PanelSection(title: "Emoji") {
            ContentField(
                placeholder: "Tap and pick an emoji",
                text: $layer.emoji,
                focused: $emojiFocused,
                project: project
            )
            OpacitySlider(layer: layer, project: project)
        }
    }
}

struct TextContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    @FocusState private var textFocused: Bool

    var body: some View {
        PanelSection(title: "Preset") {
            FontPresetPickerRow(
                selected: layer.fontDesign,
                onSelect: { design in
                    project.recordUndo()
                    layer.fontDesign = design
                }
            )
        }

        SectionDivider()
        PanelSection(title: "Text") {
            ContentField(
                placeholder: "Text",
                text: $layer.text,
                focused: $textFocused,
                project: project
            )
            ColorPickerRow(title: "Color", color: $layer.tintColor, project: project)
            FontWeightRow(weight: $layer.fontWeight, project: project)
            OpacitySlider(layer: layer, project: project)
        }

        SectionDivider()
        PanelSection(title: "Border", defaultExpanded: false) {
            DialSliderRow(
                label: "Width",
                value: $layer.borderWidth,
                range: 0 ... 0.2,
                valueText: { String(format: "%.0f%%", $0 * 500) },
                defaultValue: 0,
                onBeginEditing: { project.recordUndo() }
            )
            BorderPositionRow(position: $layer.borderPosition, project: project)
            ColorPickerRow(title: "Color", color: $layer.borderColor, project: project)
        }

        SectionDivider()
        PanelSection(title: "Repeat", defaultExpanded: false) {
            RadialRepeatPanelContent(
                layer: layer,
                project: project,
                // Text layers don't actually carry a parametric base — the
                // glyph path itself becomes the base at render time. We
                // still need a non-nil ShapeSpec to hang the radial-repeat
                // params on; iosSquircle is used as an inert sentinel.
                wrapBase: { .iosSquircle },
                disabledShapeSpec: { nil }
            )
        }
    }
}

// MARK: - Reusable content rows

private struct ContentField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let project: IconProject

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused(focused)
            .padding(.horizontal, PanelStyle.rowInsetH)
            .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                    .fill(PanelStyle.rowFill)
            )
            .onChange(of: focused.wrappedValue) { _, newValue in
                if newValue { project.recordUndo() }
            }
    }
}

struct ColorPickerRow: View {
    let title: String
    @Binding var color: Color
    let project: IconProject

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.primary.opacity(0.72))
            Spacer()
            ColorPicker(
                "",
                selection: Binding(
                    get: { color },
                    set: {
                        project.recordUndo()
                        color = $0
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
        }
        .padding(.horizontal, PanelStyle.rowInsetH)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }
}

// MARK: - Shape preset picker

private struct PresetPickerRow: View {
    let selectedPreset: PolygonPreset
    let onSelect: (PolygonPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(PolygonPreset.pickerOrder, id: \.self) { preset in
                    PresetTile(
                        preset: preset,
                        isSelected: preset == selectedPreset,
                        action: { onSelect(preset) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 72)
    }
}

private struct PresetTile: View {
    let preset: PolygonPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            Group {
                // Each tile must render exactly what tapping it produces.
                // Squircle uses the true Lamé curve; drop/shield use their
                // built-in custom paths; everything else falls through to
                // the canonical StarPolygonShape parameter cell.
                switch preset {
                case .squircle:
                    SquircleShape().fill(Color.primary)
                case .circle:
                    SuperellipseShape(roundness: 1.0).fill(Color.primary)
                case .drop:
                    DropShape(
                        pointiness: DropShape.canonical.pointiness,
                        bulbSize: DropShape.canonical.bulbSize,
                        tailOffset: DropShape.canonical.tailOffset,
                        bend: DropShape.canonical.bend
                    ).fill(Color.primary)
                default:
                    preset.canonical.fill(Color.primary)
                }
            }
            .frame(width: 40, height: 40)
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                    .fill(isSelected ? PanelStyle.rowFillActive : PanelStyle.rowFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.primary.opacity(0.6) : .clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.displayName)
    }
}

private struct BorderPositionRow: View {
    @Binding var position: BorderPosition
    let project: IconProject

    var body: some View {
        HStack(spacing: 10) {
            Text("Position")
                .foregroundStyle(.primary.opacity(0.72))
            Spacer()
            Picker("Position", selection: Binding(
                get: { position },
                set: {
                    project.recordUndo()
                    position = $0
                }
            )) {
                ForEach(BorderPosition.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .labelsHidden()
        }
        .padding(.horizontal, PanelStyle.rowInsetH)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }
}

// MARK: - Font preset picker

private struct FontPresetPickerRow: View {
    let selected: LayerFontDesign
    let onSelect: (LayerFontDesign) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(LayerFontDesign.allCases, id: \.self) { design in
                    FontPresetTile(
                        design: design,
                        isSelected: design == selected,
                        action: { onSelect(design) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 72)
    }
}

private struct FontPresetTile: View {
    let design: LayerFontDesign
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            FontPresetLabel(design: design)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                        .fill(isSelected ? PanelStyle.rowFillActive : PanelStyle.rowFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.primary.opacity(0.6) : .clear,
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(design.displayName)
    }
}

private struct FontPresetLabel: UIViewRepresentable {
    let design: LayerFontDesign

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = "Ag"
        label.textAlignment = .center
        label.textColor = .label
        label.adjustsFontForContentSizeCategory = false
        configure(label)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        configure(uiView)
    }

    private func configure(_ label: UILabel) {
        let base = UIFont.systemFont(ofSize: 28, weight: .semibold)
        let uiDesign: UIFontDescriptor.SystemDesign
        switch design {
        case .default:    uiDesign = .default
        case .serif:      uiDesign = .serif
        case .rounded:    uiDesign = .rounded
        case .monospaced: uiDesign = .monospaced
        }
        if let descriptor = base.fontDescriptor.withDesign(uiDesign) {
            label.font = UIFont(descriptor: descriptor, size: 28)
        } else {
            label.font = base
        }
    }
}

private struct FontWeightRow: View {
    @Binding var weight: LayerFontWeight
    let project: IconProject

    var body: some View {
        HStack(spacing: 10) {
            Text("Weight")
                .foregroundStyle(.primary.opacity(0.72))
            Spacer()
            Picker("Weight", selection: Binding(
                get: { weight },
                set: {
                    project.recordUndo()
                    weight = $0
                }
            )) {
                Text("Reg").tag(LayerFontWeight.regular)
                Text("Med").tag(LayerFontWeight.medium)
                Text("Semi").tag(LayerFontWeight.semibold)
                Text("Bold").tag(LayerFontWeight.bold)
                Text("Heavy").tag(LayerFontWeight.heavy)
            }
            .pickerStyle(.menu)
            .tint(.primary.opacity(0.72))
            .labelsHidden()
        }
        .padding(.horizontal, PanelStyle.rowInsetH)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }
}
