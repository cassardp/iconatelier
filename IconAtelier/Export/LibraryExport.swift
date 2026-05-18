import Foundation

// MARK: - Export bundle format

enum LibraryExporter {

    @MainActor
    static func buildBundle(projects: [IconProject]) throws -> URL {
        let fm = FileManager.default

        let timestamp = Self.timestamp()
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("IconAtelier-\(timestamp)", isDirectory: true)

        if fm.fileExists(atPath: workDir.path) {
            try fm.removeItem(at: workDir)
        }
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

        defer { try? fm.removeItem(at: workDir) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        for project in projects {
            let dir = workDir.appendingPathComponent(project.uuid.uuidString, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)

            let jsonData = try encoder.encode(project)
            try jsonData.write(
                to: dir.appendingPathComponent("project.json"),
                options: .atomic
            )

            if let thumb = project.thumbnailPNG {
                try thumb.write(
                    to: dir.appendingPathComponent("thumbnail.png"),
                    options: .atomic
                )
            }

            for layer in project.layers {
                guard let data = layer.imagePNG else { continue }
                let filename = "layer-\(layer.uuid.uuidString).png"
                try data.write(
                    to: dir.appendingPathComponent(filename),
                    options: .atomic
                )
            }
        }

        let zipURL = try ZipWriter.zip(directory: workDir, named: "IconAtelier-\(timestamp).zip")
        return zipURL
    }

    // MARK: - Internals

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: .now)
    }
}
