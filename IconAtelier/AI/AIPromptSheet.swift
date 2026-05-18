import PhotosUI
import SwiftUI

struct AIPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onGenerate: (
        _ subject: String,
        _ style: AIStyle?,
        _ material: AIMaterial?,
        _ reference: UIImage?,
        _ transparent: Bool
    ) -> Void

    @State private var text: String = ""
    @State private var selectedStyle: AIStyle?
    @State private var selectedMaterial: AIMaterial?
    @State private var pickerItem: PhotosPickerItem?
    @State private var referenceImage: UIImage?
    @State private var isTransparent: Bool = true
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmed.isEmpty || referenceImage != nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                if trimmed.isEmpty {
                    Text("Describe the icon you want…")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }

                TextField("", text: $text, axis: .vertical)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") { submit() }
                        .disabled(!canSubmit)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            isFocused = true
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await loadReference(from: newItem) }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Divider()
            styleCapsulesRow
            materialCapsulesRow
            controlsRow
        }
        .padding(.bottom, 4)
        .background(Color(uiColor: .systemBackground))
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            referenceControl
            Spacer(minLength: 0)
            transparencyToggle
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var referenceControl: some View {
        if let referenceImage {
            referenceThumbnail(referenceImage)
        } else {
            addReferenceButton
        }
    }

    private var addReferenceButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            HStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                Text("Reference")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            }
        }
        .buttonStyle(.plain)
    }

    private func referenceThumbnail(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 10))

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                referenceImage = nil
                pickerItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.7))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel("Remove reference image")
        }
        .padding(.trailing, 6)
    }

    private var transparencyToggle: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isTransparent.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isTransparent ? "checkmark" : "circle")
                    .font(.caption.weight(.bold))
                Text("Transparent")
            }
            .font(.footnote.weight(isTransparent ? .semibold : .medium))
            .foregroundStyle(isTransparent ? Color(uiColor: .systemBackground) : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(isTransparent ? Color.primary : Color(uiColor: .secondarySystemBackground))
            }
            .animation(.smooth(duration: 0.18), value: isTransparent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Transparent background")
        .accessibilityValue(isTransparent ? "On" : "Off")
    }

    private var styleCapsulesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                styleCapsule(nil)
                ForEach(AIStyle.all) { style in
                    styleCapsule(style)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func styleCapsule(_ style: AIStyle?) -> some View {
        let isSelected = selectedStyle?.id == style?.id
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedStyle = isSelected ? nil : style
        } label: {
            Text(style?.label ?? "None")
                .font(.footnote.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.primary : Color(uiColor: .secondarySystemBackground))
                }
                .animation(.smooth(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style?.label ?? "No style")
    }

    private var materialCapsulesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                materialCapsule(nil)
                ForEach(AIMaterial.all) { material in
                    materialCapsule(material)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func materialCapsule(_ material: AIMaterial?) -> some View {
        let isSelected = selectedMaterial?.id == material?.id
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedMaterial = isSelected ? nil : material
        } label: {
            Text(material?.label ?? "Any material")
                .font(.footnote.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.primary : Color(uiColor: .secondarySystemBackground))
                }
                .animation(.smooth(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(material?.label ?? "No material")
    }

    private func loadReference(from item: PhotosPickerItem?) async {
        guard let item else {
            referenceImage = nil
            return
        }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            referenceImage = image
        }
    }

    private func submit() {
        guard canSubmit else { return }
        onGenerate(trimmed, selectedStyle, selectedMaterial, referenceImage, isTransparent)
        dismiss()
    }
}
