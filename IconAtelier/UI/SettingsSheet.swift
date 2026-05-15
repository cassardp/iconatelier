import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
