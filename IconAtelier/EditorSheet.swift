import SwiftUI

enum GenerationTarget: Identifiable, Hashable {
    case background
    case overlay

    var id: Self { self }
}

struct EditSheet: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    let service: OpenAIImageService

    @State private var promptText: String = ""
    @State private var bgAIPromptText: String = ""
    @State private var isGenerating: Bool = false
    @State private var generationError: String?
    @FocusState private var promptFocused: Bool

    var body: some View {
        Group {
            if session.isBackgroundSelected {
                BackgroundEditorContent(
                    project: project,
                    aiPromptText: $bgAIPromptText,
                    isGenerating: isGenerating,
                    promptFocused: $promptFocused,
                    onGenerate: { generate(.background) }
                )
            } else {
                EditTabContent(
                    project: project,
                    session: session,
                    promptText: $promptText,
                    isGenerating: isGenerating,
                    promptFocused: $promptFocused,
                    onGenerate: generate
                )
            }
        }
        .sheetUserInterfaceStyle(.dark)
        .presentationBackground(Color(.systemBackground))
        .onChange(of: session.isBackgroundSelected) { _, isBg in
            promptFocused = false
            if isBg {
                bgAIPromptText = project.safeBackground.aiPrompt ?? ""
            } else {
                promptText = project.layer(withID: session.selectedLayerUUID)?.sourcePrompt ?? ""
            }
        }
        .onChange(of: session.selectedLayerUUID) { _, _ in
            guard !session.isBackgroundSelected else { return }
            promptFocused = false
            promptText = project.layer(withID: session.selectedLayerUUID)?.sourcePrompt ?? ""
        }
        .onAppear {
            if session.isBackgroundSelected {
                bgAIPromptText = project.safeBackground.aiPrompt ?? ""
            } else {
                promptText = project.layer(withID: session.selectedLayerUUID)?.sourcePrompt ?? ""
            }
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
        let source = target == .background ? bgAIPromptText : promptText
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        isGenerating = true
        generationError = nil
        promptFocused = false
        Task {
            do {
                switch target {
                case .background:
                    let img = try await service.generateBackground(prompt: trimmed)
                    project.setBackgroundAI(image: img, prompt: trimmed)
                case .overlay:
                    let img = try await service.generateOverlay(prompt: trimmed)
                    let layer = project.fillSelectedEmptyOverlayOrAdd(
                        selected: project.layer(withID: session.selectedLayerUUID),
                        image: img,
                        prompt: trimmed
                    )
                    session.selectLayer(layer.uuid)
                }
            } catch {
                generationError = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
