import SwiftUI

enum GenerationTarget: Identifiable, Hashable {
    case background
    case overlay

    var id: Self { self }
}

struct EditSheet: View {
    @Bindable var project: IconProject
    let service: OpenAIImageService

    @State private var promptText: String = ""
    @State private var isGenerating: Bool = false
    @State private var generationError: String?
    @FocusState private var promptFocused: Bool

    var body: some View {
        NavigationStack {
            EditTabContent(
                project: project,
                promptText: $promptText,
                isGenerating: isGenerating,
                promptFocused: $promptFocused,
                onGenerate: generate
            )
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(
            "Generation failed",
            isPresented: Binding(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            ),
            presenting: generationError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func generate(_ target: GenerationTarget) {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        isGenerating = true
        generationError = nil
        promptFocused = false
        Task {
            do {
                switch target {
                case .background:
                    let img = try await service.generateBackground(prompt: trimmed)
                    project.setOrReplaceBackground(image: img, prompt: trimmed)
                case .overlay:
                    let img = try await service.generateOverlay(prompt: trimmed)
                    project.fillSelectedEmptyOverlayOrAdd(image: img, prompt: trimmed)
                }
                promptText = ""
            } catch {
                generationError = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
