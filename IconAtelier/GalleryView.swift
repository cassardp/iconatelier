import SwiftUI
import SwiftData
import PhotosUI
import ImageIO
import UIKit

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IconProject.updatedAt, order: .reverse)
    private var projects: [IconProject]

    @State private var path = NavigationPath()
    @State private var renameTarget: IconProject?
    @State private var draftTitle: String = ""
    @State private var showSettings: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selectedUUIDs: Set<UUID> = []
    @AppStorage("galleryColumnCount") private var columnCount: Int = 3
    @Namespace private var galleryNamespace
    @State private var tileSide: CGFloat = 0
    @State private var pinchTriggered: Bool = false
    @State private var isPinching: Bool = false
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var showPhotosPicker: Bool = false
    @State private var photoPickerItems: [PhotosPickerItem] = []

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.05)
            .updating($pinchScale) { value, state, _ in
                // Very subtle live feedback so the grid hints at the pinch
                // direction without visibly resizing.
                let damped = 1 + (value.magnification - 1) * 0.15
                state = min(max(damped, 0.96), 1.04)
            }
            .onChanged { value in
                if !isPinching { isPinching = true }
                guard !pinchTriggered, !isSelecting else { return }
                if value.magnification > 1.25, columnCount > 2 {
                    pinchTriggered = true
                    withAnimation(.smooth(duration: 0.35)) { columnCount -= 1 }
                } else if value.magnification < 0.8, columnCount < 4 {
                    pinchTriggered = true
                    withAnimation(.smooth(duration: 0.35)) { columnCount += 1 }
                }
            }
            .onEnded { _ in
                pinchTriggered = false
                // Keep tap-suppression briefly so a finger lifted just after a
                // pinch doesn't fire a stray Button tap and open an icon.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isPinching = false
                }
            }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if projects.isEmpty {
                    VStack(spacing: 16) {
                        Text("Tap the + button")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Image(systemName: "arrow.down")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(projects) { project in
                                cell(for: project)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.6).combined(with: .opacity),
                                        removal: .opacity.animation(.easeOut(duration: 0.12))
                                    ))
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 80)
                        .scaleEffect(pinchScale, anchor: .center)
                        .animation(.smooth(duration: 0.35), value: columnCount)
                        .animation(.smooth(duration: 0.35), value: projects.count)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: pinchScale)
                    }
                    .simultaneousGesture(pinchGesture)
                    .sensoryFeedback(.selection, trigger: columnCount)
                }
            }
            .background(Color.appPageBackground.ignoresSafeArea())
            .toolbar {
                if !projects.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelecting ? "Done" : "Select") {
                            withAnimation(.smooth(duration: 0.35)) {
                                isSelecting.toggle()
                                if !isSelecting { selectedUUIDs.removeAll() }
                            }
                        }
                    }
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .disabled(isSelecting)
                }
            }
            .overlay(alignment: .bottom) {
                Group {
                    if isSelecting {
                        deleteSelectedButton
                    } else {
                        newProjectButton
                    }
                }
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $photoPickerItems,
                maxSelectionCount: 1,
                matching: .images
            )
            .onChange(of: photoPickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await handlePickedPhoto(items) }
            }
            .navigationDestination(for: ProjectRoute.self) { route in
                if let project = projects.first(where: { $0.uuid == route.projectUUID }) {
                    ContentView(project: project, initialIntent: route.intent)
                }
            }
            .alert(
                "Rename icon",
                isPresented: Binding(
                    get: { renameTarget != nil },
                    set: { if !$0 { renameTarget = nil } }
                )
            ) {
                TextField("Name", text: $draftTitle)
                Button("Save") {
                    if let project = renameTarget {
                        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { project.title = trimmed }
                    }
                    renameTarget = nil
                }
                Button("Cancel", role: .cancel) { renameTarget = nil }
            }
            .onChange(of: projects.count) { _, _ in
                if projects.isEmpty && isSelecting {
                    isSelecting = false
                    selectedUUIDs.removeAll()
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for project: IconProject) -> some View {
        Button {
            guard !isPinching else { return }
            if isSelecting {
                toggleSelection(project)
            } else {
                path.append(ProjectRoute(projectUUID: project.uuid, intent: nil))
            }
        } label: {
            GalleryCell(
                project: project,
                isSelecting: isSelecting,
                isSelected: selectedUUIDs.contains(project.uuid)
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newSide in
                if abs(newSide - tileSide) > 0.5 { tileSide = newSide }
            }
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: project.uuid, in: galleryNamespace) { config in
            config.clipShape(
                RoundedRectangle(
                    cornerRadius: max(tileSide, 1) * 0.2237,
                    style: .continuous
                )
            )
        }
        .contextMenu {
            if !isSelecting {
                Button {
                    draftTitle = project.title
                    renameTarget = project
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    duplicate(project)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Button(role: .destructive) {
                    delete(project)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var newProjectButton: some View {
        CreateRadialMenu(items: createItems)
    }

    private var createItems: [CreateActionItem] {
        [
            CreateActionItem(
                id: "photo",
                label: "Photo",
                systemImage: "camera.fill",
                color: .primary,
                action: { showPhotosPicker = true }
            ),
            CreateActionItem(
                id: "prompt",
                label: "Prompt",
                systemImage: "wand.and.stars",
                color: .primary,
                action: { createProjectAndOpen(intent: .prompt) }
            ),
            CreateActionItem(
                id: "voice",
                label: "Voice",
                systemImage: "mic.fill",
                color: .primary,
                action: {}
            ),
            CreateActionItem(
                id: "symbol",
                label: "Symbol",
                systemImage: "star.fill",
                color: .primary,
                action: { createProjectAndOpen(intent: .symbol) }
            ),
            CreateActionItem(
                id: "text",
                label: "Text",
                systemImage: "textformat",
                color: .primary,
                action: { createProjectAndOpen(intent: .text) }
            )
        ]
    }

    private var deleteSelectedButton: some View {
        Button {
            if !selectedUUIDs.isEmpty {
                deleteSelected()
            }
        } label: {
            Image(systemName: "trash")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(selectedUUIDs.isEmpty ? Color.gray.opacity(0.5) : Color.red, in: .circle)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .disabled(selectedUUIDs.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: selectedUUIDs.isEmpty)
        .accessibilityLabel(selectedUUIDs.count <= 1 ? "Delete selected icon" : "Delete \(selectedUUIDs.count) selected icons")
    }

    private func toggleSelection(_ project: IconProject) {
        if selectedUUIDs.contains(project.uuid) {
            selectedUUIDs.remove(project.uuid)
        } else {
            selectedUUIDs.insert(project.uuid)
        }
    }

    private func deleteSelected() {
        let targets = projects.filter { selectedUUIDs.contains($0.uuid) }
        withAnimation(.smooth(duration: 0.35)) {
            for project in targets {
                modelContext.delete(project)
            }
            isSelecting = false
        }
        try? modelContext.save()
        selectedUUIDs.removeAll()
    }

    private func createProjectAndOpen(intent: CreationIntent) {
        let project = makeProject(seedingFor: intent)
        path.append(ProjectRoute(projectUUID: project.uuid, intent: intent))
    }

    private func makeProject(seedingFor intent: CreationIntent) -> IconProject {
        let project = IconProject(title: "Untitled")
        let preset = BackgroundPresets.mesh.randomElement() ?? BackgroundPresets.mesh[0]
        project.background = Background(
            kind: .meshGradient,
            meshColors: preset.meshColors
        )
        // Only seed a default text layer for the Text intent so the project has
        // visible content immediately. The other intents add their own layer
        // (or a generation) inside the editor.
        if case .text = intent {
            project.addTextOverlay(text: "New")
        }
        project.clearHistory()
        IconRenderer.updateThumbnail(project)
        withAnimation(.smooth(duration: 0.35)) {
            modelContext.insert(project)
        }
        try? modelContext.save()
        return project
    }

    private func handlePickedPhoto(_ items: [PhotosPickerItem]) async {
        guard let first = items.first else { return }
        let data = try? await first.loadTransferable(type: Data.self)
        await MainActor.run {
            photoPickerItems = []
            guard let data, UIImage(data: data) != nil else { return }
            let project = makeProject(seedingFor: .photo(data))
            path.append(ProjectRoute(projectUUID: project.uuid, intent: .photo(data)))
        }
    }

    private func duplicate(_ project: IconProject) {
        let copy = project.duplicated()
        modelContext.insert(copy)
        try? modelContext.save()
    }

    private func delete(_ project: IconProject) {
        withAnimation(.smooth(duration: 0.35)) {
            modelContext.delete(project)
        }
        try? modelContext.save()
    }
}

private struct AppIconSquircle: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.2237
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

private struct GalleryCell: View {
    let project: IconProject
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        thumbnail
            .aspectRatio(1, contentMode: .fit)
            .clipShape(AppIconSquircle())
            .overlay {
                AppIconSquircle()
                    .stroke(SeparatorShapeStyle().opacity(0.4), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelecting {
                    selectionBadge
                        .padding(10)
                }
            }
            .opacity(isSelecting && !isSelected ? 0.85 : 1)
    }

    private var selectionBadge: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                isSelected ? Color.white : Color.white.opacity(0.95),
                isSelected ? Color.red : Color.black.opacity(0.25)
            )
            .font(.system(size: 26, weight: .semibold))
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = project.thumbnailPNG,
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            Image(decorative: cgImage, scale: 1)
                .resizable()
                .interpolation(.medium)
        } else {
            ZStack {
                LinearGradient(
                    colors: [.gray.opacity(0.2), .gray.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
