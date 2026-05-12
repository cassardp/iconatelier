import SwiftUI
import SwiftData
import UIKit

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IconProject.updatedAt, order: .reverse)
    private var projects: [IconProject]

    @State private var path = NavigationPath()
    @State private var deletionTarget: IconProject?
    @State private var renameTarget: IconProject?
    @State private var draftTitle: String = ""
    @State private var showSettings: Bool = false

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if projects.isEmpty {
                    ContentUnavailableView {
                        Label("No icons yet", systemImage: "square.dashed")
                    } description: {
                        Text("Tap + to start designing your first icon.")
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(projects) { project in
                                NavigationLink(value: project) {
                                    GalleryCell(project: project)
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
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Icon Atelier")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .overlay(alignment: .bottom) {
                newProjectButton
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

    private func createNewProject() {
        let project = IconProject(title: "Untitled")
        project.background = Background()
        modelContext.insert(project)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.separator.opacity(0.4), lineWidth: 1)
                }

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

    @ViewBuilder
    private var thumbnail: some View {
        if let data = project.thumbnailPNG, let image = UIImage(data: data) {
            Image(uiImage: image)
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
