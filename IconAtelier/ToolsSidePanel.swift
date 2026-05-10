import SwiftUI
import UIKit

struct EditTabContent: View {
    @Bindable var project: IconProject
    @Binding var promptText: String
    let isGenerating: Bool
    var promptFocused: FocusState<Bool>.Binding
    let onGenerate: (GenerationTarget) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                generateSection
                Divider()
                selectionSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var trimmedPrompt: String {
        promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canGenerate: Bool {
        !trimmedPrompt.isEmpty && !isGenerating
    }

    // MARK: - Generate

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generate")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)

                TextField("Describe an image…", text: $promptText, axis: .vertical)
                    .lineLimit(1 ... 4)
                    .textFieldStyle(.plain)
                    .focused(promptFocused)
                    .disabled(isGenerating)
                    .submitLabel(.return)

                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            HStack(spacing: 10) {
                Button {
                    onGenerate(.background)
                } label: {
                    Label(
                        project.background == nil ? "as Background" : "Replace background",
                        systemImage: "photo"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!canGenerate)

                Button {
                    onGenerate(.overlay)
                } label: {
                    Label("as Overlay", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!canGenerate)
            }
        }
    }

    // MARK: - Selection / contextual tools

    private var selectionSection: some View {
        let layer = project.selectedLayer
        let isOverlay = layer?.kind == .aiOverlay
        let hasLayer = layer != nil

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Selection")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(layer?.name ?? "None")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            opacityRow(layer: layer, enabled: hasLayer)
            scaleRow(layer: layer, enabled: isOverlay)
            rotationRow(layer: layer, enabled: isOverlay)

            HStack(spacing: 10) {
                Button {
                    if let layer { recenterOverlay(layer) }
                } label: {
                    Label("Center", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isOverlay)

                Button {
                    if let layer { project.duplicate(layer) }
                } label: {
                    Label("Duplicate", systemImage: "square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!hasLayer)
            }

            HStack(spacing: 10) {
                Button {
                    if let layer { project.toggleVisibility(layer) }
                } label: {
                    Label(
                        layer?.isHidden == true ? "Show" : "Hide",
                        systemImage: layer?.isHidden == true ? "eye" : "eye.slash"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!hasLayer)

                Button(role: .destructive) {
                    if let layer { project.remove(layer) }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!hasLayer)
            }
        }
    }

    @ViewBuilder
    private func opacityRow(layer: Layer?, enabled: Bool) -> some View {
        SliderRow(
            label: "Opacity",
            symbol: "drop.fill",
            value: Binding(
                get: { layer?.opacity ?? 1.0 },
                set: { layer?.opacity = $0 }
            ),
            range: 0 ... 1,
            enabled: enabled,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private func scaleRow(layer: Layer?, enabled: Bool) -> some View {
        SliderRow(
            label: "Scale",
            symbol: "arrow.up.left.and.arrow.down.right",
            value: Binding(
                get: { layer?.scale ?? 1.0 },
                set: { layer?.scale = $0 }
            ),
            range: 0.1 ... 3.0,
            enabled: enabled,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private func rotationRow(layer: Layer?, enabled: Bool) -> some View {
        SliderRow(
            label: "Rotation",
            symbol: "arrow.clockwise",
            value: Binding(
                get: { layer?.rotation.degrees ?? 0 },
                set: { layer?.rotation = .degrees($0) }
            ),
            range: -180 ... 180,
            enabled: enabled,
            onBeginEditing: { project.recordUndo() }
        )
    }

    private func recenterOverlay(_ layer: Layer) {
        project.recordUndo()
        layer.offset = .zero
    }
}

private struct SliderRow: View {
    let label: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let enabled: Bool
    let onBeginEditing: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Slider(
                value: $value,
                in: range,
                onEditingChanged: { editing in
                    if editing { onBeginEditing() }
                }
            )
            .controlSize(.small)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.5)
    }
}

extension SliderRow {
    init(
        label: String,
        symbol: String,
        value: Binding<CGFloat>,
        range: ClosedRange<Double>,
        enabled: Bool,
        onBeginEditing: @escaping () -> Void
    ) {
        self.label = label
        self.symbol = symbol
        self._value = Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = CGFloat($0) }
        )
        self.range = range
        self.enabled = enabled
        self.onBeginEditing = onBeginEditing
    }
}
