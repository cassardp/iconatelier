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
    @State private var showLayersPanel = false
    @State private var showToolsPanel = false

    @State private var promptText: String = ""
    @State private var isGenerating: Bool = false
    @State private var generationError: String?
    @FocusState private var promptFocused: Bool

    private let layersPanelWidth: CGFloat = 96
    private let toolsPanelWidth: CGFloat = 60
    private let gutter: CGFloat = 16

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

                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            toggleLayersPanel()
                        } label: {
                            Image(systemName: EditorTab.layers.symbol)
                                .symbolVariant(showLayersPanel ? .fill : .none)
                        }
                        .accessibilityLabel(EditorTab.layers.title)
                    }

                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                    }

                    ToolbarItem(placement: .bottomBar) {
                        promptField
                    }

                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                    }

                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            toggleToolsPanel()
                        } label: {
                            Image(systemName: EditorTab.tools.symbol)
                                .symbolVariant(showToolsPanel ? .fill : .none)
                        }
                        .accessibilityLabel(EditorTab.tools.title)
                    }
                }
                .toolbarBackground(.visible, for: .bottomBar)
                .navigationBarTitleDisplayMode(.inline)
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

    private var canvas: some View {
        HStack(spacing: 0) {
            if showLayersPanel {
                LayersSidePanel(project: project)
                    .frame(width: layersPanelWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            IconCanvasView(project: project, onSwipe: handleCanvasSwipe)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, showLayersPanel ? 0 : gutter)
                .padding(.trailing, gutter)

            if showToolsPanel {
                ToolsSidePanel(project: project)
                    .frame(width: toolsPanelWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var promptField: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Prompt", text: $promptText)
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .focused($promptFocused)
                .disabled(isGenerating)
                .onSubmit { submitPrompt() }

            if isGenerating {
                ProgressView().controlSize(.mini)
            } else if !trimmedPrompt.isEmpty {
                sendMenu
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sendMenu: some View {
        Menu {
            Button {
                generate(.background)
            } label: {
                Label(
                    project.background == nil ? "Background" : "Replace background",
                    systemImage: "photo"
                )
            }

            Button {
                generate(.overlay)
            } label: {
                Label("Overlay", systemImage: "sparkles")
            }
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel("Generate")
    }

    private var trimmedPrompt: String {
        promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggleLayersPanel() {
        withAnimation(.smooth(duration: 0.3)) {
            if showLayersPanel {
                showLayersPanel = false
            } else {
                showLayersPanel = true
                showToolsPanel = false
            }
        }
    }

    private func toggleToolsPanel() {
        withAnimation(.smooth(duration: 0.3)) {
            if showToolsPanel {
                showToolsPanel = false
            } else {
                showToolsPanel = true
                showLayersPanel = false
            }
        }
    }

    private func handleCanvasSwipe(_ direction: IconCanvasView.SwipeDirection) {
        switch direction {
        case .right:
            withAnimation(.smooth(duration: 0.3)) {
                if showToolsPanel {
                    showToolsPanel = false
                } else if !showLayersPanel {
                    showLayersPanel = true
                }
            }
        case .left:
            withAnimation(.smooth(duration: 0.3)) {
                if showLayersPanel {
                    showLayersPanel = false
                } else if !showToolsPanel {
                    showToolsPanel = true
                }
            }
        }
    }

    private func submitPrompt() {
        guard !trimmedPrompt.isEmpty else { return }
        let target: GenerationSheet.Target = project.background == nil ? .background : .overlay
        generate(target)
    }

    private func generate(_ target: GenerationSheet.Target) {
        let prompt = trimmedPrompt
        guard !prompt.isEmpty, !isGenerating else { return }
        isGenerating = true
        generationError = nil
        promptFocused = false
        Task {
            do {
                switch target {
                case .background:
                    let img = try await service.generateBackground(prompt: prompt)
                    project.setOrReplaceBackground(image: img, prompt: prompt)
                case .overlay:
                    let img = try await service.generateOverlay(prompt: prompt)
                    project.addOverlay(image: img, prompt: prompt)
                }
                promptText = ""
            } catch {
                generationError = error.localizedDescription
            }
            isGenerating = false
        }
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
