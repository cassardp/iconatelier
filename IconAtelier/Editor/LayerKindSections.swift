import SwiftUI

// MARK: - Per-kind content sections

struct ImageContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        PanelSection(title: "Image") {
            ColorPickerRow(title: "Tint", color: $layer.tintColor, onChange: { project.recordUndo() })
        }
    }
}

struct TextContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    @FocusState private var textFocused: Bool

    var body: some View {
        PanelSection(title: "Text") {
            PanelTextField(
                placeholder: "Text",
                text: $layer.text,
                focused: $textFocused,
                project: project
            )
            ColorPickerRow(title: "Color", color: $layer.tintColor, onChange: { project.recordUndo() })
            FontDesignRow(design: $layer.fontDesign, project: project)
            FontWeightRow(weight: $layer.fontWeight, project: project)
        }
    }
}

// MARK: - Reusable content rows

struct PanelTextField: View {
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
