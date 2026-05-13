import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var apiKey: String = ""
    @State private var didLoad: Bool = false
    @State private var isSaving: Bool = false
    @State private var isRevealed: Bool = false

    @State private var isExporting: Bool = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    @State private var isImporting: Bool = false
    @State private var isPickingImport: Bool = false
    @State private var importResult: ImportResult?
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if isRevealed {
                                TextField("sk-...", text: $apiKey)
                            } else {
                                SecureField("sk-...", text: $apiKey)
                            }
                        }
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(save)

                        Button {
                            isRevealed.toggle()
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isRevealed ? "Hide API key" : "Show API key")
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Stored securely in the iOS Keychain on this device. Used to generate icons via OpenAI.")
                }

                Section {
                    Button(action: exportLibrary) {
                        HStack {
                            Label("Export library", systemImage: "arrow.up.doc")
                            Spacer()
                            if isExporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting || isImporting)

                    Button {
                        isPickingImport = true
                    } label: {
                        HStack {
                            Label("Import library", systemImage: "arrow.down.doc")
                            Spacer()
                            if isImporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting || isImporting)
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Save all your projects to a zip file (Files, AirDrop, email), or restore one. Import skips projects that already exist.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(!didLoad || isSaving)
                }
            }
            .task {
                guard !didLoad else { return }
                apiKey = await APIKeyStore.shared.load() ?? ""
                didLoad = true
            }
            .sheet(item: $exportFile) { file in
                ExportShareView(file: file)
                    .presentationDetents([.medium])
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
            .alert(
                "Import complete",
                isPresented: Binding(
                    get: { importResult != nil },
                    set: { if !$0 { importResult = nil } }
                ),
                presenting: importResult
            ) { _ in
                Button("OK", role: .cancel) { importResult = nil }
            } message: { result in
                Text(result.message)
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let value = apiKey
        Task {
            await APIKeyStore.shared.save(value)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }

    private func exportLibrary() {
        guard !isExporting else { return }
        isExporting = true
        Task { @MainActor in
            defer { isExporting = false }
            do {
                let descriptor = FetchDescriptor<IconProject>(
                    sortBy: [SortDescriptor(\.createdAt)]
                )
                let projects = try modelContext.fetch(descriptor)
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
                    into: modelContext
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

    var message: String {
        let importedLabel = "\(importedCount) project\(importedCount == 1 ? "" : "s") imported"
        if skippedCount > 0 {
            let skipLabel = "\(skippedCount) skipped (already in your library)"
            return "\(importedLabel) · \(skipLabel)."
        }
        return importedLabel + "."
    }
}

private struct ExportShareView: View {
    @Environment(\.dismiss) private var dismiss
    let file: ExportFile

    private var sizeText: String {
        ByteCountFormatStyle(style: .file).format(Int64(file.byteSize))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                VStack(spacing: 6) {
                    Text("Library exported")
                        .font(.title3.weight(.semibold))
                    Text("\(file.projectCount) project\(file.projectCount == 1 ? "" : "s") · \(sizeText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ShareLink(
                    item: file.url,
                    preview: SharePreview("IconAtelier Library", image: Image(systemName: "doc.text"))
                ) {
                    Label("Save or share file", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                Spacer()
            }
            .padding()
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
