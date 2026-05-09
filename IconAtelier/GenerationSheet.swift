import SwiftUI

struct GenerationSheet: View {
    enum Target: Identifiable, Hashable {
        case background
        case overlay

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var project: IconProject
    let target: Target
    let service: OpenAIImageService

    @State private var prompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(promptHelp)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Describe the image…", text: $prompt, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .disabled(isGenerating)

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                }

                Button(action: generate) {
                    HStack {
                        if isGenerating {
                            ProgressView().controlSize(.small)
                        }
                        Text(isGenerating ? "Generating…" : "Generate")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isGenerating || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isGenerating)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.fraction(0.45), .large])
        .interactiveDismissDisabled(isGenerating)
    }

    private var title: String {
        switch target {
        case .background: "Generate background"
        case .overlay: "Generate overlay"
        }
    }

    private var promptHelp: String {
        switch target {
        case .background:
            "Describe an opaque background (colors, mood, style)."
        case .overlay:
            "Describe a centered subject on a transparent background."
        }
    }

    private func generate() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isGenerating = true
        error = nil
        Task {
            do {
                switch target {
                case .background:
                    let img = try await service.generateBackground(prompt: trimmed)
                    project.setOrReplaceBackground(image: img, prompt: trimmed)
                case .overlay:
                    let img = try await service.generateOverlay(prompt: trimmed)
                    project.addOverlay(image: img, prompt: trimmed)
                }
                isGenerating = false
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isGenerating = false
            }
        }
    }
}
