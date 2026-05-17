import SwiftUI
import SwiftData
import ImageIO

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IconProject.createdAt, order: .reverse)
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

    private let horizontalSpacing: CGFloat = 16
    private let verticalSpacing: CGFloat = 20
    private let minColumns: Int = 2
    private let maxColumns: Int = 4

    private var pinchGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.05)
            .updating($pinchScale) { value, state, _ in
                let damped = 1 + (value.magnification - 1) * 0.15
                state = min(max(damped, 0.96), 1.04)
            }
            .onChanged { value in
                if !isPinching { isPinching = true }
                guard !pinchTriggered, !isSelecting else { return }
                if value.magnification > 1.25, columnCount > minColumns {
                    pinchTriggered = true
                    withAnimation(.snappy(duration: 0.32)) { columnCount -= 1 }
                } else if value.magnification < 0.8, columnCount < maxColumns {
                    pinchTriggered = true
                    withAnimation(.snappy(duration: 0.32)) { columnCount += 1 }
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
            ZStack(alignment: .bottom) {
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
                            UniformIconGridLayout(
                                columns: columnCount,
                                horizontalSpacing: horizontalSpacing,
                                verticalSpacing: verticalSpacing
                            ) {
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
                            .animation(.snappy(duration: 0.32), value: columnCount)
                            .animation(.smooth(duration: 0.35), value: projects.count)
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: pinchScale)
                        }
                        .scrollIndicators(.hidden)
                        .simultaneousGesture(pinchGesture)
                        .sensoryFeedback(.selection, trigger: columnCount)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomProgressiveBlur(expanded: false)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)

                Group {
                    if isSelecting {
                        deleteSelectedButton
                    } else {
                        newProjectButton
                    }
                }
                .padding(.bottom, 16)
            }
            .background(Color.appPageBackground.ignoresSafeArea())
            .toolbar {
                if !projects.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelecting ? "Cancel" : "Select") {
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
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .navigationDestination(for: ProjectRoute.self) { route in
                if let project = projects.first(where: { $0.uuid == route.projectUUID }) {
                    ContentView(project: project)
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
                path.append(ProjectRoute(projectUUID: project.uuid))
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
            // matchedTransitionSource is restricted to RoundedRectangle clip
            // shapes by SwiftUI, so the transition uses the .continuous
            // approximation. The settled cell itself uses SquircleShape.
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
        Button {
            createNewProject()
        } label: {
            Image(systemName: "plus")
                .font(.title.weight(.regular))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: 60, height: 60)
                .background(Color.primary, in: .circle)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: projects.count)
        .accessibilityLabel("Create new icon")
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
        withAnimation(.easeOut(duration: 0.12)) {
            if selectedUUIDs.contains(project.uuid) {
                selectedUUIDs.remove(project.uuid)
            } else {
                selectedUUIDs.insert(project.uuid)
            }
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
        let tropical = BackgroundPresets.mesh[8]
        project.background = Background(
            kind: .meshGradient,
            meshColors: tropical.meshColors
        )
        let silhouette = project.addShapeLayer(spec: .iosSquircle)
        silhouette.scale = 1.8
        silhouette.opacity = 0.4
        project.clearHistory()
        IconRenderer.updateThumbnail(project)
        modelContext.insert(project)
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
    }
}

private struct BottomProgressiveBlur: View {
    var expanded: Bool

    private var height: CGFloat { expanded ? 260 : 140 }

    var body: some View {
        Rectangle()
            .fill(.ultraThickMaterial)
            .mask(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.35), location: 0.45),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height)
                .frame(maxWidth: .infinity)
            }
            .animation(.smooth(duration: 0.32), value: expanded)
    }
}

// Non-lazy uniform square grid. All cells exist in the view tree at all
// times, so when the column count changes SwiftUI animates each cell from
// its old position to the new one instead of materializing/dematerializing
// cells (which would trigger insertion/removal transitions and feel janky).
private struct UniformIconGridLayout: Layout {
    let columns: Int
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let count = subviews.count
        guard count > 0, columns > 0 else { return CGSize(width: width, height: 0) }
        let cell = cellSide(for: width)
        let rows = (count + columns - 1) / columns
        let height = CGFloat(rows) * cell + CGFloat(max(0, rows - 1)) * verticalSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = cellSide(for: bounds.width)
        let cellProposal = ProposedViewSize(width: cell, height: cell)
        for (index, subview) in subviews.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = bounds.minX + CGFloat(col) * (cell + horizontalSpacing)
            let y = bounds.minY + CGFloat(row) * (cell + verticalSpacing)
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: cellProposal)
        }
    }

    private func cellSide(for width: CGFloat) -> CGFloat {
        let totalSpacing = horizontalSpacing * CGFloat(max(0, columns - 1))
        return max(0, (width - totalSpacing) / CGFloat(columns))
    }
}

private struct GalleryCell: View {
    let project: IconProject
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        thumbnail
            .aspectRatio(1, contentMode: .fit)
            .clipShape(SquircleShape())
            .overlay {
                SquircleShape()
                    .stroke(SeparatorShapeStyle().opacity(0.4), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelecting {
                    selectionBadge
                        .padding(10)
                }
            }
            .opacity(isSelecting && !isSelected ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var selectionBadge: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                isSelected ? Color.white : Color.white.opacity(0.95),
                isSelected ? Color.red : Color.black.opacity(0.25)
            )
            .font(.system(size: 26, weight: .semibold))
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(isSelected ? 1.0 : 0.94)
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
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
