import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var project: IconProject

    @State private var session = ProjectSession()
    @State private var showEditSheet = true
    @State private var showExportSheet = false
    @State private var sheetDetent: PresentationDetent = Self.peekDetent

    @State private var showImportPicker: Bool = false

    private static let peekHeight: CGFloat = 100
    private static let peekDetent: PresentationDetent = .height(100)

    // Lasso multi-selection (Phase 1)
    @State private var canvasFrame: CGRect = .zero
    @State private var layersBarFrame: CGRect = .zero
    @State private var lassoRect: CGRect? = nil
    private static let editorSpaceName = "iconAtelierEditor"

    var body: some View {
        GeometryReader { geo in
            let layersBarHeight: CGFloat = 56 + 16
            let layersBarBottomInset: CGFloat = 8  // internal LayersBar verticalPadding
            // Minimum air to keep above the icon and below the layers bar in
            // the 0.5 detent so the block isn't crammed against the sheet.
            let minVerticalMargin: CGFloat = 20
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
            let iconHeight = max(0, visibleHeight - layersBarHeight - 2 * minVerticalMargin)
            let iconSide = max(0, min(geo.size.width - 32, iconHeight))
            // Center icon+layers in visibleHeight, but bias the bottom spacer
            // down by 8pt so the visible whitespace above the icon equals the
            // whitespace below the last thumbnail (LayersBar carries an 8pt
            // internal bottom padding).
            let totalContent = iconSide + layersBarHeight
            let leftover = max(0, visibleHeight - totalContent)
            let bottomSpacer = max(0, (leftover - layersBarBottomInset) / 2)
            let topSpacer = max(0, leftover - bottomSpacer)
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
                        onAddShape: { addShapeLayer(spec: .defaultShape) },
                        onAddText: addTextLayer,
                        onImportImage: { showImportPicker = true }
                    )
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(Self.editorSpaceName))
                    } action: { newFrame in
                        layersBarFrame = newFrame
                    }
                    Color.clear.frame(height: bottomSpacer)
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
                session: session,
                onBooleanOp: performBooleanOperation
            )
            .presentationDetents(
                [Self.peekDetent, .fraction(0.5), .large],
                selection: $sheetDetent
            )
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(project: project)
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.png],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .onChange(of: showExportSheet) { _, isPresented in
            // The edit sheet is normally always open. We close it while the
            // export sheet is on screen (iOS allows only one sheet from a given
            // anchor), then re-open it once export is dismissed.
            if !isPresented && !showEditSheet {
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
            project.clearHistory()
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
        case .emoji, .text, .parametricShape: return 0.5
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

    private func addShapeLayer(spec: ShapeSpec) {
        withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
            let layer = project.addShapeLayer(spec: spec)
            session.selectLayer(layer.uuid)
        }
    }

    private func addTextLayer() {
        withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
            let layer = project.addTextOverlay()
            session.selectLayer(layer.uuid)
        }
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
        sheetDetent = .fraction(0.5)
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

    /// Height (in points) that the sheet visually claims from the bottom of
    /// the *full* window for the current detent. The caller projects this
    /// into geo space if needed.
    private func sheetCoverHeight(totalHeight: CGFloat) -> CGFloat {
        guard showEditSheet else { return 0 }
        if sheetDetent == Self.peekDetent { return Self.peekHeight }
        if sheetDetent == .fraction(0.5) { return totalHeight * 0.5 }
        // .large covers (almost) everything — clamp so the canvas can collapse
        // without producing negative dimensions.
        return totalHeight
    }

    private var exportSignature: Int {
        var hasher = Hasher()
        if let bg = project.background {
            hasher.combine(bg.kindRaw)
            hasher.combine(bg.isHidden)
        }
        for layer in project.layers {
            hasher.combine(layer.uuid)
            hasher.combine(layer.kindRaw)
            hasher.combine(layer.imagePNG?.hashValue ?? 0)
            hasher.combine(layer.emoji)
            hasher.combine(layer.text)
            hasher.combine(layer.shapeSpecJSON?.hashValue ?? 0)
            hasher.combine(layer.cornerRadius)
            hasher.combine(layer.borderWidth)
            hasher.combine(layer.storedBorderColor)
            hasher.combine(layer.borderPositionRaw)
            hasher.combine(layer.storedTintColor)
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
