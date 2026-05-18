import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var project: IconProject

    @State private var session = ProjectSession()
    @State private var showEditSheet = false
    @State private var fanIsOpen = false
    @State private var showExportSheet = false
    @State private var sheetDetent: PresentationDetent = .fraction(0.5)

    @State private var showImportPicker: Bool = false
    @State private var showPromptSheet: Bool = false
    @State private var isGenerating: Bool = false
    @State private var generationError: String?
    @State private var showNoAPIKeyAlert: Bool = false
    @State private var wasEditSheetOpenBeforeExport = false

    // Lasso multi-selection (Phase 1)
    @State private var canvasFrame: CGRect = .zero
    @State private var layersBarFrame: CGRect = .zero
    @State private var lassoRect: CGRect? = nil
    private static let editorSpaceName = "iconAtelierEditor"

    private var fanItems: [ShapeFanItem] {
        [
            ShapeFanItem(id: "text", symbol: "textformat", label: "Text") {
                addTextLayer(presentSheet: false)
            },
            ShapeFanItem(id: "circle", symbol: "circle", label: "Circle") {
                addShapeLayer(spec: .preset(.circle), presentSheet: false)
            },
            ShapeFanItem(id: "square", symbol: "square", label: "Square") {
                addShapeLayer(spec: .preset(.square), presentSheet: false)
            },
            ShapeFanItem(id: "drop", symbol: "drop", label: "Drop") {
                addShapeLayer(spec: .preset(.drop), presentSheet: false)
            },
            ShapeFanItem(id: "flower", symbol: "star", label: "Flower") {
                addShapeLayer(spec: .preset(.flower6), presentSheet: false)
            },
            ShapeFanItem(id: "generate", symbol: "wand.and.stars", label: "Generate") {
                showPromptSheet = true
            }
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let layersBarHeight: CGFloat = 48
            // Reserve space below the layers bar for the floating + button
            // only when it's actually visible. When the edit sheet is open
            // the button hides, so the bar can sit closer to the sheet edge.
            let fanButtonRowHeight: CGFloat = showEditSheet ? 0 : 76
            // Minimum air above the icon so it never sticks to the top of the
            // visible band (status bar / nav title).
            let topPadding: CGFloat = 16
            // The sheet's `.fraction(0.5)` and `.height(N)` detents measure
            // against the *full* window height (including the top/bottom safe
            // areas), whereas `geo.size.height` excludes them. Reconstructing
            // the total screen height here lets us project the sheet's cover
            // band back into geo's coordinate space — otherwise the VStack
            // ends up extending behind the sheet by ~50pt in the 0.5 detent.
            let totalScreenHeight = geo.size.height
                + geo.safeAreaInsets.top
                + geo.safeAreaInsets.bottom
            let sheetCoverFromScreenBottom = sheetCoverHeight(totalHeight: totalScreenHeight)
            let sheetCoverInGeo = max(0, sheetCoverFromScreenBottom - geo.safeAreaInsets.bottom)
            let visibleHeight = max(0, geo.size.height - sheetCoverInGeo)
            let iconHeight = max(0, visibleHeight - layersBarHeight - topPadding - fanButtonRowHeight)
            let iconSide = max(0, min(geo.size.width - 32, iconHeight))
            let leftover = max(0, visibleHeight - iconSide - layersBarHeight - fanButtonRowHeight)
            let topSpacer = max(topPadding, leftover / 2)
            let bottomSpacer = max(0, leftover - topSpacer)
            ZStack {
                VStack(spacing: 0) {
                    Color.clear.frame(height: topSpacer)
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
                        onItemSelected: presentEditSheet
                    )
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(Self.editorSpaceName))
                    } action: { newFrame in
                        layersBarFrame = newFrame
                    }
                    Color.clear
                        .frame(height: fanButtonRowHeight + bottomSpacer)
                        .contentShape(Rectangle())
                        .gesture(swipeUpToEditGesture)
                }
                .frame(width: geo.size.width, height: visibleHeight)
                .overlay {
                    if fanIsOpen {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.22, bounce: 0.25)) {
                                    fanIsOpen = false
                                }
                            }
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .bottom) {
                    ShapeFanButton(
                        items: fanItems,
                        isOpen: $fanIsOpen
                    )
                    .padding(.bottom, 16)
                    .opacity(showEditSheet ? 0 : 1)
                    .scaleEffect(showEditSheet ? 0.4 : 1)
                    .animation(.spring(duration: 0.25, bounce: 0.2), value: showEditSheet)
                    .allowsHitTesting(!showEditSheet)
                }
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
                if session.isMultiSelecting {
                    HStack(spacing: 20) {
                        ForEach(BooleanOpKind.allCases, id: \.self) { op in
                            Button {
                                performBooleanOperation(op)
                            } label: {
                                op.icon
                            }
                            .accessibilityLabel(op.label)
                        }
                    }
                } else {
                    HStack(spacing: 20) {
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
            EditSheet(
                project: project,
                session: session
            )
            .presentationDetents(
                [.fraction(0.5), .large],
                selection: $sheetDetent
            )
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(project: project)
        }
        .sheet(isPresented: $showPromptSheet) {
            AIPromptSheet { subject, style, material, reference, transparent in
                handlePromptSubmitted(
                    subject: subject,
                    style: style,
                    material: material,
                    reference: reference,
                    transparent: transparent
                )
            }
        }
        .alert(
            "Add OpenAI API key",
            isPresented: $showNoAPIKeyAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Open the gallery settings to add your OpenAI API key, then try again.")
        }
        .alert(
            "Generation failed",
            isPresented: Binding(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            ),
            presenting: generationError
        ) { _ in
            Button("OK", role: .cancel) { generationError = nil }
        } message: { error in
            Text(error)
        }
        .overlay {
            if isGenerating {
                generatingOverlay
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.png],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .onChange(of: showExportSheet) { _, isPresented in
            // iOS allows only one sheet from a given anchor, so the edit sheet
            // is temporarily dismissed while export is on screen. Restore the
            // previous state once export dismisses.
            if !isPresented && wasEditSheetOpenBeforeExport && !showEditSheet {
                wasEditSheetOpenBeforeExport = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    showEditSheet = true
                }
            }
        }
        .onChange(of: exportSignature) { _, _ in
            // Thumbnail is refreshed in-memory so the gallery is up to date
            // when we navigate back. Actual persistence is debounced until
            // the project closes or the app backgrounds.
            IconRenderer.updateThumbnail(project)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                IconRenderer.updateThumbnail(project)
                store.save(project)
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
            project.clearHistory()
        }
    }

    // MARK: - Swipe up to open EditSheet

    private var swipeUpToEditGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onEnded { value in
                guard !showEditSheet, !fanIsOpen else { return }
                let dy = value.translation.height
                let predictedDY = value.predictedEndTranslation.height
                let horizontal = abs(value.translation.width)
                let isUpward = dy < -40 || predictedDY < -120
                let isMostlyVertical = abs(dy) > horizontal
                guard isUpward, isMostlyVertical else { return }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                presentEditSheet()
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
        case .image: return 0.7
        case .text, .parametricShape: return 0.5
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

    private func addShapeLayer(spec: ShapeSpec, presentSheet: Bool = true) {
        withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
            let layer = project.addShapeLayer(spec: spec)
            session.selectLayer(layer.uuid)
        }
        if presentSheet { presentEditSheet() }
    }

    private func addTextLayer(presentSheet: Bool = true) {
        withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
            let layer = project.addTextOverlay()
            session.selectLayer(layer.uuid)
        }
        if presentSheet { presentEditSheet() }
    }

    private func presentEditSheet() {
        guard !showEditSheet else { return }
        sheetDetent = .fraction(0.5)
        showEditSheet = true
    }

    private func handlePromptSubmitted(
        subject: String,
        style: AIStyle?,
        material: AIMaterial?,
        reference: UIImage?,
        transparent: Bool
    ) {
        Task { @MainActor in
            guard let key = await APIKeyStore.shared.load(), !key.isEmpty else {
                showNoAPIKeyAlert = true
                return
            }
            isGenerating = true
            defer { isGenerating = false }
            let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            let subjectText = trimmedSubject.isEmpty
                ? "the subject shown in the reference image"
                : trimmedSubject
            let materialClause = material.map { ". Surface and material: \($0.promptFragment)" } ?? ""
            let finalPrompt: String
            if let style {
                let isolation = transparent ? "isolated on transparent background, " : ""
                finalPrompt = "\(subjectText), \(isolation)rendered as \(style.promptFragment)\(materialClause)"
            } else {
                finalPrompt = "\(subjectText)\(materialClause)"
            }
            do {
                let references = reference.map { [$0] } ?? []
                let image = try await OpenAIImageService().generateOverlay(
                    prompt: finalPrompt,
                    transparent: transparent,
                    references: references
                )
                withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
                    let layer = project.addGeneratedImage(image: image)
                    session.selectLayer(layer.uuid)
                }
                presentEditSheet()
            } catch {
                generationError = error.localizedDescription
            }
        }
    }

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("Generating…")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
        .transition(.opacity)
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
        presentEditSheet()
    }

    private func presentExportSheet() {
        // SwiftUI cannot present two sheets from the same anchor view at once.
        // If the edit sheet is open, dismiss it first so the export sheet can
        // be presented from the parent anchor after the dismiss animation.
        if showEditSheet {
            wasEditSheetOpenBeforeExport = true
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
        let storeRef = store
        Task { @MainActor in
            // Yield once so the dismiss/zoom-out animation can start before
            // the synchronous ImageRenderer pass blocks the main actor.
            await Task.yield()
            IconRenderer.updateThumbnail(projectRef)
            storeRef.save(projectRef)
        }
    }

    /// Height (in points) that the sheet visually claims from the bottom of
    /// the *full* window for the current detent. The caller projects this
    /// into geo space if needed.
    private func sheetCoverHeight(totalHeight: CGFloat) -> CGFloat {
        guard showEditSheet else { return 0 }
        if sheetDetent == .fraction(0.5) { return totalHeight * 0.5 }
        // .large covers (almost) everything — clamp so the canvas can collapse
        // without producing negative dimensions.
        return totalHeight
    }

    private var exportSignature: Int {
        var hasher = Hasher()
        if let bg = project.background {
            hasher.combine(bg.kind)
            hasher.combine(bg.isHidden)
        }
        for layer in project.layers {
            hasher.combine(layer.uuid)
            hasher.combine(layer.kind)
            hasher.combine(layer.imagePNG?.hashValue ?? 0)
            hasher.combine(layer.text)
            hasher.combine(layer.shapeSpec)
            hasher.combine(layer.cornerRadius)
            hasher.combine(layer.borderWidth)
            hasher.combine(layer.storedBorderColor)
            hasher.combine(layer.borderPosition)
            hasher.combine(layer.storedTintColor)
            hasher.combine(layer.storedFillPaint)
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
