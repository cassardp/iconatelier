import SwiftUI
import UniformTypeIdentifiers

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProjectStore.self) private var store

    @AppStorage("authorName") private var authorName: String = ""

    @State private var apiKey: String = ""
    @State private var didLoadKey: Bool = false
    @State private var isSavingKey: Bool = false
    @State private var isKeyRevealed: Bool = false

    @State private var isExporting: Bool = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    @State private var isImporting: Bool = false
    @State private var isPickingImport: Bool = false
    @State private var importResult: ImportResult?
    @State private var importError: String?

    @State private var adminToken: String = ""
    @State private var didLoadAdmin: Bool = false
    @State private var showAdminSection: Bool = false
    @State private var isAdminRevealed: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $authorName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                } header: {
                    Text("Author")
                } footer: {
                    Text("Used as the author when you share an icon to the gallery. You can still change it for each icon.")
                }

                Section {
                    HStack {
                        Group {
                            if isKeyRevealed {
                                TextField("sk-...", text: $apiKey)
                            } else {
                                SecureField("sk-...", text: $apiKey)
                            }
                        }
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(saveAPIKey)

                        Button {
                            isKeyRevealed.toggle()
                        } label: {
                            Image(systemName: isKeyRevealed ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isKeyRevealed ? "Hide API key" : "Show API key")

                        Button("Save", action: saveAPIKey)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!didLoadKey || isSavingKey)
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Stored securely in the iOS Keychain on this device. Used to generate icons via OpenAI.")
                }

                Section {
                    Button(action: exportLibrary) {
                        backupRow(
                            title: "Export Library",
                            systemImage: "square.and.arrow.up",
                            busy: isExporting
                        )
                    }
                    .disabled(isExporting || isImporting)

                    Button {
                        isPickingImport = true
                    } label: {
                        backupRow(
                            title: "Import Library",
                            systemImage: "square.and.arrow.down",
                            busy: isImporting
                        )
                    }
                    .disabled(isExporting || isImporting)
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Back up your projects to a zip file you can share via Files, AirDrop, or email. Importing skips projects already in your library.")
                }

                if showAdminSection {
                    Section {
                        HStack {
                            Group {
                                if isAdminRevealed {
                                    TextField("Admin token", text: $adminToken)
                                } else {
                                    SecureField("Admin token", text: $adminToken)
                                }
                            }
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            .onSubmit(saveAdminToken)

                            Button {
                                isAdminRevealed.toggle()
                            } label: {
                                Image(systemName: isAdminRevealed ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isAdminRevealed ? "Hide admin token" : "Show admin token")

                            Button("Save", action: saveAdminToken)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!didLoadAdmin)
                        }

                        if !adminToken.isEmpty {
                            Button("Disable admin", role: .destructive, action: clearAdmin)
                        }
                    } header: {
                        Text("Gallery Admin")
                    } footer: {
                        Text("Moderation token, stored in the Keychain on this device only. Lets you remove icons from the public gallery.")
                    }
                }

                Section {
                } footer: {
                    HStack {
                        Spacer()
                        Text(versionText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.2) {
                        showAdminSection = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard !didLoadKey else { return }
                apiKey = await APIKeyStore.shared.load() ?? ""
                didLoadKey = true

                adminToken = await CommunityCredentialStore.shared.adminToken() ?? ""
                if !adminToken.isEmpty { showAdminSection = true }
                didLoadAdmin = true
            }
            .sheet(item: $exportFile) { file in
                ExportShareView(file: file)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $importResult) { result in
                ImportSuccessView(result: result)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .fileImporter(
                isPresented: $isPickingImport,
                allowedContentTypes: [.zip],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { importLibrary(from: url) }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert(
                "Export failed",
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                ),
                presenting: exportError
            ) { _ in
                Button("OK", role: .cancel) { exportError = nil }
            } message: { error in
                Text(error)
            }
            .alert(
                "Import failed",
                isPresented: Binding(
                    get: { importError != nil },
                    set: { if !$0 { importError = nil } }
                ),
                presenting: importError
            ) { _ in
                Button("OK", role: .cancel) { importError = nil }
            } message: { error in
                Text(error)
            }
        }
    }

    @ViewBuilder
    private func backupRow(title: String, systemImage: String, busy: Bool) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
            }
            Spacer()
            if busy {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isSavingKey = true
        Task {
            await APIKeyStore.shared.save(trimmed)
            await MainActor.run { isSavingKey = false }
        }
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "v\(version)" : "v\(version) (\(build))"
    }

    private func saveAdminToken() {
        let trimmed = adminToken.trimmingCharacters(in: .whitespacesAndNewlines)
        adminToken = trimmed
        Task { await CommunityCredentialStore.shared.saveAdminToken(trimmed) }
    }

    private func clearAdmin() {
        adminToken = ""
        showAdminSection = false
        Task { await CommunityCredentialStore.shared.clearAdminToken() }
    }

    private func exportLibrary() {
        guard !isExporting else { return }
        isExporting = true
        Task { @MainActor in
            defer { isExporting = false }
            do {
                let projects = store.projects.sorted { $0.createdAt < $1.createdAt }
                let url = try LibraryExporter.buildBundle(projects: projects)
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                exportFile = ExportFile(
                    url: url,
                    projectCount: projects.count,
                    byteSize: size
                )
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    private func importLibrary(from url: URL) {
        guard !isImporting else { return }
        isImporting = true
        Task { @MainActor in
            defer { isImporting = false }
            let needsScopedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if needsScopedAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let summary = try LibraryImporter.importBundle(
                    from: url,
                    into: store
                )
                importResult = ImportResult(
                    importedCount: summary.importedCount,
                    skippedCount: summary.skippedCount
                )
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}

// MARK: - Export sheet content

private struct ExportFile: Identifiable {
    let url: URL
    let projectCount: Int
    let byteSize: Int
    var id: URL { url }
}

private struct ImportResult: Identifiable {
    let importedCount: Int
    let skippedCount: Int
    let id = UUID()
}

private struct ExportShareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bounce: Int = 0
    let file: ExportFile

    private var sizeText: String {
        ByteCountFormatStyle(style: .file).format(Int64(file.byteSize))
    }

    private var projectsText: String {
        "\(file.projectCount) project\(file.projectCount == 1 ? "" : "s") · \(sizeText)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 8)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: bounce)

                VStack(spacing: 6) {
                    Text("Backup ready")
                        .font(.title3.weight(.semibold))
                    Text(projectsText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Choose where to save it below")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                Text(file.url.lastPathComponent)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: .rect(cornerRadius: 8))
                    .padding(.horizontal)

                Spacer()

                ShareLink(
                    item: file.url,
                    preview: SharePreview(
                        "IconAtelier Library",
                        image: Image(systemName: "archivebox.fill")
                    )
                ) {
                    Label("Save or Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { bounce += 1 }
        }
    }
}

private struct ImportSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bounce: Int = 0
    let result: ImportResult

    private var title: String {
        if result.importedCount == 0 {
            return "Nothing new to import"
        }
        return result.importedCount == 1 ? "1 project imported" : "\(result.importedCount) projects imported"
    }

    private var subtitle: String? {
        guard result.skippedCount > 0 else { return nil }
        return "\(result.skippedCount) skipped — already in your library"
    }

    private var symbolName: String {
        result.importedCount == 0 ? "checkmark.circle.fill" : "checkmark.seal.fill"
    }

    private var symbolTint: Color {
        result.importedCount == 0 ? .secondary : .green
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 8)

                Image(systemName: symbolName)
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(symbolTint)
                    .symbolEffect(.bounce, value: bounce)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { bounce += 1 }
        }
    }
}
