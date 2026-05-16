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
            if !isIosSquircle {
                parameterSliders
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

    // True iOS-icon squircle is parameter-less by design — sliders are
    // hidden so the user can't drift away from the pixel-identical mask.
    private var isIosSquircle: Bool {
        if case .iosSquircle = layer.shapeSpec?.unwrapped { return true }
        return false
    }

    // Picker selection. The iosSquircle case maps back to the .squircle
    // preset so its tile is highlighted in the picker.
    private var selectedPreset: PolygonPreset {
        if case .iosSquircle = layer.shapeSpec?.unwrapped { return .squircle }
        return currentParams.preset
    }

    @ViewBuilder
    private var parameterSliders: some View {
        DialSliderRow(
            label: "Sides",
            value: sidesBinding,
            range: 2 ... 24,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 4,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Bulge",
            value: bulgeBinding,
            range: -100 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Roundness",
            value: percentBinding(\.roundness),
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
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

    // Mirror of the .polygon case payload — lets the editor read/write each
    // parameter independently without re-pattern-matching everywhere.
    private struct PolygonParams: Equatable {
        var preset: PolygonPreset
        var sides: Int
        var bulge: Double      // -1...+1
        var roundness: Double  // 0...1
        var stretchX: Double   // 0.3...3
        var stretchY: Double
        var rotation: Double   // degrees

        static let fallback = PolygonParams(
            preset: .squircle,
            sides: 4, bulge: 0, roundness: 0.6,
            stretchX: 1, stretchY: 1, rotation: 45
        )
    }

    private var currentParams: PolygonParams {
        if case let .polygon(preset, sides, bulge, roundness, sx, sy, rotation)
            = layer.shapeSpec?.unwrapped {
            return PolygonParams(
                preset: preset,
                sides: sides,
                bulge: bulge,
                roundness: roundness,
                stretchX: sx,
                stretchY: sy,
                rotation: rotation
            )
        }
        return .fallback
    }

    private func applyParams(_ p: PolygonParams) {
        let newBase = ShapeSpec.polygon(
            preset: p.preset,
            sides: p.sides,
            bulge: p.bulge,
            roundness: p.roundness,
            stretchX: p.stretchX,
            stretchY: p.stretchY,
            rotation: p.rotation
        )
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    private var sidesBinding: Binding<Double> {
        Binding(
            get: { Double(currentParams.sides) },
            set: { newVal in
                var p = currentParams
                p.sides = max(2, min(24, Int(newVal.rounded())))
                p.preset = .free
                applyParams(p)
            }
        )
    }

    // Roundness is stored as 0...1 but exposed as 0–100. Anything that
    // touches geometry flips the preset to `.free`.
    private func percentBinding(
        _ keyPath: WritableKeyPath<PolygonParams, Double>
    ) -> Binding<Double> {
        Binding(
            get: { currentParams[keyPath: keyPath] * 100 },
            set: { newPercent in
                var p = currentParams
                p[keyPath: keyPath] = min(1, max(0, newPercent / 100))
                p.preset = .free
                applyParams(p)
            }
        )
    }

    // Bulge is stored as -1...+1 but exposed as -100...+100 so the dial
    // reads symmetrically around zero (negative = star/pinch, positive =
    // puff toward 2N-gon). Same preset-invalidation contract as the rest.
    private var bulgeBinding: Binding<Double> {
        Binding(
            get: { currentParams.bulge * 100 },
            set: { newPercent in
                var p = currentParams
                p.bulge = min(1, max(-1, newPercent / 100))
                p.preset = .free
                applyParams(p)
            }
        )
    }

    // StretchX/StretchY are stored as a multiplier around 1.0. The slider
    // exposes the same value range directly so the label reads as "1.0×".
    private func stretchBinding(
        _ keyPath: WritableKeyPath<PolygonParams, Double>
    ) -> Binding<Double> {
        Binding(
            get: { currentParams[keyPath: keyPath] },
            set: { newVal in
                var p = currentParams
                p[keyPath: keyPath] = max(0.3, min(3, newVal))
                p.preset = .free
                applyParams(p)
            }
        )
    }

    // MARK: - Helpers
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
                // The Squircle tile must render the true Lamé curve
                // (same as the iOS-icon mask), not a fillet-approximated
                // PolygonShape — otherwise the thumb wouldn't match
                // what the user actually gets on tap.
                if preset == .squircle {
                    SquircleShape()
                        .fill(Color.primary)
                } else {
                    preset.canonical
                        .fill(Color.primary)
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
