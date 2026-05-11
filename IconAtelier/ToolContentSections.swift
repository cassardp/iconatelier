import SwiftUI

// MARK: - Per-kind content sections

struct SymbolContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject

    @FocusState private var nameFocused: Bool

    var body: some View {
        PanelSection(title: "Symbol") {
            ContentField(
                systemImage: "star",
                placeholder: "Symbol name (e.g. star.fill)",
                text: $layer.symbolName,
                focused: $nameFocused,
                project: project
            )
            ColorPickerRow(title: "Color", color: $layer.tintColor, project: project)
            FontWeightRow(weight: $layer.fontWeight, project: project)
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
                systemImage: "face.smiling",
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
                systemImage: "textformat",
                placeholder: "Text",
                text: $layer.text,
                focused: $textFocused,
                project: project
            )
            ColorPickerRow(title: "Color", color: $layer.tintColor, project: project)
            FontWeightRow(weight: $layer.fontWeight, project: project)
        }
    }
}

struct AIOverlayContentSection: View {
    @Bindable var layer: Layer
    let project: IconProject
    @Binding var promptText: String
    let isGenerating: Bool
    var promptFocused: FocusState<Bool>.Binding
    let onGenerate: () -> Void

    var body: some View {
        PanelSection(title: "AI image") {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                TextField(
                    "Describe an image…",
                    text: $promptText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1 ... 4)
                .focused(promptFocused)
                .disabled(isGenerating)

                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PanelStyle.rowFill)
            )

            ActionRow(
                title: layer.image == nil ? "Generate" : "Replace",
                systemImage: "sparkles",
                enabled: !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !isGenerating,
                role: .prominent
            ) {
                onGenerate()
            }
        }
    }
}

// MARK: - Reusable content rows

private struct ContentField: View {
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let project: IconProject

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused(focused)
        }
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

private struct ColorPickerRow: View {
    let title: String
    @Binding var color: Color
    let project: IconProject

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "paintpalette")
                .foregroundStyle(.secondary)
                .frame(width: 22)
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

private struct FontWeightRow: View {
    @Binding var weight: LayerFontWeight
    let project: IconProject

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bold")
                .foregroundStyle(.secondary)
                .frame(width: 22)
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
