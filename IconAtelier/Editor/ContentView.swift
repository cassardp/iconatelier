import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

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
    @State private var aiSelectedStyle: AIFlowOption?
    @State private var aiSelectedMaterial: AIFlowOption?
    @State private var didConsumeInitialIntent: Bool = false
    @State private var showPromptSheet: Bool = false
    @State private var showDrawingSheet: Bool = false
    @State private var showImportPicker: Bool = false

    // Lasso multi-selection (Phase 1)
    @State private var canvasFrame: CGRect = .zero
    @State private var layersBarFrame: CGRect = .zero
    @State private var lassoRect: CGRect? = nil
    private static let editorSpaceName = "iconAtelierEditor"

    var body: some View {
        GeometryReader { geo in
            let layersBarHeight: CGFloat = 56 + 16
            let verticalMargin: CGFloat = sheetFraction > 0 ? 8 : 0
            let visibleHeight = max(0, geo.size.height * (1 - sheetFraction))
            let blockHeight = max(0, visibleHeight - verticalMargin * 2)
            let iconHeight = max(0, blockHeight - layersBarHeight)
            let iconSide = max(0, min(geo.size.width - 32, iconHeight))
            ZStack {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    IconCanvasView(project: project, session: session)
                        .frame(width: iconSide, height: iconSide)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named(Self.editorSpaceName))
                        } action: { newFrame in
                            canvasFrame = newFrame
                        }
                    LayersBar(
                        project: project,
                        session: session,
                        isSheetOpen: $showEditSheet
                    )
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(Self.editorSpaceName))
                    } action: { newFrame in
                        layersBarFrame = newFrame
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: visibleHeight)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)

                if let rect = lassoRect {
                    LassoMarquee(rect: rect)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: Self.editorSpaceName)
            .contentShape(Rectangle())
            .gesture(lassoGesture)
            .simultaneousGesture(clearLassoTap)
            .animation(.smooth(duration: 0.35), value: visibleHeight)
        }
        .background(Color.appPageBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AIPhotoFlowBar(
                isGenerating: isGeneratingAI,
                seed: $aiSeed,
                selectedStyle: $aiSelectedStyle,
                selectedMaterial: $aiSelectedMaterial,
                onGenerate: triggerGenerate,
                onAddSymbol: { addSymbolLayer(symbolName: $0) },
                onAddPrompt: { showPromptSheet = true },
                onAddDrawing: { showDrawingSheet = true },
                onAddText: addTextLayer
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
                HStack(spacing: 20) {
                    if session.isMultiSelecting {
                        Button {
                            performBooleanOperation(.union)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Union")

                        Button {
                            performBooleanOperation(.intersect)
                        } label: {
                            Image(systemName: "circle.righthalf.filled")
                        }
                        .accessibilityLabel("Intersect")

                        Button {
                            performBooleanOperation(.subtract)
                        } label: {
                            Image(systemName: "minus")
                        }
                        .accessibilityLabel("Subtract")
                    } else {
                        Button {
                            project.undo()
                            reselectTopIfNeeded()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!project.canUndo)

                        Button {
                            project.redo()
                            reselectTopIfNeeded()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        .disabled(!project.canRedo)
                    }
                }
                .animation(.smooth(duration: 0.2), value: session.isMultiSelecting)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Image", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        presentExportSheet()
                    } label: {
                        Label("Export Icon", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!project.hasContent)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
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
        .sheet(isPresented: $showPromptSheet) {
            AIPromptSheet { text in
                aiSeed = .prompt(text)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDrawingSheet) {
            AIDrawingSheet { image in
                aiSeed = .drawing(image)
            }
            .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.png],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
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
            project.clearHistory()
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

    // MARK: - Lasso multi-selection

    private var lassoGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .named(Self.editorSpaceName))
            .onChanged { value in
                let start = value.startLocation
                // Only engage when the drag starts outside both the canvas and the
                // layers bar — the canvas owns its own transform gestures and the
                // bar owns long-press reorder, so we must not steal from them.
                guard !canvasFrame.contains(start),
                      !layersBarFrame.contains(start)
                else { return }

                let rect = CGRect(
                    x: min(start.x, value.location.x),
                    y: min(start.y, value.location.y),
                    width: abs(value.location.x - start.x),
                    height: abs(value.location.y - start.y)
                )
                lassoRect = rect

                let canvasLocal = rect.offsetBy(dx: -canvasFrame.minX, dy: -canvasFrame.minY)
                let newSelection = lassoHitTest(rect: canvasLocal, side: canvasFrame.width)
                if newSelection != session.lassoSelectedLayerUUIDs {
                    if newSelection.count > session.lassoSelectedLayerUUIDs.count {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    session.setLassoSelection(newSelection)
                }
            }
            .onEnded { _ in
                withAnimation(.smooth(duration: 0.22)) {
                    lassoRect = nil
                }
                if session.lassoSelectedLayerUUIDs.count == 1 {
                    // A single layer matches — promote it to standard selection
                    // for consistency with tap-to-select.
                    if let only = session.lassoSelectedLayerUUIDs.first {
                        session.selectLayer(only)
                    }
                } else if session.lassoSelectedLayerUUIDs.isEmpty {
                    // Nothing matched — make sure we don't leave a dangling state.
                    session.clearLassoSelection()
                } else {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }

    /// Approximate axis-aligned bounding box of each visible layer, in canvas-local
    /// coordinates. Good enough for marquee selection; the exact rotated bounds
    /// are not worth the cost here.
    private func lassoHitTest(rect: CGRect, side: CGFloat) -> Set<UUID> {
        guard side > 0 else { return [] }
        var matched: Set<UUID> = []
        for layer in project.layers where !layer.isHidden {
            let bboxSide = layerBaseFraction(layer.kind) * layer.scale * side
            let centerX = side / 2 + layer.offset.width * side
            let centerY = side / 2 + layer.offset.height * side
            let layerRect = CGRect(
                x: centerX - bboxSide / 2,
                y: centerY - bboxSide / 2,
                width: bboxSide,
                height: bboxSide
            )
            if rect.intersects(layerRect) {
                matched.insert(layer.uuid)
            }
        }
        return matched
    }

    private func layerBaseFraction(_ kind: LayerKind) -> CGFloat {
        switch kind {
        case .aiOverlay: return 0.7
        case .symbol, .emoji, .text: return 0.5
        }
    }

    /// If the currently-selected layer no longer exists (e.g. after undo/redo
    /// removed it), fall back to selecting the top-most remaining layer.
    private func reselectTopIfNeeded() {
        if let id = session.selectedLayerUUID, project.layer(withID: id) == nil {
            session.selectLayer(project.layers.last?.uuid)
        }
    }

    private func performBooleanOperation(_ op: BooleanOpKind) {
        let uuids = session.lassoSelectedLayerUUIDs
        guard uuids.count >= 2 else { return }
        if let result = project.performBooleanOperation(op, on: uuids) {
            session.clearLassoSelection()
            session.selectLayer(result.uuid)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private var clearLassoTap: some Gesture {
        SpatialTapGesture(coordinateSpace: .named(Self.editorSpaceName))
            .onEnded { value in
                guard session.isMultiSelecting else { return }
                let loc = value.location
                guard !canvasFrame.contains(loc),
                      !layersBarFrame.contains(loc)
                else { return }
                session.clearLassoSelection()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
    }

    // MARK: - AI generation

    private func triggerGenerate() {
        guard
            let seed = aiSeed,
            let style = aiSelectedStyle,
            !isGeneratingAI
        else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        generateFromFlow(seed: seed, style: style, material: aiSelectedMaterial)
    }

    private func generateFromFlow(
        seed: AIFlowSeed,
        style: AIFlowOption,
        material: AIFlowOption?
    ) {
        guard !isGeneratingAI else { return }
        let materialClause = material.map { ", \($0.promptFragment)" } ?? ""
        let prompt: String
        let references: [UIImage]
        switch seed {
        case .photo(let image):
            prompt = "the main subject from the reference image, isolated on transparent background, rendered as \(style.promptFragment)\(materialClause)"
            references = [image]
        case .prompt(let text):
            let subject = text.trimmingCharacters(in: .whitespacesAndNewlines)
            prompt = "\(subject), isolated on transparent background, rendered as \(style.promptFragment)\(materialClause)"
            references = []
        case .drawing(let image):
            prompt = "the reference image is a rough hand-drawn sketch made on a touchscreen with a finger. Use it only as a loose shape and composition reference: identify the intended subject, refine its proportions, smooth out shaky lines, fix wobbly geometry, clean up imperfections and produce a polished version of that subject. Do not preserve sketchy linework, do not copy stroke imperfections. The final image must be the cleaned-up, well-drawn subject, isolated on transparent background, rendered as \(style.promptFragment)\(materialClause)"
            references = [image]
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
                aiSeed = nil
                aiSelectedStyle = nil
                aiSelectedMaterial = nil
            } catch {
                aiError = error.localizedDescription
            }
            isGeneratingAI = false
        }
    }

    private func addSymbolLayer(symbolName: String = "star.fill") {
        withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
            let layer = project.addSymbolOverlay(symbolName: symbolName)
            session.selectLayer(layer.uuid)
        }
    }

    private func addTextLayer() {
        withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
            let layer = project.addTextOverlay()
            session.selectLayer(layer.uuid)
        }
    }

    private func addPromptLayer() {
        let layer = project.addEmptyAIOverlay()
        session.selectLayer(layer.uuid)
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let needsScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsScope { url.stopAccessingSecurityScopedResource() }
        }
        guard
            let data = try? Data(contentsOf: url),
            let image = UIImage(data: data)
        else { return }
        withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
            let layer = project.addImportedOverlay(image: image)
            session.selectLayer(layer.uuid)
        }
        showEditSheet = true
    }

    private func consumeInitialIntent() {
        guard !didConsumeInitialIntent, let intent = initialIntent else { return }
        didConsumeInitialIntent = true
        switch intent {
        case .symbol:
            addSymbolLayer()
        case .prompt(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                showPromptSheet = true
            } else {
                aiSeed = .prompt(trimmed)
            }
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

// MARK: - Lasso marquee

private struct LassoMarquee: View {
    let rect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.iaSelectionYellow.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(
                            Color.iaSelectionYellow,
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
    }
}
