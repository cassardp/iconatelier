import SwiftUI
import UIKit

struct ContentView: View {
    @State private var project = IconProject()
    private let service = OpenAIImageService()

    @State private var dragOffset: CGSize = .zero
    @GestureState private var magnify: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    canvas
                        .padding(.horizontal)

                    if project.background != nil || project.overlay != nil {
                        controls
                            .padding(.horizontal)
                    }

                    promptSection(
                        title: "Fond (gpt-image-2)",
                        prompt: $project.backgroundPrompt,
                        isLoading: project.isGeneratingBackground,
                        action: generateBackground
                    )

                    promptSection(
                        title: "Élément transparent (gpt-image-1.5)",
                        prompt: $project.overlayPrompt,
                        isLoading: project.isGeneratingOverlay,
                        action: generateOverlay
                    )

                    if let error = project.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Icon Atelier")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let exported = renderedIcon() {
                        ShareLink(
                            item: Image(uiImage: exported),
                            preview: SharePreview("Icône", image: Image(uiImage: exported))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if let bg = project.background {
                    Image(uiImage: bg)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.secondarySystemBackground))
                        .overlay {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                        }
                }

                if let ov = project.overlay {
                    Image(uiImage: ov)
                        .resizable()
                        .scaledToFit()
                        .frame(width: side * 0.7, height: side * 0.7)
                        .scaleEffect(project.overlayScale * magnify)
                        .opacity(project.overlayOpacity)
                        .offset(
                            x: project.overlayOffset.width + dragOffset.width,
                            y: project.overlayOffset.height + dragOffset.height
                        )
                        .gesture(dragGesture)
                        .gesture(magnifyGesture)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                project.overlayOffset.width += value.translation.width
                project.overlayOffset.height += value.translation.height
                dragOffset = .zero
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnify) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                project.overlayScale *= value.magnification
                project.overlayScale = max(0.1, min(project.overlayScale, 4.0))
            }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if project.overlay != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Échelle")
                        Spacer()
                        Text(String(format: "%.2f×", project.overlayScale))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $project.overlayScale, in: 0.1...4.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Opacité")
                        Spacer()
                        Text(String(format: "%.0f%%", project.overlayOpacity * 100))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $project.overlayOpacity, in: 0...1)
                }

                Button("Recentrer l'élément") {
                    project.overlayOffset = .zero
                    project.overlayScale = 1.0
                }
                .font(.footnote)
            }
        }
    }

    // MARK: - Prompts

    private func promptSection(
        title: String,
        prompt: Binding<String>,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextField("Décris l'image…", text: prompt, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            Button {
                action()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isLoading ? "Génération…" : "Générer")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || prompt.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
    }

    // MARK: - Generation

    private func generateBackground() {
        Task {
            project.isGeneratingBackground = true
            project.lastError = nil
            do {
                project.background = try await service.generateBackground(prompt: project.backgroundPrompt)
            } catch {
                project.lastError = error.localizedDescription
            }
            project.isGeneratingBackground = false
        }
    }

    private func generateOverlay() {
        Task {
            project.isGeneratingOverlay = true
            project.lastError = nil
            do {
                project.overlay = try await service.generateOverlay(prompt: project.overlayPrompt)
            } catch {
                project.lastError = error.localizedDescription
            }
            project.isGeneratingOverlay = false
        }
    }

    // MARK: - Export

    private func renderedIcon() -> UIImage? {
        guard project.background != nil else { return nil }

        let exportSide: CGFloat = 1024
        let canvasSide: CGFloat = 1024

        let view = ZStack {
            if let bg = project.background {
                Image(uiImage: bg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: canvasSide, height: canvasSide)
                    .clipped()
            }
            if let ov = project.overlay {
                Image(uiImage: ov)
                    .resizable()
                    .scaledToFit()
                    .frame(width: canvasSide * 0.7, height: canvasSide * 0.7)
                    .scaleEffect(project.overlayScale)
                    .opacity(project.overlayOpacity)
                    .offset(
                        x: project.overlayOffset.width,
                        y: project.overlayOffset.height
                    )
            }
        }
        .frame(width: canvasSide, height: canvasSide)

        let renderer = ImageRenderer(content: view)
        renderer.scale = exportSide / canvasSide
        renderer.proposedSize = .init(width: canvasSide, height: canvasSide)
        return renderer.uiImage
    }
}
