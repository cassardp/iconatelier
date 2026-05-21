import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var project: IconProject

    @State private var session = ProjectSession()
    @State private var ai = AIFlowController()
    @State private var lasso = LassoController()

    @State private var showEditSheet = false
    @State private var fanIsOpen = false
    @State private var showExportSheet = false
    @State private var sheetDetent: PresentationDetent = .fraction(0.5)

    @State private var showImportPicker: Bool = false
    @State private var wasEditSheetOpenBeforeExport = false
    @State private var trashArmed: Bool = false

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
            ShapeFanItem(id: "star", symbol: "star", label: "Star") {
                addShapeLayer(spec: .preset(.star5), presentSheet: false)
            },
            ShapeFanItem(id: "generate", symbol: "wand.and.stars", label: "Generate") {
                ai.showPromptSheet = true
            }
        ]
    }

    private func handleLayerDragMove(uuid: UUID, editorPoint: CGPoint) -> Bool {
        guard lasso.fabFrame != .zero else {
            if trashArmed { trashArmed = false }
            return false
        }
        let hitZone = lasso.fabFrame.insetBy(dx: -28, dy: -28)
        let armed = hitZone.contains(editorPoint)
        if armed != trashArmed {
            trashArmed = armed
            if armed {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
            if fanIsOpen && armed {
                withAnimation(.spring(duration: 0.22, bounce: 0.25)) {
                    fanIsOpen = false
                }
            }
        }
        return armed
    }

    private func handleLayerDragEnd(uuid: UUID) -> Bool {
        let shouldDelete = trashArmed
        trashArmed = false
        guard shouldDelete, let layer = project.layer(withID: uuid) else { return false }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            project.remove(layer)
            if session.selectedLayerUUID == uuid {
                if let top = project.layers.last {
                    session.selectLayer(top.uuid)
                } else {
                    session.selectBackground()
                }
            }
        }
        return true
    }

    private var showsQuickActionsBar: Bool {
        guard !showEditSheet, !fanIsOpen, !ai.isGenerating else { return false }
        return LayerActions(project: project, session: session).hasActiveLayers
    }

    private var quickActionsIdentity: String {
        if session.isMultiSelecting {
            return "multi-\(session.lassoSelectedLayerUUIDs.count)"
        }
        if let id = session.selectedLayerUUID {
            return "single-\(id.uuidString)"
        }
        return "none"
    }

    private var deleteFloatingButton: some View {
        Button {
            LayerActions(project: project, session: session).delete()
        } label: {
            Image(systemName: "trash")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.red, in: .circle)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete selected layers")
    }

    var body: some View {
        @Bindable var ai = ai
        GeometryReader { geo in
            let layersBarHeight: CGFloat = 48

            let fanButtonRowHeight: CGFloat = showEditSheet ? 0 : 76

            let topPadding: CGFloat = 16

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
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: topSpacer)
                        IconCanvasView(project: project, session: session)
                            .frame(width: iconSide, height: iconSide)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named(Self.editorSpaceName))
                            } action: { newFrame in
                                lasso.canvasFrame = newFrame
                            }
                        LayersBar(
                            project: project,
                            session: session,
                            onItemSelected: presentEditSheet,
                            coordinateSpaceName: Self.editorSpaceName,
                            onRowFrame: { uuid, frame in
                                lasso.layerRowFrames[uuid] = frame
                            },
                            onDragMove: { uuid, point in
                                handleLayerDragMove(uuid: uuid, editorPoint: point)
                            },
                            onDragEnd: { uuid in
                                handleLayerDragEnd(uuid: uuid)
                            }
                        )
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named(Self.editorSpaceName))
                        } action: { newFrame in
                            lasso.layersBarFrame = newFrame
                        }
                        Color.clear
                            .frame(height: fanButtonRowHeight + bottomSpacer)
                            .contentShape(Rectangle())
                            .overlay(alignment: .top) {
                                if showsQuickActionsBar {
                                    LayerQuickActionsCanvasBar(
                                        project: project,
                                        session: session
                                    )
                                    .id(quickActionsIdentity)
                                    .padding(.top, 4)
                                    .transition(
                                        .asymmetric(
                                            insertion: .scale(scale: 0.92, anchor: .top)
                                                .combined(with: .opacity),
                                            removal: .opacity
                                        )
                                    )
                                }
                            }
                            .animation(.spring(duration: 0.32, bounce: 0.25), value: showsQuickActionsBar)
                    }
                    .zIndex(trashArmed ? 1 : 0)
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

                    Group {
                        if session.isMultiSelecting {
                            deleteFloatingButton
                        } else {
                            ShapeFanButton(
                                items: fanItems,
                                isOpen: $fanIsOpen,
                                trashMode: trashArmed
                            )
                        }
                    }
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(Self.editorSpaceName))
                    } action: { newFrame in
                        lasso.fabFrame = newFrame
                    }
                    .padding(.bottom, 16)
                    .opacity(showEditSheet ? 0 : 1)
                    .scaleEffect(showEditSheet ? 0.4 : 1)
                    .animation(.spring(duration: 0.25, bounce: 0.2), value: showEditSheet)
                    .allowsHitTesting(!showEditSheet)
                    .zIndex(trashArmed ? 0 : 1)
                }
                .frame(width: geo.size.width, height: visibleHeight)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)

                if let rect = lasso.lassoRect {
                    LassoMarquee(rect: rect)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: Self.editorSpaceName)
            .contentShape(Rectangle())
            .gesture(lasso.dragGesture(project: project, session: session, spaceName: Self.editorSpaceName))
            .simultaneousGesture(lasso.clearTapGesture(session: session, spaceName: Self.editorSpaceName))
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
                                lasso.performBooleanOperation(op, project: project, session: session)
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
                            session.showGrid.toggle()
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Image(systemName: "grid")
                                .imageScale(.large)
                                .foregroundStyle(session.showGrid ? Color.primary : Color.secondary)
                        }
                        .accessibilityLabel(session.showGrid ? "Hide grid" : "Show grid")

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
                EditActionsMenu(
                    project: project,
                    session: session,
                    showImportPicker: $showImportPicker,
                    presentExport: presentExportSheet,
                    deleteProject: deleteCurrentProject
                )
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(ai.isGenerating ? .hidden : .visible, for: .navigationBar)
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
        .sheet(isPresented: $ai.showPromptSheet) {
            AIPromptSheet { subject, style, reference, transparent in
                ai.submit(
                    subject: subject,
                    style: style,
                    reference: reference,
                    transparent: transparent,
                    project: project,
                    session: session,
                    onSuccess: { presentEditSheet() }
                )
            }
        }
        .alert(
            "Add OpenAI API key",
            isPresented: $ai.showNoAPIKeyAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Open the gallery settings to add your OpenAI API key, then try again.")
        }
        .alert(
            "Generation failed",
            isPresented: Binding(
                get: { ai.generationError != nil },
                set: { if !$0 { ai.generationError = nil } }
            ),
            presenting: ai.generationError
        ) { _ in
            Button("OK", role: .cancel) { ai.generationError = nil }
        } message: { error in
            Text(error)
        }
        .overlay {
            if ai.isGenerating {
                GeneratingOverlay(
                    startDate: ai.generationStartDate,
                    total: AIFlowController.generationTimeoutSeconds
                )
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

            if !isPresented && wasEditSheetOpenBeforeExport && !showEditSheet {
                wasEditSheetOpenBeforeExport = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    showEditSheet = true
                }
            }
        }
        .onChange(of: exportSignature) { _, _ in

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

    private func reselectTopIfNeeded() {
        if let id = session.selectedLayerUUID, project.layer(withID: id) == nil {
            session.selectLayer(project.layers.last?.uuid)
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

    private func deleteCurrentProject() {
        let projectRef = project
        let storeRef = store
        showEditSheet = false
        dismiss()
        Task { @MainActor in
            await Task.yield()
            withAnimation(.smooth(duration: 0.35)) {
                storeRef.delete(projectRef)
            }
        }
    }

    private func persistSnapshotInBackground() {
        let projectRef = project
        let storeRef = store
        Task { @MainActor in

            await Task.yield()
            IconRenderer.updateThumbnail(projectRef)
            storeRef.save(projectRef)
        }
    }

    private func sheetCoverHeight(totalHeight: CGFloat) -> CGFloat {
        guard showEditSheet else { return 0 }
        if sheetDetent == .fraction(0.5) { return totalHeight * 0.5 }

        return totalHeight
    }

    private var exportSignature: Int {
        var hasher = Hasher()
        if let bg = project.background {
            hasher.combine(bg.kind)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for layer in project.layers {
            hasher.combine(layer.uuid)
            if let data = try? encoder.encode(layer) {
                hasher.combine(data)
            }
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
