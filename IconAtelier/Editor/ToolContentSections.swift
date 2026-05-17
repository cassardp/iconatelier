import SwiftUI

// MARK: - Per-kind content sections

struct ImageContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        PanelSection(title: "Color") {
            ColorPickerRow(title: "Tint", color: $layer.tintColor, onChange: { project.recordUndo() })
            OpacitySlider(layer: layer, project: project)
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
            OpacitySlider(layer: layer, project: project)
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
            ColorPickerRow(title: "Color", color: $layer.tintColor, onChange: { project.recordUndo() })
            FontDesignRow(design: $layer.fontDesign, project: project)
            FontWeightRow(weight: $layer.fontWeight, project: project)
            OpacitySlider(layer: layer, project: project)
        }

        SectionDivider()
        PanelSection(
            title: "Border",
            isOn: BorderPanelContent.enabledBinding(
                layer: layer,
                project: project,
                widthDefault: BorderDefaults.textWidth
            )
        ) {
            BorderPanelContent(
                layer: layer,
                project: project,
                widthRange: 0 ... 0.2,
                widthDefault: BorderDefaults.textWidth,
                widthValueText: { String(format: "%.0f%%", $0 * 500) }
            )
        }

        SectionDivider()
        PanelSection(
            title: "Repeat",
            // Text layers don't actually carry a parametric base — the
            // glyph path itself becomes the base at render time. We still
            // need a non-nil ShapeSpec to hang the radial-repeat params on;
            // iosSquircle is used as an inert sentinel.
            isOn: RadialRepeatPanelContent.enabledBinding(
                layer: layer,
                project: project,
                wrapBase: { .iosSquircle },
                disabledShapeSpec: { nil }
            )
        ) {
            RadialRepeatPanelContent(layer: layer, project: project)
        }
    }
}

// MARK: - Reusable content rows

struct ContentField: View {
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

// MARK: - Font design / weight (segmented)

struct FontDesignRow: View {
    @Binding var design: LayerFontDesign
    let project: IconProject

    var body: some View {
        PanelMenu(
            options: LayerFontDesign.allCases,
            selection: Binding(
                get: { design },
                set: { design = $0 }
            ),
            optionLabel: { $0.displayName },
            onChange: { project.recordUndo() }
        )
    }
}

struct FontWeightRow: View {
    @Binding var weight: LayerFontWeight
    let project: IconProject

    var body: some View {
        PanelMenu(
            options: LayerFontWeight.allCases,
            selection: Binding(
                get: { weight },
                set: { weight = $0 }
            ),
            optionLabel: { $0.displayName },
            onChange: { project.recordUndo() }
        )
    }
}

private extension LayerFontWeight {
    var displayName: String {
        switch self {
        case .regular:  return "Regular"
        case .medium:   return "Medium"
        case .semibold: return "Semibold"
        case .bold:     return "Bold"
        case .heavy:    return "Heavy"
        }
    }
}
