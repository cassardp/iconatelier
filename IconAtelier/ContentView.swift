import SwiftUI
import UIKit

struct ContentView: View {
    #if DEBUG
    @State private var project = IconProject.devSample()
    #else
    @State private var project = IconProject()
    #endif
    private let service = OpenAIImageService()

    @State private var exportedImage: UIImage?
    @State private var showingNewProjectConfirm = false
    @State private var showEditSheet = false
    @State private var sheetDetent: PresentationDetent = .fraction(0.5)

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let layersBarHeight: CGFloat = project.hasContent ? (56 + 16) : 0
                let verticalMargin: CGFloat = sheetFraction > 0 ? 8 : 0
                let visibleHeight = max(0, geo.size.height * (1 - sheetFraction))
                let blockHeight = max(0, visibleHeight - verticalMargin * 2)
                let iconHeight = max(0, blockHeight - layersBarHeight)
                let iconSide = max(0, min(geo.size.width - 32, iconHeight))
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    IconCanvasView(project: project)
                        .frame(width: iconSide, height: iconSide)
                    if project.hasContent {
                        LayersBar(
                            project: project,
                            onAddLayer: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    project.addEmptyOverlay()
                                }
                            },
                            onSelectLayer: {
                                sheetDetent = .fraction(0.5)
                                showEditSheet = true
                            }
                        )
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: visibleHeight)
                .animation(.smooth(duration: 0.3), value: visibleHeight)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingNewProjectConfirm = true
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
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

                if project.hasContent, let exportedImage {
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: Image(uiImage: exportedImage),
                            preview: SharePreview("Icon", image: Image(uiImage: exportedImage))
                        ) {
                            Text("Export")
                        }
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "paintbrush.pointed.fill")
                    }
                    .accessibilityLabel("Edit")
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showEditSheet) {
            EditSheet(project: project, service: service)
                .presentationDetents([.fraction(0.5), .large], selection: $sheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
                .presentationDragIndicator(.visible)
        }
        .onChange(of: exportSignature) { _, _ in
            exportedImage = renderedIcon()
        }
        .onAppear {
            exportedImage = renderedIcon()
        }
        .confirmationDialog(
            "Start a new project?",
            isPresented: $showingNewProjectConfirm,
            titleVisibility: .visible
        ) {
            Button("New project", role: .destructive) {
                project = IconProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will discard the current icon.")
        }
    }

    private var sheetFraction: CGFloat {
        (showEditSheet && sheetDetent == .fraction(0.5)) ? 0.5 : 0
    }

    private var exportSignature: Int {
        var hasher = Hasher()
        for layer in project.layers {
            hasher.combine(layer.id)
            hasher.combine(layer.image?.hash ?? 0)
            hasher.combine(layer.scale)
            hasher.combine(layer.rotation.radians)
            hasher.combine(layer.offset.width)
            hasher.combine(layer.offset.height)
            hasher.combine(layer.opacity)
            hasher.combine(layer.isHidden)
        }
        return hasher.finalize()
    }

    private func renderedIcon() -> UIImage? {
        guard project.hasContent else { return nil }

        let exportSide: CGFloat = 1024

        let view = ZStack {
            ForEach(project.layers) { layer in
                if !layer.isHidden, let image = layer.image {
                    if layer.fillsCanvas {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: exportSide, height: exportSide)
                            .clipped()
                            .opacity(layer.opacity)
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: exportSide * 0.7 * layer.scale,
                                height: exportSide * 0.7 * layer.scale
                            )
                            .rotationEffect(layer.rotation)
                            .opacity(layer.opacity)
                            .position(
                                x: exportSide / 2 + layer.offset.width * exportSide,
                                y: exportSide / 2 + layer.offset.height * exportSide
                            )
                    }
                }
            }
        }
        .frame(width: exportSide, height: exportSide)
        .compositingGroup()

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = .init(width: exportSide, height: exportSide)
        return renderer.uiImage
    }
}
