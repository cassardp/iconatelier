import Foundation
import SwiftData

// MARK: - Importer service

enum LibraryImportError: LocalizedError {
    case missingManifest
    case invalidManifest(String)

    var errorDescription: String? {
        switch self {
        case .missingManifest:
            return "The archive doesn't contain a manifest.json file."
        case .invalidManifest(let detail):
            return "The manifest is invalid: \(detail)"
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
        into modelContext: ModelContext
    ) throws -> LibraryImportSummary {
        let entries = try ZipReader.extract(zipURL: zipURL)

        // NSFileCoordinator(.forUploading) wraps the bundle in a top-level
        // folder named after the export directory. Detect that prefix once
        // and strip it from every lookup.
        var manifestData: Data?
        var prefix: String = ""
        for entry in entries where entry.name.hasSuffix("manifest.json") {
            let name = entry.name
            manifestData = entry.data
            prefix = name.hasSuffix("/manifest.json")
                ? String(name.dropLast("manifest.json".count))
                : ""
            break
        }

        guard let manifestData else { throw LibraryImportError.missingManifest }

        var fileMap: [String: Data] = [:]
        fileMap.reserveCapacity(entries.count)
        for entry in entries {
            let name = entry.name
            guard !name.hasSuffix("manifest.json") else { continue }
            let key = (!prefix.isEmpty && name.hasPrefix(prefix))
                ? String(name.dropFirst(prefix.count))
                : name
            fileMap[key] = entry.data
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let manifest: LibraryExport
        do {
            manifest = try decoder.decode(LibraryExport.self, from: manifestData)
        } catch {
            throw LibraryImportError.invalidManifest(error.localizedDescription)
        }

        let existingUUIDs = Set(
            try modelContext.fetch(FetchDescriptor<IconProject>()).map(\.uuid)
        )

        var imported = 0
        var skipped = 0

        try modelContext.transaction {
            for dto in manifest.projects {
                guard !existingUUIDs.contains(dto.uuid) else {
                    skipped += 1
                    continue
                }
                let project = makeProject(from: dto, fileMap: fileMap)
                modelContext.insert(project)
                imported += 1
            }
        }

        return LibraryImportSummary(importedCount: imported, skippedCount: skipped)
    }

    // MARK: - DTO → model

    private static func makeProject(
        from dto: ProjectExport,
        fileMap: [String: Data]
    ) -> IconProject {
        let project = IconProject(title: dto.title)
        project.uuid = dto.uuid
        project.createdAt = dto.createdAt
        project.updatedAt = dto.updatedAt
        project.thumbnailPNG = dto.thumbnail.flatMap { fileMap[$0] }

        project.appName = dto.appName
        project.appStoreURL = dto.appStoreURL
        project.appBundleID = dto.appBundleID

        project.notes = dto.notes
        project.tags = dto.tags
        project.authorName = dto.authorName

        project.isPublic = dto.isPublic
        project.publishedID = dto.publishedID
        project.publishedAt = dto.publishedAt

        if let bgDTO = dto.background {
            project.background = makeBackground(from: bgDTO, fileMap: fileMap)
        }

        project.rawLayers = dto.layers.map { makeLayer(from: $0, fileMap: fileMap) }

        return project
    }

    private static func makeBackground(
        from dto: BackgroundExport,
        fileMap: [String: Data]
    ) -> Background {
        let bg = Background()
        bg.kindRaw = dto.kind
        bg.storedSolidColor = dto.solidColor
        bg.storedGradientColors = dto.gradientColors
        bg.storedLinearStart = dto.linearStart
        bg.storedLinearEnd = dto.linearEnd
        bg.storedGradientCenter = dto.gradientCenter
        bg.storedMeshColors = dto.meshColors
        bg.meshRotationDegrees = dto.meshRotationDegrees
        bg.isHidden = dto.isHidden
        return bg
    }

    private static func makeLayer(
        from dto: LayerExport,
        fileMap: [String: Data]
    ) -> Layer {
        let layer = Layer(
            uuid: dto.uuid,
            kind: LayerKind(rawValue: dto.kind)!,
            name: dto.name
        )
        layer.orderIndex = dto.orderIndex
        layer.imagePNG = dto.image.flatMap { fileMap[$0] }
        layer.emoji = dto.emoji
        layer.text = dto.text
        layer.fontWeightRaw = dto.fontWeight
        layer.fontDesignRaw = dto.fontDesign
        layer.storedTintColor = dto.tintColor
        layer.offsetW = dto.offsetW
        layer.offsetH = dto.offsetH
        layer.scaleValue = dto.scaleValue
        layer.rotationRadians = dto.rotationRadians
        layer.opacity = dto.opacity
        layer.shadowOpacity = dto.shadowOpacity
        layer.shadowRadius = dto.shadowRadius
        layer.shadowOffsetX = dto.shadowOffsetX
        layer.shadowOffsetY = dto.shadowOffsetY
        layer.storedShadowColor = dto.shadowColor
        layer.isHidden = dto.isHidden
        layer.isLocked = dto.isLocked
        layer.isFlippedHorizontally = dto.isFlippedHorizontally
        layer.isFlippedVertically = dto.isFlippedVertically
        layer.cornerRadius = dto.cornerRadius
        layer.borderWidth = dto.borderWidth
        layer.storedBorderColor = dto.borderColor
        layer.borderPositionRaw = dto.borderPosition
        layer.shapeSpecJSON = dto.shapeSpecJSON
        return layer
    }
}
