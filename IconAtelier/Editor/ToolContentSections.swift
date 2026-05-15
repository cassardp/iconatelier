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
            shapeParamRows
            ColorPickerRow(title: "Color", color: $layer.tintColor, project: project)
        }
    }

    @ViewBuilder
    private var shapeParamRows: some View {
        switch layer.shapeSpec {
        case .polygon:
            DialSliderRow(
                label: "Sides",
                value: Binding(
                    get: {
                        if case .polygon(let s, _) = layer.shapeSpec { return Double(s) }
                        return 6
                    },
                    set: { v in
                        if case .polygon(_, let r) = layer.shapeSpec {
                            layer.shapeSpec = .polygon(sides: Int(v.rounded()), rotation: r)
                        }
                    }
                ),
                range: 3 ... 12,
                valueText: { "\(Int($0.rounded()))" },
                defaultValue: 6,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Rotation",
                value: Binding(
                    get: {
                        if case .polygon(_, let r) = layer.shapeSpec { return r }
                        return -90
                    },
                    set: { v in
                        if case .polygon(let s, _) = layer.shapeSpec {
                            layer.shapeSpec = .polygon(sides: s, rotation: v)
                        }
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
                value: Binding(
                    get: {
                        if case .star(let p, _, _) = layer.shapeSpec { return Double(p) }
                        return 5
                    },
                    set: { v in
                        if case .star(_, let ir, let r) = layer.shapeSpec {
                            layer.shapeSpec = .star(points: Int(v.rounded()), innerRatio: ir, rotation: r)
                        }
                    }
                ),
                range: 3 ... 12,
                valueText: { "\(Int($0.rounded()))" },
                defaultValue: 5,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Inner Ratio",
                value: Binding(
                    get: {
                        if case .star(_, let ir, _) = layer.shapeSpec { return ir }
                        return 0.5
                    },
                    set: { v in
                        if case .star(let p, _, let r) = layer.shapeSpec {
                            layer.shapeSpec = .star(points: p, innerRatio: v, rotation: r)
                        }
                    }
                ),
                range: 0.1 ... 0.9,
                valueText: { String(format: "%.2f", $0) },
                defaultValue: 0.5,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Rotation",
                value: Binding(
                    get: {
                        if case .star(_, _, let r) = layer.shapeSpec { return r }
                        return -90
                    },
                    set: { v in
                        if case .star(let p, let ir, _) = layer.shapeSpec {
                            layer.shapeSpec = .star(points: p, innerRatio: ir, rotation: v)
                        }
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
                value: Binding(
                    get: {
                        if case .squircle(let crf) = layer.shapeSpec { return crf }
                        return 0.2237
                    },
                    set: { v in
                        layer.shapeSpec = .squircle(cornerRadiusFraction: v)
                    }
                ),
                range: 0 ... 0.5,
                valueText: { String(format: "%.0f%%", $0 * 200) },
                defaultValue: 0.2237,
                onBeginEditing: { project.recordUndo() }
            )

        case .petal:
            petalSliders

        case .radialRepeat:
            radialRepeatSliders

        case nil:
            EmptyView()
        }
    }

    // Shared between top-level .petal layers and a .radialRepeat whose base
    // is a .petal — both surface the same four params here.
    @ViewBuilder
    private var petalSliders: some View {
        DialSliderRow(
            label: "Length",
            value: Binding(
                get: { petalParam(\.length) ?? 0.9 },
                set: { v in updatePetal { p in
                    .petal(length: v, width: p.width, pointiness: p.pointiness, curvature: p.curvature)
                } }
            ),
            range: 0.2 ... 1.0,
            valueText: { String(format: "%.2f", $0) },
            defaultValue: 0.9,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Width",
            value: Binding(
                get: { petalParam(\.width) ?? 0.45 },
                set: { v in updatePetal { p in
                    .petal(length: p.length, width: v, pointiness: p.pointiness, curvature: p.curvature)
                } }
            ),
            range: 0.1 ... 1.0,
            valueText: { String(format: "%.2f", $0) },
            defaultValue: 0.45,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Pointiness",
            value: Binding(
                get: { petalParam(\.pointiness) ?? 0.5 },
                set: { v in updatePetal { p in
                    .petal(length: p.length, width: p.width, pointiness: v, curvature: p.curvature)
                } }
            ),
            range: 0 ... 1,
            valueText: { String(format: "%.2f", $0) },
            defaultValue: 0.5,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Curvature",
            value: Binding(
                get: { petalParam(\.curvature) ?? 0.4 },
                set: { v in updatePetal { p in
                    .petal(length: p.length, width: p.width, pointiness: p.pointiness, curvature: v)
                } }
            ),
            range: -1 ... 1,
            valueText: { String(format: "%+.2f", $0) },
            defaultValue: 0.4,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private var radialRepeatSliders: some View {
        DialSliderRow(
            label: "Count",
            value: Binding(
                get: {
                    if case .radialRepeat(_, let c, _, _, _) = layer.shapeSpec { return Double(c) }
                    return 6
                },
                set: { v in
                    if case .radialRepeat(let b, _, let h, let p, let a) = layer.shapeSpec {
                        layer.shapeSpec = .radialRepeat(
                            base: b, count: Int(v.rounded()),
                            centerHole: h, phaseDegrees: p, alternateScale: a
                        )
                    }
                }
            ),
            range: 2 ... 24,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 6,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Center Hole",
            value: Binding(
                get: {
                    if case .radialRepeat(_, _, let h, _, _) = layer.shapeSpec { return h }
                    return 0.1
                },
                set: { v in
                    if case .radialRepeat(let b, let c, _, let p, let a) = layer.shapeSpec {
                        layer.shapeSpec = .radialRepeat(
                            base: b, count: c, centerHole: v, phaseDegrees: p, alternateScale: a
                        )
                    }
                }
            ),
            range: 0 ... 0.5,
            valueText: { String(format: "%.0f%%", $0 * 200) },
            defaultValue: 0.1,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Phase",
            value: Binding(
                get: {
                    if case .radialRepeat(_, _, _, let p, _) = layer.shapeSpec { return p }
                    return -90
                },
                set: { v in
                    if case .radialRepeat(let b, let c, let h, _, let a) = layer.shapeSpec {
                        layer.shapeSpec = .radialRepeat(
                            base: b, count: c, centerHole: h, phaseDegrees: v, alternateScale: a
                        )
                    }
                }
            ),
            range: -180 ... 180,
            valueText: { String(format: "%.0f°", $0) },
            defaultValue: -90,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Alternate",
            value: Binding(
                get: {
                    if case .radialRepeat(_, _, _, _, let a) = layer.shapeSpec { return a }
                    return 1.0
                },
                set: { v in
                    if case .radialRepeat(let b, let c, let h, let p, _) = layer.shapeSpec {
                        layer.shapeSpec = .radialRepeat(
                            base: b, count: c, centerHole: h, phaseDegrees: p, alternateScale: v
                        )
                    }
                }
            ),
            range: 0.2 ... 1.0,
            valueText: { String(format: "%.2f", $0) },
            defaultValue: 1.0,
            onBeginEditing: { project.recordUndo() }
        )

        // When the radial base is a petal, expose its 4 params here too so
        // the user can shape the flower's petals without rebuilding the layer.
        if case .radialRepeat(let base, _, _, _, _) = layer.shapeSpec,
           case .petal = base {
            SectionDivider()
            petalSliders
        }
    }

    // MARK: - Petal param access (handles top-level .petal or .radialRepeat→.petal)

    private struct PetalParams {
        var length: Double
        var width: Double
        var pointiness: Double
        var curvature: Double
    }

    private func petalParam(_ field: KeyPath<PetalParams, Double>) -> Double? {
        guard let params = currentPetalParams() else { return nil }
        return params[keyPath: field]
    }

    private func currentPetalParams() -> PetalParams? {
        switch layer.shapeSpec {
        case let .petal(l, w, p, c):
            return PetalParams(length: l, width: w, pointiness: p, curvature: c)
        case let .radialRepeat(base, _, _, _, _):
            if case let .petal(l, w, p, c) = base {
                return PetalParams(length: l, width: w, pointiness: p, curvature: c)
            }
            return nil
        default:
            return nil
        }
    }

    private func updatePetal(_ transform: (PetalParams) -> ShapeSpec) {
        guard let params = currentPetalParams() else { return }
        let newPetalSpec = transform(params)
        switch layer.shapeSpec {
        case .petal:
            layer.shapeSpec = newPetalSpec
        case let .radialRepeat(_, count, hole, phase, alt):
            layer.shapeSpec = .radialRepeat(
                base: newPetalSpec,
                count: count,
                centerHole: hole,
                phaseDegrees: phase,
                alternateScale: alt
            )
        default:
            break
        }
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
