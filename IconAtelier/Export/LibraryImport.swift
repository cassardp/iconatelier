import Foundation

enum LibraryImportError: LocalizedError {
    case noProjectsFound

    var errorDescription: String? {
        switch self {
        case .noProjectsFound:
            return "The archive doesn't contain any IconAtelier project."
        }
    }
}

struct LibraryImportSummary: Sendable {
    let importedCount: Int
    let skippedCount: Int
    let importedUUIDs: [UUID]
}

enum LibraryImporter {

    @MainActor
    static func importBundle(
        from zipURL: URL,
        into store: ProjectStore,
        asNewCopy: Bool = false
    ) throws -> LibraryImportSummary {
        let entries = try ZipReader.extract(zipURL: zipURL)

        var byDir: [String: [String: Data]] = [:]
        for entry in entries {
            guard let lastSlash = entry.name.lastIndex(of: "/") else { continue }
            let dir = String(entry.name[..<lastSlash])
            let filename = String(entry.name[entry.name.index(after: lastSlash)...])
            byDir[dir, default: [:]][filename] = entry.data
        }

        let projectDirs = byDir.filter { $0.value["project.json"] != nil }
        guard !projectDirs.isEmpty else { throw LibraryImportError.noProjectsFound }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let existingUUIDs = Set(store.projects.map(\.uuid))
        var imported = 0
        var skipped = 0
        var importedUUIDs: [UUID] = []

        for (_, files) in projectDirs {
            guard let jsonData = files["project.json"],
                  let project = try? decoder.decode(IconProject.self, from: jsonData)
            else { continue }

            if asNewCopy {
                project.uuid = UUID()
                project.authorName = nil
                project.isPublic = false
                project.publishedID = nil
                project.publishedAt = nil
            }

            guard !existingUUIDs.contains(project.uuid) else {
                skipped += 1
                continue
            }

            if let thumb = files["thumbnail.png"] {
                project.thumbnailPNG = thumb
            }
            for idx in project.layers.indices {
                let filename = "layer-\(project.layers[idx].uuid.uuidString).png"
                if let data = files[filename] {
                    project.layers[idx].imagePNG = data
                }
            }

            store.add(project)
            imported += 1
            importedUUIDs.append(project.uuid)
        }

        return LibraryImportSummary(importedCount: imported, skippedCount: skipped, importedUUIDs: importedUUIDs)
    }
}
