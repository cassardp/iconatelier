import Foundation

// MARK: - Top-level export envelope
//
// The export is a .zip wrapping a single folder named after the timestamp:
//
//     IconAtelier-YYYY-MM-DD-HHmm/
//         manifest.json
//         images/<uuid>-thumb.png        (per project, optional)
//         images/<layerUUID>.png         (per image layer, optional)
//
// Path values in the JSON are relative to the folder, e.g. "images/abc.png".

struct LibraryExport: Codable {
    let exportedAt: Date
    let appVersion: String?
    let projects: [ProjectExport]
}

// MARK: - DTOs

struct ProjectExport: Codable {
    let uuid: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let thumbnail: String?

    let appName: String?
    let appStoreURL: URL?
    let appBundleID: String?

    let notes: String?
    let tags: [String]
    let authorName: String?

    let isPublic: Bool
    let publishedID: String?
    let publishedAt: Date?

    let background: BackgroundExport?
    let layers: [LayerExport]
}

struct BackgroundExport: Codable {
    let kind: String

    let solidColor: StoredColor
    let gradientColors: [StoredColor]
    let linearStart: StoredPoint
    let linearEnd: StoredPoint
    let gradientCenter: StoredPoint
    let meshColors: [StoredColor]
    let meshRotationDegrees: Double

    let isHidden: Bool
}

struct LayerExport: Codable {
    let uuid: UUID
    let name: String
    let kind: String
    let orderIndex: Int

    let image: String?

    let emoji: String
    let text: String
    let fontWeight: String
    let fontDesign: String

    let tintColor: StoredColor

    let offsetW: Double
    let offsetH: Double
    let scaleValue: Double
    let rotationRadians: Double
    let opacity: Double

    let shadowOpacity: Double
    let shadowRadius: Double
    let shadowOffsetX: Double
    let shadowOffsetY: Double
    let shadowColor: StoredColor

    let isHidden: Bool
    let isLocked: Bool
    let isFlippedHorizontally: Bool
    let isFlippedVertically: Bool

    let cornerRadius: Double
    let borderWidth: Double
    let borderColor: StoredColor
    let borderPosition: String
    let shapeSpecJSON: Data?
    // Added after v1 — optional to keep older bundles decodable.
    let fillEnabled: Bool?
    let lineCap: String?
}

// MARK: - Exporter service

enum LibraryExporter {
    /// Builds the bundle directory (`manifest.json` + `images/`) then zips it.
    /// Returns the URL of the final `.zip` file in the temporary directory.
    @MainActor
    static func buildBundle(projects: [IconProject]) throws -> URL {
        let fm = FileManager.default

        let timestamp = Self.timestamp()
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("IconAtelier-\(timestamp)", isDirectory: true)
        let imagesDir = workDir.appendingPathComponent("images", isDirectory: true)

        if fm.fileExists(atPath: workDir.path) {
            try fm.removeItem(at: workDir)
        }
        try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        var projectDTOs: [ProjectExport] = []
        projectDTOs.reserveCapacity(projects.count)

        for project in projects {
            let thumbPath = try Self.writeImage(
                data: project.thumbnailPNG,
                name: "\(project.uuid.uuidString)-thumb",
                in: imagesDir
            )

            let bg = project.background.map { background in
                BackgroundExport(
                    kind: background.kindRaw,
                    solidColor: background.storedSolidColor,
                    gradientColors: background.storedGradientColors,
                    linearStart: background.storedLinearStart,
                    linearEnd: background.storedLinearEnd,
                    gradientCenter: background.storedGradientCenter,
                    meshColors: background.storedMeshColors,
                    meshRotationDegrees: background.meshRotationDegrees,
                    isHidden: background.isHidden
                )
            }

            var layerDTOs: [LayerExport] = []
            layerDTOs.reserveCapacity(project.layers.count)
            for layer in project.layers {
                let layerPath = try Self.writeImage(
                    data: layer.imagePNG,
                    name: layer.uuid.uuidString,
                    in: imagesDir
                )
                layerDTOs.append(LayerExport(
                    uuid: layer.uuid,
                    name: layer.name,
                    kind: layer.kindRaw,
                    orderIndex: layer.orderIndex,
                    image: layerPath,
                    emoji: layer.emoji,
                    text: layer.text,
                    fontWeight: layer.fontWeightRaw,
                    fontDesign: layer.fontDesignRaw,
                    tintColor: layer.storedTintColor,
                    offsetW: layer.offsetW,
                    offsetH: layer.offsetH,
                    scaleValue: layer.scaleValue,
                    rotationRadians: layer.rotationRadians,
                    opacity: layer.opacity,
                    shadowOpacity: layer.shadowOpacity,
                    shadowRadius: layer.shadowRadius,
                    shadowOffsetX: layer.shadowOffsetX,
                    shadowOffsetY: layer.shadowOffsetY,
                    shadowColor: layer.storedShadowColor,
                    isHidden: layer.isHidden,
                    isLocked: layer.isLocked,
                    isFlippedHorizontally: layer.isFlippedHorizontally,
                    isFlippedVertically: layer.isFlippedVertically,
                    cornerRadius: layer.cornerRadius,
                    borderWidth: layer.borderWidth,
                    borderColor: layer.storedBorderColor,
                    borderPosition: layer.borderPositionRaw,
                    shapeSpecJSON: layer.shapeSpecJSON,
                    fillEnabled: layer.fillEnabled,
                    lineCap: layer.lineCapRaw
                ))
            }

            projectDTOs.append(ProjectExport(
                uuid: project.uuid,
                title: project.title,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt,
                thumbnail: thumbPath,
                appName: project.appName,
                appStoreURL: project.appStoreURL,
                appBundleID: project.appBundleID,
                notes: project.notes,
                tags: project.tags,
                authorName: project.authorName,
                isPublic: project.isPublic,
                publishedID: project.publishedID,
                publishedAt: project.publishedAt,
                background: bg,
                layers: layerDTOs
            ))
        }

        let manifest = LibraryExport(
            exportedAt: .now,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            projects: projectDTOs
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(
            to: workDir.appendingPathComponent("manifest.json"),
            options: .atomic
        )

        let zipURL = try Self.zip(directory: workDir, named: "IconAtelier-\(timestamp).zip")

        // Clean up the loose directory now that we have the zip.
        try? fm.removeItem(at: workDir)

        return zipURL
    }

    // MARK: - Internals

    /// Writes `data` as a PNG file under `dir` and returns the relative path
    /// (`images/<name>.png`), or `nil` if `data` is nil.
    private static func writeImage(data: Data?, name: String, in dir: URL) throws -> String? {
        guard let data else { return nil }
        let url = dir.appendingPathComponent("\(name).png")
        try data.write(to: url, options: .atomic)
        return "images/\(name).png"
    }

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
