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

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)
    ]

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
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 80)
                    }
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
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSelecting.toggle()
                                if !isSelecting { selectedUUIDs.removeAll() }
                            }
                        }
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
        if isSelecting {
            Button {
                toggleSelection(project)
            } label: {
                GalleryCell(
                    project: project,
                    isSelecting: true,
                    isSelected: selectedUUIDs.contains(project.uuid)
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: project) {
                GalleryCell(project: project, isSelecting: false, isSelected: false)
            }
            .buttonStyle(.plain)
            .contextMenu {
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
        for project in targets {
            modelContext.delete(project)
        }
        try? modelContext.save()
        selectedUUIDs.removeAll()
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelecting = false
        }
    }

    private func createNewProject() {
        let project = IconProject(title: "Untitled")
        let preset = BackgroundPresets.mesh.randomElement() ?? BackgroundPresets.mesh[0]
        project.background = Background(
            kind: .meshGradient,
            meshColors: preset.meshColors
        )
        modelContext.insert(project)
        project.addTextOverlay()
        project.clearHistory()
        try? modelContext.save()
        path.append(project)
    }

    private func duplicate(_ project: IconProject) {
        let copy = project.duplicated()
        modelContext.insert(copy)
        try? modelContext.save()
    }

    private func delete(_ project: IconProject) {
        modelContext.delete(project)
        try? modelContext.save()
        deletionTarget = nil
    }
}

private struct GalleryCell: View {
    let project: IconProject
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SeparatorShapeStyle().opacity(0.4), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelecting {
                        selectionBadge
                            .padding(10)
                    }
                }
                .opacity(isSelecting && !isSelected ? 0.85 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(project.updatedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
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
