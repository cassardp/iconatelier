import SwiftUI
import UIKit

struct ContentView: View {
    #if DEBUG
    @State private var project = IconProject.devSample()
    #else
    @State private var project = IconProject()
    #endif
    private let service = OpenAIImageService()

    @State private var activeTool: LayerTool = .opacity
    @State private var presentedTab: EditorTab?
    @State private var sheetDetent: PresentationDetent = .fraction(0.5)
    @State private var generationTarget: GenerationSheet.Target?
    @State private var exportedImage: UIImage?
    @State private var showingNewProjectConfirm = false

    var body: some View {
        NavigationStack {
            canvas
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
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(
                                item: Image(uiImage: exportedImage),
                                preview: SharePreview("Icon", image: Image(uiImage: exportedImage))
                            ) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            presentedTab = .layers
                        } label: {
                            Label(EditorTab.layers.title, systemImage: EditorTab.layers.symbol)
                        }

                        Button {
                            presentedTab = .tools
                        } label: {
                            Label(EditorTab.tools.title, systemImage: EditorTab.tools.symbol)
                        }

                        Spacer()

                        Menu {
                            Button {
                                generationTarget = .background
                            } label: {
                                Label(
                                    project.background == nil ? "Background" : "Replace background",
                                    systemImage: "photo"
                                )
                            }

                            Divider()

                            Button {
                                generationTarget = .overlay
                            } label: {
                                Label("Overlay", systemImage: "sparkles")
                            }
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }
                .toolbarBackground(.visible, for: .bottomBar)
                .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $presentedTab) { tab in
            EditorSheet(
                project: project,
                tab: tab,
                activeTool: $activeTool
            )
            .presentationDetents([.fraction(0.5), .large], selection: $sheetDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
        }
        .sheet(item: $generationTarget) { target in
            GenerationSheet(project: project, target: target, service: service)
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

    private var canvas: some View {
        GeometryReader { geo in
            IconCanvasView(project: project)
                .ignoresSafeArea(.keyboard)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, canvasBottomPadding(for: geo.size.height))
                .animation(.smooth(duration: 0.3), value: presentedTab)
                .animation(.smooth(duration: 0.3), value: sheetDetent)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func canvasBottomPadding(for height: CGFloat) -> CGFloat {
        guard presentedTab != nil else { return 0 }
        return sheetDetent == .large ? 0 : height * 0.5
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
