import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var project: IconProject
    private let service = OpenAIImageService()

    @State private var session = ProjectSession()
    @State private var showEditSheet = false
    @State private var showExportSheet = false
    @State private var sheetDetent: PresentationDetent = .fraction(0.5)

    @State private var aiPromptText: String = ""
    @State private var aiPromptImages: [UIImage] = []
    @State private var isGeneratingAI: Bool = false
    @State private var aiError: String?
    @FocusState private var aiPromptFocused: Bool

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
            .simultaneousGesture(
                TapGesture().onEnded {
                    if aiPromptFocused { aiPromptFocused = false }
                }
            )
            .animation(.smooth(duration: 0.35), value: visibleHeight)
        }
        .background(Color.appPageBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AIPromptBar(
                text: $aiPromptText,
                attachments: $aiPromptImages,
                placeholder: promptPlaceholder,
                isGenerating: isGeneratingAI,
                canSubmit: canSubmitPrompt,
                focused: $aiPromptFocused,
                onGenerate: generate
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
                        showExportSheet = true
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
        .onChange(of: showEditSheet) { wasOpen, isOpen in
            if isOpen && !wasOpen {
                aiPromptFocused = false
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

    // MARK: - AI prompt

    private enum PromptTarget {
        case background
        case overlay(layerID: UUID)
    }

    private var currentTarget: PromptTarget? {
        if session.isBackgroundSelected { return .background }
        if let id = session.selectedLayerUUID { return .overlay(layerID: id) }
        return nil
    }

    private var promptPlaceholder: String {
        switch currentTarget {
        case .background: return "Describe a background…"
        case .overlay:    return "Describe an image…"
        case .none:       return "Select a layer or background…"
        }
    }

    private var canSubmitPrompt: Bool {
        !isGeneratingAI
            && currentTarget != nil
            && !aiPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func generate() {
        guard let target = currentTarget else { return }
        let trimmed = aiPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGeneratingAI else { return }
        let references = aiPromptImages
        isGeneratingAI = true
        aiError = nil
        aiPromptFocused = false
        Task {
            do {
                switch target {
                case .background:
                    let img = try await service.generateBackground(
                        prompt: trimmed,
                        references: references
                    )
                    project.setBackgroundAI(image: img, prompt: trimmed)
                case .overlay(let layerID):
                    let img = try await service.generateOverlay(
                        prompt: trimmed,
                        references: references
                    )
                    if let layer = project.layer(withID: layerID) {
                        project.recordUndo()
                        layer.kind = .aiOverlay
                        layer.image = img
                        layer.sourcePrompt = trimmed
                        session.selectLayer(layer.uuid)
                    } else {
                        let layer = project.addAIOverlay(image: img, prompt: trimmed)
                        session.selectLayer(layer.uuid)
                    }
                }
                aiPromptText = ""
                aiPromptImages = []
            } catch {
                aiError = error.localizedDescription
            }
            isGeneratingAI = false
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
