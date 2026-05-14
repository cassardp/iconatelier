import SwiftUI

struct AIPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onUse: (String) -> Void

    @State private var text: String = ""
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

    private func submit() {
        guard !trimmed.isEmpty else { return }
        onUse(trimmed)
        dismiss()
    }
}
