import SwiftUI
import SwiftData
import ImageIO

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IconProject.updatedAt, order: .reverse)
    private var projects: [IconProject]

    @State private var path = NavigationPath()
    @State private var deletionTarget: IconProject?
    @State private var renameTarget: IconProject?
    @State private var draftTitle: String = ""
    @State private var showSettings: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selectedUUIDs: Set<UUID> = []
    @State private var showBulkDeletion: Bool = false
    @AppStorage("galleryColumnCount") private var columnCount: Int = 2
    @Namespace private var galleryNamespace
    @State private var tileSide: CGFloat = 0
    @State private var pinchTriggered: Bool = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    private var columnsIconName: String {
        columnCount >= 4 ? "plus.magnifyingglass" : "minus.magnifyingglass"
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.05)
            .onChanged { value in
                guard !pinchTriggered, !isSelecting else { return }
                if value.magnification > 1.25, columnCount > 2 {
                    pinchTriggered = true
                    withAnimation(.smooth(duration: 0.35)) { columnCount -= 1 }
                } else if value.magnification < 0.8, columnCount < 4 {
                    pinchTriggered = true
                    withAnimation(.smooth(duration: 0.35)) { columnCount += 1 }
                }
            }
            .onEnded { _ in pinchTriggered = false }
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
                                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 80)
                        .animation(.smooth(duration: 0.35), value: columnCount)
                        .animation(.smooth(duration: 0.35), value: projects.count)
                    }
                    .simultaneousGesture(pinchGesture)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .disabled(isSelecting)
                }
                if !projects.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelecting ? "Done" : "Select") {
                            withAnimation(.smooth(duration: 0.35)) {
                                isSelecting.toggle()
                                if !isSelecting { selectedUUIDs.removeAll() }
                            }
                        }
                    }
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.smooth(duration: 0.35)) {
                                columnCount = columnCount >= 4 ? 2 : columnCount + 1
                            }
                        } label: {
                            Image(systemName: columnsIconName)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityLabel("Change column count")
                        .disabled(isSelecting)
                    }
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
            .navigationDestination(for: IconProject.self) { project in
                ContentView(project: project)
                    .navigationTransition(.zoom(sourceID: project.uuid, in: galleryNamespace))
            }
            .confirmationDialog(
                "Delete this icon?",
                isPresented: Binding(
                    get: { deletionTarget != nil },
                    set: { if !$0 { deletionTarget = nil } }
                ),
                titleVisibility: .visible,
                presenting: deletionTarget
            ) { project in
                Button("Delete", role: .destructive) {
                    delete(project)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This cannot be undone.")
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
            .confirmationDialog(
                selectedUUIDs.count <= 1
                    ? "Delete this icon?"
                    : "Delete \(selectedUUIDs.count) icons?",
                isPresented: $showBulkDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
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
            if isSelecting {
                toggleSelection(project)
            } else {
                path.append(project)
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
                    deletionTarget = project
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var newProjectButton: some View {
        Button {
            createNewProject()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: 60, height: 60)
                .background(Color.primary, in: .circle)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .accessibilityLabel("New icon")
    }

    private var deleteSelectedButton: some View {
        Button {
            if !selectedUUIDs.isEmpty {
                showBulkDeletion = true
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

    private func createNewProject() {
        let project = IconProject(title: "Untitled")
        let preset = BackgroundPresets.mesh.randomElement() ?? BackgroundPresets.mesh[0]
        project.background = Background(
            kind: .meshGradient,
            meshColors: preset.meshColors
        )
        project.addTextOverlay()
        project.clearHistory()
        IconRenderer.updateThumbnail(project)
        withAnimation(.smooth(duration: 0.35)) {
            modelContext.insert(project)
        }
        try? modelContext.save()
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
        deletionTarget = nil
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
