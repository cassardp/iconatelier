import SwiftUI

/// Browse the public web gallery from inside the app and import an editable project
/// back into the local library. Read-only on the web; here icons can be added to "My Library".
struct CommunityGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var items: [CommunityIcon] = []
    @State private var nextCursor: Int?
    @State private var phase: Phase = .loading
    @State private var isLoadingMore = false

    enum Phase: Equatable {
        case loading, loaded, empty
        case failed(String)
    }

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 1024), spacing: 16)]

    var body: some View {
        NavigationStack {
            content
                .background(Color.appPageBackground.ignoresSafeArea())
                .navigationTitle("Gallery")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
                .navigationDestination(for: CommunityIcon.self) { icon in
                    CommunityIconDetailView(icon: icon) { removedID in
                        items.removeAll { $0.id == removedID }
                    }
                }
        }
        .task {
            if case .loading = phase { await loadInitial() }
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load the gallery", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await loadInitial() } }
                    .buttonStyle(.borderedProminent)
            }
        case .empty:
            ContentUnavailableView(
                "No icons yet",
                systemImage: "square.grid.2x2",
                description: Text("Icons published from IconAtelier will show up here.")
            )
        case .loaded:
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(items) { icon in
                    NavigationLink(value: icon) {
                        CommunityThumbnail(icon: icon)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if icon.id == items.last?.id { Task { await loadMore() } }
                    }
                }
            }
            .padding(20)

            if isLoadingMore {
                ProgressView()
                    .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await loadInitial() }
    }

    // MARK: - Loading

    private func loadInitial() async {
        do {
            let response = try await CommunityService().list(cursor: nil)
            items = response.items
            nextCursor = response.nextCursor
            phase = response.items.isEmpty ? .empty : .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await CommunityService().list(cursor: cursor)
            // Guard against duplicates if a page boundary shifts between requests.
            let known = Set(items.map(\.id))
            items.append(contentsOf: response.items.filter { !known.contains($0.id) })
            nextCursor = response.nextCursor
        } catch {
            // Keep what we have; pagination failures shouldn't blow away the grid.
            nextCursor = nil
        }
    }
}

// MARK: - Thumbnail

private struct CommunityThumbnail: View {
    let icon: CommunityIcon

    var body: some View {
        SquircleThumbnail {
            AsyncImage(url: URL(string: icon.pngURL), transaction: Transaction(animation: .default)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().interpolation(.medium)
                case .failure:
                    ThumbnailPlaceholder {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                case .empty:
                    ThumbnailPlaceholder { ProgressView() }
                @unknown default:
                    ThumbnailPlaceholder { ProgressView() }
                }
            }
        }
    }
}

// MARK: - Detail

struct CommunityIconDetailView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    let icon: CommunityIcon
    var onRemoved: ((String) -> Void)? = nil

    @State private var state: ImportState = .idle
    @State private var adminToken: String?
    @State private var showRemoveConfirm = false

    enum ImportState: Equatable {
        case idle, downloading, imported, alreadyInLibrary
        case failed(String)
    }

    private var appStoreURL: URL? {
        icon.appStoreURL.flatMap(URL.init(string:))
    }

    private var createdDate: Date {
        Date(timeIntervalSince1970: Double(icon.createdAt) / 1000)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                preview
                metadata
                if !icon.tags.isEmpty { tags }
                actions
            }
            .padding()
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color.appPageBackground.ignoresSafeArea())
        .navigationTitle(icon.title.isEmpty ? "Icon" : icon.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { adminToken = await CommunityCredentialStore.shared.adminToken() }
        .confirmationDialog(
            "Remove this icon from the gallery?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task { await removeFromGallery() }
            }
        } message: {
            Text("It will no longer appear in the public gallery.")
        }
    }

    // MARK: Sections

    private var preview: some View {
        AsyncImage(url: URL(string: icon.pngURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().interpolation(.high)
            case .failure:
                Color(uiColor: .secondarySystemBackground)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            default:
                Color(uiColor: .secondarySystemBackground)
                    .overlay { ProgressView() }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 240)
        .clipShape(SquircleShape())
        .overlay {
            SquircleShape().stroke(SeparatorShapeStyle().opacity(0.4), lineWidth: 1)
        }
    }

    private var metadata: some View {
        VStack(spacing: 6) {
            Text(icon.title.isEmpty ? "Untitled" : icon.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            if let author = icon.authorName, !author.isEmpty {
                Text("by \(author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                Text("\(icon.downloads) download\(icon.downloads == 1 ? "" : "s")")
                Text("·")
                Text(createdDate, format: .dateTime.month().day().year())
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
    }

    private var tags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(icon.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: .capsule)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            addButton

            if let appStoreURL {
                Button {
                    openURL(appStoreURL)
                } label: {
                    Label("View on the App Store", systemImage: "apple.logo")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.black)
                .controlSize(.large)
            }

            if adminToken != nil {
                Button(role: .destructive) {
                    showRemoveConfirm = true
                } label: {
                    Label("Remove from gallery", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            }

            if case .failed(let message) = state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        switch state {
        case .imported:
            Label("Added to your library", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: state)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        case .alreadyInLibrary:
            Label("Already in your library", systemImage: "checkmark.circle")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        default:
            Button {
                Task { await addToLibrary() }
            } label: {
                HStack {
                    if state == .downloading {
                        ProgressView().tint(.white)
                    } else {
                        Label("Remix", systemImage: "shuffle")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .controlSize(.large)
            .disabled(state == .downloading)
        }
    }

    // MARK: Actions

    private func addToLibrary() async {
        state = .downloading
        do {
            let zipURL = try await CommunityService().downloadProjectBundle(id: icon.id)
            defer { try? FileManager.default.removeItem(at: zipURL) }
            let summary = try LibraryImporter.importBundle(from: zipURL, into: store, asNewCopy: true)
            state = summary.importedCount > 0 ? .imported : .alreadyInLibrary
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func removeFromGallery() async {
        guard let token = adminToken else { return }
        do {
            try await CommunityService().moderate(id: icon.id, status: "removed", adminToken: token)
            onRemoved?(icon.id)
            dismiss()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
