import SwiftUI
import UIKit

struct ContentView: View {
    @State private var project = IconProject()
    private let service = OpenAIImageService()

    @State private var showingLayers = false
    @State private var showingTools = false
    @State private var showingInspector = false
    @State private var pendingGeneration: GenerationSheet.Target?
    @State private var exportedImage: UIImage?

    var body: some View {
        ZStack {
            IconCanvasView(
                project: project,
                onTapLayer: handleTapLayer
            )

            VStack {
                topBar
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .zIndex(2)

            sideButtons
                .padding(.horizontal, 16)
                .zIndex(2)

            if showingLayers {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy) { showingLayers = false }
                    }
                    .transition(.opacity)
                    .zIndex(3)
            }

            if showingLayers {
                HStack {
                    LayersPanel(
                        project: project,
                        onClose: {
                            withAnimation(.snappy) { showingLayers = false }
                        },
                        onAddLayer: {
                            withAnimation(.snappy) { showingLayers = false }
                            showingTools = true
                        }
                    )
                    .padding(.leading, 12)
                    .padding(.top, 90)
                    .padding(.bottom, 110)
                    Spacer()
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(4)
            }
        }
        .animation(.snappy, value: showingLayers)
        .onChange(of: exportSignature) { _, _ in
            exportedImage = renderedIcon()
        }
        .onAppear {
            exportedImage = renderedIcon()
        }
        .sheet(isPresented: $showingTools) {
            ToolsPalette(hasBackground: project.background != nil) { tool in
                switch tool {
                case .generateBackground: pendingGeneration = .background
                case .generateOverlay: pendingGeneration = .overlay
                }
            }
        }
        .sheet(item: $pendingGeneration) { target in
            GenerationSheet(project: project, target: target, service: service)
        }
        .sheet(isPresented: $showingInspector) {
            if let layer = project.selectedLayer {
                LayerInspectorSheet(layer: layer, project: project)
            }
        }
    }

    @ViewBuilder
    private var topBar: some View {
        HStack {
            Spacer()
            if let exported = exportedImage {
                ShareLink(
                    item: Image(uiImage: exported),
                    preview: SharePreview("Icon", image: Image(uiImage: exported))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: .circle)
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sideButtons: some View {
        HStack {
            FloatingIconButton(systemName: "square.3.stack.3d") {
                withAnimation(.snappy) { showingLayers.toggle() }
            }
            Spacer()
            FloatingIconButton(systemName: "paintbrush.pointed.fill") {
                showingTools = true
            }
        }
    }

    private func handleTapLayer(_ layer: Layer) {
        if project.selectedLayerID == layer.id {
            showingInspector = true
        } else {
            project.selectedLayerID = layer.id
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
