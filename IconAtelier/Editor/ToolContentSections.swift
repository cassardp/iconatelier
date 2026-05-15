import SwiftUI
import SFSymbols

// MARK: - Per-kind content sections

struct SymbolContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    @State private var showSymbolPicker = false

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { layer.symbolName.isEmpty ? nil : layer.symbolName },
            set: { newValue in
                guard let newValue, newValue != layer.symbolName else { return }
                project.recordUndo()
                layer.symbolName = newValue
                showSymbolPicker = false
            }
        )
    }

    var body: some View {
        PanelSection(title: "Symbol") {
            SymbolPickerRow(symbol: $layer.symbolName, isPresented: $showSymbolPicker)
            ColorPickerRow(title: "Color", color: $layer.tintColor, project: project)
            FontWeightRow(weight: $layer.fontWeight, project: project)
        }
        .sfSymbolPicker(isPresented: $showSymbolPicker, selection: selectionBinding)
    }
}

private struct SymbolPickerRow: View {
    @Binding var symbol: String
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol.isEmpty ? "questionmark.square.dashed" : symbol)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 28, alignment: .center)
                Text(symbol.isEmpty ? "Pick a symbol" : symbol)
                    .foregroundStyle(.primary.opacity(0.72))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                    .fill(PanelStyle.rowFill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AIOverlayContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        PanelSection(title: "Color") {
            ColorPickerRow(title: "Tint", color: $layer.tintColor, project: project)
        }
    }
}

struct ParametricShapeContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        PanelSection(title: layer.shapeSpec?.displayName ?? "Shape") {
            baseShapeSliders
            ColorPickerRow(title: "Color", color: $layer.tintColor, project: project)
        }

        SectionDivider()
        PanelSection(title: "Repeat") {
            repeatToggleRow
            if layer.shapeSpec?.radialRepeatParams != nil {
                radialRepeatSliders
            }
        }
    }

    // Base shape sliders read/write the unwrapped base, preserving the radial
    // wrap if the layer is currently repeated.
    @ViewBuilder
    private var baseShapeSliders: some View {
        switch layer.shapeSpec?.unwrapped {
        case .polygon:
            DialSliderRow(
                label: "Sides",
                value: baseDoubleBinding(
                    get: { spec in
                        if case .polygon(let s, _) = spec { return Double(s) }
                        return 6
                    },
                    set: { spec, v in
                        if case .polygon(_, let r) = spec {
                            return .polygon(sides: Int(v.rounded()), rotation: r)
                        }
                        return spec
                    }
                ),
                range: 3 ... 12,
                valueText: { "\(Int($0.rounded()))" },
                defaultValue: 6,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Rotation",
                value: baseDoubleBinding(
                    get: { spec in
                        if case .polygon(_, let r) = spec { return r }
                        return -90
                    },
                    set: { spec, v in
                        if case .polygon(let s, _) = spec {
                            return .polygon(sides: s, rotation: v)
                        }
                        return spec
                    }
                ),
                range: -180 ... 180,
                valueText: { String(format: "%.0f°", $0) },
                defaultValue: -90,
                onBeginEditing: { project.recordUndo() }
            )

        case .star:
            DialSliderRow(
                label: "Points",
                value: baseDoubleBinding(
                    get: { spec in
                        if case .star(let p, _, _) = spec { return Double(p) }
                        return 5
                    },
                    set: { spec, v in
                        if case .star(_, let ir, let r) = spec {
                            return .star(points: Int(v.rounded()), innerRatio: ir, rotation: r)
                        }
                        return spec
                    }
                ),
                range: 3 ... 12,
                valueText: { "\(Int($0.rounded()))" },
                defaultValue: 5,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Inner Ratio",
                value: baseDoubleBinding(
                    get: { spec in
                        if case .star(_, let ir, _) = spec { return ir }
                        return 0.5
                    },
                    set: { spec, v in
                        if case .star(let p, _, let r) = spec {
                            return .star(points: p, innerRatio: v, rotation: r)
                        }
                        return spec
                    }
                ),
                range: 0.1 ... 0.9,
                valueText: { String(format: "%.2f", $0) },
                defaultValue: 0.5,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Rotation",
                value: baseDoubleBinding(
                    get: { spec in
                        if case .star(_, _, let r) = spec { return r }
                        return -90
                    },
                    set: { spec, v in
                        if case .star(let p, let ir, _) = spec {
                            return .star(points: p, innerRatio: ir, rotation: v)
                        }
                        return spec
                    }
                ),
                range: -180 ... 180,
                valueText: { String(format: "%.0f°", $0) },
                defaultValue: -90,
                onBeginEditing: { project.recordUndo() }
            )

        case .squircle:
            DialSliderRow(
                label: "Corner",
                value: baseDoubleBinding(
                    get: { spec in
                        if case .squircle(let crf) = spec { return crf }
                        return 0.2237
                    },
                    set: { _, v in .squircle(cornerRadiusFraction: v) }
                ),
                range: 0 ... 0.5,
                valueText: { String(format: "%.0f%%", $0 * 200) },
                defaultValue: 0.2237,
                onBeginEditing: { project.recordUndo() }
            )

        default:
            EmptyView()
        }
    }

    // Tiny pill-style toggle row that fits the panel's row metrics.
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
    private var radialRepeatSliders: some View {
        DialSliderRow(
            label: "Count",
            value: radialDoubleBinding(
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
            value: radialDoubleBinding(
                get: { $0.centerHole },
                set: { p, v in var p = p; p.centerHole = v; return p }
            ),
            range: 0 ... 0.5,
            valueText: { String(format: "%.0f%%", $0 * 200) },
            defaultValue: ShapeSpec.defaultRadialRepeat.centerHole,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Phase",
            value: radialDoubleBinding(
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
            value: radialDoubleBinding(
                get: { $0.alternateScale },
                set: { p, v in var p = p; p.alternateScale = v; return p }
            ),
            range: 0.2 ... 1.0,
            valueText: { String(format: "%.2f", $0) },
            defaultValue: ShapeSpec.defaultRadialRepeat.alternateScale,
            onBeginEditing: { project.recordUndo() }
        )
    }

    // MARK: - Helpers

    private func toggleRepeat(to enable: Bool) {
        guard let spec = layer.shapeSpec else { return }
        project.recordUndo()
        if enable {
            layer.shapeSpec = spec.wrappingInRadialRepeat(ShapeSpec.defaultRadialRepeat)
        } else {
            layer.shapeSpec = spec.unwrapped
        }
    }

    /// Build a slider binding that reads/writes the base shape's params,
    /// transparently preserving the radial-repeat wrap if any.
    private func baseDoubleBinding(
        get: @escaping (ShapeSpec) -> Double,
        set: @escaping (ShapeSpec, Double) -> ShapeSpec
    ) -> Binding<Double> {
        Binding(
            get: { layer.shapeSpec.map { get($0.unwrapped) } ?? 0 },
            set: { newVal in
                guard let spec = layer.shapeSpec else { return }
                let newBase = set(spec.unwrapped, newVal)
                layer.shapeSpec = spec.replacingBase(with: newBase)
            }
        )
    }

    /// Build a slider binding that reads/writes the current radial-repeat
    /// params. No-op if the spec isn't currently wrapped.
    private func radialDoubleBinding(
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
        }
    }
}

struct TextContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    @FocusState private var textFocused: Bool

    var body: some View {
        PanelSection(title: "Text") {
            ContentField(
                placeholder: "Text",
                text: $layer.text,
                focused: $textFocused,
                project: project
            )
            ColorPickerRow(title: "Color", color: $layer.tintColor, project: project)
            FontDesignRow(design: $layer.fontDesign, project: project)
            FontWeightRow(weight: $layer.fontWeight, project: project)
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
            .padding(.horizontal, 14)
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
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }
}

private struct FontDesignRow: View {
    @Binding var design: LayerFontDesign
    let project: IconProject

    var body: some View {
        HStack(spacing: 10) {
            Text("Font")
                .foregroundStyle(.primary.opacity(0.72))
            Spacer()
            Picker("Font", selection: Binding(
                get: { design },
                set: {
                    project.recordUndo()
                    design = $0
                }
            )) {
                ForEach(LayerFontDesign.allCases, id: \.self) { d in
                    Text(d.displayName).tag(d)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary.opacity(0.72))
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
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
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }
}
