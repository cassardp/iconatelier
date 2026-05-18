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
}

enum LibraryImporter {

    @MainActor
    static func importBundle(
        from zipURL: URL,
        into store: ProjectStore
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

        for (_, files) in projectDirs {
            guard let jsonData = files["project.json"],
                  let project = try? decoder.decode(IconProject.self, from: jsonData)
            else { continue }

            guard !existingUUIDs.contains(project.uuid) else {
                skipped += 1
                continue
            }

            if let thumb = files["thumbnail.png"] {
                project.thumbnailPNG = thumb
            }
            for layer in project.layers {
                let filename = "layer-\(layer.uuid.uuidString).png"
                if let data = files[filename] {
                    layer.imagePNG = data
                }
            }

            store.add(project)
            imported += 1
        }

        return LibraryImportSummary(importedCount: imported, skippedCount: skipped)
    }
}
