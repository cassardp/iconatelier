import SwiftUI

struct AIPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onUse: (_ subject: String, _ style: AIStyle?) -> Void

    @State private var text: String = ""
    @State private var selectedStyle: AIStyle?
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
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
            .overlay(alignment: .bottom) {
                styleCapsulesRow
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { submit() }
                        .disabled(trimmed.isEmpty)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            isFocused = true
        }
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
            .padding(.vertical, 10)
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

    private func submit() {
        guard !trimmed.isEmpty else { return }
        onUse(trimmed, selectedStyle)
        dismiss()
    }
}
