import Foundation

// MARK: - Export bundle format
//
// The export is a .zip wrapping a single timestamped folder that mirrors
// the on-disk store layout (`Documents/Projects/{uuid}/`):
//
//     IconAtelier-YYYY-MM-DD-HHmm/
//         {uuid}/
//             project.json
//             thumbnail.png        (optional)
//             layer-{uuid}.png     (one per image-bearing layer)
//         {uuid}/
//             ...
//
// No manifest file — the structure is self-describing and a project's UUID
// lives both in its directory name and in `project.json`. Importing is the
// inverse: drop each `{uuid}/` directory into the store as-is.

enum LibraryExporter {
    /// Builds the bundle directory then zips it. Returns the URL of the
    /// final `.zip` file in the temporary directory.
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

        // Make sure the loose work directory is always cleaned up, even if a
        // PNG write throws midway through the loop.
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

        let zipURL = try Self.zip(directory: workDir, named: "IconAtelier-\(timestamp).zip")
        return zipURL
    }

    // MARK: - Internals

    /// Zips a directory using `NSFileCoordinator` with `.forUploading`, which
    /// natively produces a zip archive of the directory. We copy the result
    /// out of the coordinator's temporary location into a stable URL.
    private static func zip(directory source: URL, named filename: String) throws -> URL {
        let fm = FileManager.default
        let destination = fm.temporaryDirectory.appendingPathComponent(filename)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var produced: Error?

        coordinator.coordinate(
            readingItemAt: source,
            options: [.forUploading],
            error: &coordError
        ) { tempZipURL in
            do {
                try fm.copyItem(at: tempZipURL, to: destination)
            } catch {
                produced = error
            }
        }

        if let coordError { throw coordError }
        if let produced { throw produced }
        return destination
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: .now)
    }
}
