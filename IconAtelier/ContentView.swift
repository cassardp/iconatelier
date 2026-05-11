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
    @State private var exportedImage: UIImage?
    @State private var showEditSheet = false
    @State private var sheetDetent: PresentationDetent = .fraction(0.5)
    @State private var isFocusMode = false
    @State private var dismissAfterSheetClose = false

    var body: some View {
        GeometryReader { geo in
            let layersBarHeight: CGFloat = isFocusMode ? 0 : 56 + 16
            let verticalMargin: CGFloat = sheetFraction > 0 ? 8 : 0
            let visibleHeight = max(0, geo.size.height * (1 - sheetFraction))
            let blockHeight = max(0, visibleHeight - verticalMargin * 2)
            let iconHeight = max(0, blockHeight - layersBarHeight)
            let iconSide = max(0, min(geo.size.width - 32, iconHeight))
            ZStack(alignment: .top) {
                if isFocusMode {
                    HomeScreenPreview(project: project)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        IconCanvasView(project: project, session: session)
                            .frame(width: iconSide, height: iconSide)
                        LayersBar(
                            project: project,
                            session: session,
                            isSheetOpen: $showEditSheet
                        )
                        .transition(.opacity)
                        Spacer(minLength: 0)
                    }
                    .frame(width: geo.size.width, height: visibleHeight)
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture {
                if isFocusMode {
                    withAnimation(.smooth(duration: 0.35)) { isFocusMode = false }
                }
            }
            .animation(.smooth(duration: 0.35), value: visibleHeight)
            .animation(.smooth(duration: 0.35), value: isFocusMode)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
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

            if project.hasContent, let exportedImage {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: Image(uiImage: exportedImage),
                        preview: SharePreview("Icon", image: Image(uiImage: exportedImage))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button {
                    withAnimation(.smooth(duration: 0.35)) {
                        isFocusMode.toggle()
                    }
                } label: {
                    Image(systemName: isFocusMode
                        ? "xmark"
                        : "eye")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(isFocusMode ? "Exit focus mode" : "Focus mode")
            }
        }
        .toolbar(isFocusMode ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(isFocusMode ? .hidden : .visible, for: .bottomBar)
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showEditSheet, onDismiss: {
            if dismissAfterSheetClose {
                dismissAfterSheetClose = false
                dismiss()
            }
        }) {
            EditSheet(project: project, session: session, service: service)
                .presentationDetents([.fraction(0.5), .large], selection: $sheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showEditSheet) { wasOpen, isOpen in
            if isOpen && !wasOpen { sheetDetent = .fraction(0.5) }
        }
        .onChange(of: exportSignature) { _, _ in
            exportedImage = IconRenderer.render(project, side: 1024)
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
            exportedImage = IconRenderer.render(project, side: 1024)
        }
        .onDisappear {
            IconRenderer.updateThumbnail(project)
            try? modelContext.save()
        }
    }

    private func closeProject() {
        IconRenderer.updateThumbnail(project)
        try? modelContext.save()
        if showEditSheet {
            dismissAfterSheetClose = true
            showEditSheet = false
        } else {
            dismiss()
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
        }
        return hasher.finalize()
    }
}
