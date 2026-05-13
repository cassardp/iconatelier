import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var project: IconProject
    var initialIntent: CreationIntent? = nil
    private let service = OpenAIImageService()

    @State private var session = ProjectSession()
    @State private var showEditSheet = false
    @State private var showExportSheet = false
    @State private var sheetDetent: PresentationDetent = .fraction(0.5)

    @State private var isGeneratingAI: Bool = false
    @State private var aiError: String?
    @State private var aiSeed: AIFlowSeed?
    @State private var didConsumeInitialIntent: Bool = false
    @State private var showVoiceSheet: Bool = false

    var body: some View {
        GeometryReader { geo in
            let layersBarHeight: CGFloat = 56 + 16
            let verticalMargin: CGFloat = sheetFraction > 0 ? 8 : 0
            let visibleHeight = max(0, geo.size.height * (1 - sheetFraction))
            let blockHeight = max(0, visibleHeight - verticalMargin * 2)
            let iconHeight = max(0, blockHeight - layersBarHeight)
            let iconSide = max(0, min(geo.size.width - 32, iconHeight))
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                IconCanvasView(project: project, session: session)
                    .frame(width: iconSide, height: iconSide)
                LayersBar(
                    project: project,
                    session: session,
                    isSheetOpen: $showEditSheet
                )
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: visibleHeight)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .contentShape(Rectangle())
            .animation(.smooth(duration: 0.35), value: visibleHeight)
        }
        .background(Color.appPageBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AIPhotoFlowBar(
                isGenerating: isGeneratingAI,
                seed: $aiSeed,
                onGenerate: generateFromFlow,
                onAddSymbol: addSymbolLayer,
                onAddText: addTextLayer,
                onAddPrompt: addPromptLayer,
                onAddVoice: { showVoiceSheet = true }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    closeProject()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("Back to gallery")
            }

            ToolbarItem(placement: .principal) {
                HStack {
                    Button {
                        project.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!project.canUndo)

                    Button {
                        project.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!project.canRedo)
                }
            }

            if project.hasContent {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentExportSheet()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export icon")
                }
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showEditSheet) {
            EditSheet(project: project, session: session)
                .presentationDetents([.fraction(0.5), .large], selection: $sheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(project: project)
        }
        .sheet(isPresented: $showVoiceSheet) {
            VoiceCaptureSheet { transcript in
                aiSeed = .prompt(transcript)
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: showEditSheet) { wasOpen, isOpen in
            if isOpen && !wasOpen {
                sheetDetent = .fraction(0.5)
            }
        }
        .onChange(of: exportSignature) { _, _ in
            IconRenderer.updateThumbnail(project)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                IconRenderer.updateThumbnail(project)
                try? modelContext.save()
            }
        }
        .onAppear {
            project.ensureBackground()
            if session.selectedLayerUUID == nil,
               !session.isBackgroundSelected,
               let topLayer = project.layers.last {
                session.selectLayer(topLayer.uuid)
            }
            consumeInitialIntent()
        }
        .onDisappear {
            persistSnapshotInBackground()
        }
        .alert(
            "Generation failed",
            isPresented: Binding(
                get: { aiError != nil },
                set: { if !$0 { aiError = nil } }
            ),
            presenting: aiError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - AI generation

    private func generateFromFlow(
        seed: AIFlowSeed,
        style: AIFlowOption,
        angle: AIFlowOption
    ) {
        guard !isGeneratingAI else { return }
        let prompt: String
        let references: [UIImage]
        switch seed {
        case .photo(let image):
            prompt = "the main subject from the reference image, isolated on transparent background, rendered as \(style.promptFragment), viewed from \(angle.promptFragment)"
            references = [image]
        case .prompt(let text):
            let subject = text.trimmingCharacters(in: .whitespacesAndNewlines)
            prompt = "\(subject), isolated on transparent background, rendered as \(style.promptFragment), viewed from \(angle.promptFragment)"
            references = []
        }
        isGeneratingAI = true
        aiError = nil
        Task {
            do {
                let img = try await service.generateOverlay(
                    prompt: prompt,
                    references: references
                )
                let layer = project.addAIOverlay(image: img, prompt: prompt)
                session.selectLayer(layer.uuid)
            } catch {
                aiError = error.localizedDescription
            }
            isGeneratingAI = false
        }
    }

    private func addSymbolLayer() {
        let layer = project.addSymbolOverlay()
        session.selectLayer(layer.uuid)
    }

    private func addTextLayer() {
        let layer = project.addTextOverlay()
        session.selectLayer(layer.uuid)
    }

    private func addPromptLayer() {
        let layer = project.addEmptyAIOverlay()
        session.selectLayer(layer.uuid)
    }

    private func consumeInitialIntent() {
        guard !didConsumeInitialIntent, let intent = initialIntent else { return }
        didConsumeInitialIntent = true
        switch intent {
        case .text:
            // Gallery already seeded a text overlay; just select it.
            if let last = project.layers.last { session.selectLayer(last.uuid) }
        case .symbol:
            addSymbolLayer()
        case .prompt:
            addPromptLayer()
        case .voice(let transcript):
            aiSeed = .prompt(transcript)
        case .photo(let item):
            // Data load happens here (not in the gallery) so the editor can
            // push immediately when the picker dismisses, avoiding a flash
            // of the gallery between dismissal and navigation.
            Task {
                guard
                    let data = try? await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                else { return }
                aiSeed = .photo(image)
            }
        }
    }

    private func presentExportSheet() {
        // SwiftUI cannot present two sheets from the same anchor view at once.
        // If the edit sheet is open, dismiss it first so the export sheet can
        // be presented from the parent anchor after the dismiss animation.
        if showEditSheet {
            showEditSheet = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                showExportSheet = true
            }
        } else {
            showExportSheet = true
        }
    }

    private func closeProject() {
        showEditSheet = false
        dismiss()
        persistSnapshotInBackground()
    }

    private func persistSnapshotInBackground() {
        let projectRef = project
        let ctx = modelContext
        Task { @MainActor in
            // Yield once so the dismiss/zoom-out animation can start before
            // the synchronous ImageRenderer pass blocks the main actor.
            await Task.yield()
            IconRenderer.updateThumbnail(projectRef)
            try? ctx.save()
        }
    }

    private var sheetFraction: CGFloat {
        if showEditSheet, sheetDetent == .fraction(0.5) { return 0.5 }
        return 0
    }

    private var exportSignature: Int {
        var hasher = Hasher()
        if let bg = project.background {
            hasher.combine(bg.kindRaw)
            hasher.combine(bg.aiImagePNG?.hashValue ?? 0)
            hasher.combine(bg.isHidden)
        }
        for layer in project.layers {
            hasher.combine(layer.uuid)
            hasher.combine(layer.kindRaw)
            hasher.combine(layer.imagePNG?.hashValue ?? 0)
            hasher.combine(layer.symbolName)
            hasher.combine(layer.emoji)
            hasher.combine(layer.text)
            hasher.combine(layer.scaleValue)
            hasher.combine(layer.rotationRadians)
            hasher.combine(layer.offsetW)
            hasher.combine(layer.offsetH)
            hasher.combine(layer.opacity)
            hasher.combine(layer.isHidden)
            hasher.combine(layer.isFlippedHorizontally)
            hasher.combine(layer.isFlippedVertically)
        }
        return hasher.finalize()
    }
}
