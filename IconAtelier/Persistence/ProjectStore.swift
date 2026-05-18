import SwiftUI
import UIKit
import os

/// Filesystem-backed project store. Replaces the previous SwiftData
/// `ModelContainer` setup. Each project lives in its own directory under
/// `Documents/Projects/{uuid}/`:
///
///     project.json        # IconProject + Background + [Layer] serialised
///     layer-{uuid}.png    # per-layer PNG payloads (out-of-band)
///     thumbnail.png       # gallery vignette
///
/// All writes are atomic. PNG sidecars are written first, then `project.json`
/// last: the JSON is the index of truth, so a mid-save crash can leave PNG
/// orphans (cleaned up on the next save) but never produce a JSON that
/// references a missing image. The store keeps every project loaded in
/// memory — IconAtelier is single-user and the libraries are small.
@MainActor
@Observable
final class ProjectStore {
    private(set) var projects: [IconProject] = []

    private let fm = FileManager.default
    private let baseURL: URL
    private let logger = Logger(subsystem: "fr.cassard.IconAtelier", category: "ProjectStore")

    init() {
        let docs = URL.documentsDirectory
        baseURL = docs.appendingPathComponent("Projects", isDirectory: true)
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Load

    func load() {
        guard let entries = try? fm.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            projects = []
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var loaded: [IconProject] = []
        for dir in entries where (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            let jsonURL = dir.appendingPathComponent("project.json")
            guard let data = try? Data(contentsOf: jsonURL),
                  let project = try? decoder.decode(IconProject.self, from: data)
            else {
                logger.warning("Skipping unreadable project at \(dir.lastPathComponent, privacy: .public)")
                continue
            }

            // Rehydrate out-of-band PNG payloads. The dirty flags are reset
            // right after assignment so the next save() doesn't rewrite
            // what we just read back.
            if let thumbData = try? Data(contentsOf: dir.appendingPathComponent("thumbnail.png")) {
                project.thumbnailPNG = thumbData
            }
            project.thumbnailPNGDirty = false

            for layer in project.layers {
                let layerURL = dir.appendingPathComponent("layer-\(layer.uuid.uuidString).png")
                if let imageData = try? Data(contentsOf: layerURL) {
                    layer.imagePNG = imageData
                }
                layer.imagePNGDirty = false
            }

            loaded.append(project)
        }

        // Gallery is sorted newest-first, matching the previous @Query order.
        projects = loaded.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Mutations

    /// Inserts a freshly created project, persists it, and returns the same
    /// instance so callers can navigate into it immediately.
    @discardableResult
    func add(_ project: IconProject) -> IconProject {
        if !projects.contains(where: { $0.uuid == project.uuid }) {
            projects.insert(project, at: 0)
        }
        save(project)
        return project
    }

    /// Writes the project's PNG sidecars first, then `project.json` last.
    /// All writes are atomic per file. The JSON is written last so it never
    /// references a sidecar that doesn't exist yet: a mid-save crash can
    /// leave orphan PNGs (which the next save will reap) but never an
    /// inconsistent index. Updates `updatedAt` as a side effect.
    func save(_ project: IconProject) {
        project.updatedAt = .now
        let dir = directory(for: project.uuid)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)

            // 1. Thumbnail sidecar — skip the write if the blob is clean
            //    *and* the file already exists on disk. The dirty flag is
            //    reset only on a successful write so a failed write retries
            //    next time.
            let thumbURL = dir.appendingPathComponent("thumbnail.png")
            if let thumb = project.thumbnailPNG {
                if project.thumbnailPNGDirty || !fm.fileExists(atPath: thumbURL.path) {
                    try thumb.write(to: thumbURL, options: .atomic)
                    project.thumbnailPNGDirty = false
                }
            } else if fm.fileExists(atPath: thumbURL.path) {
                try? fm.removeItem(at: thumbURL)
            }

            // 2. Layer PNG sidecars — same skip logic per layer.
            var keepFilenames: Set<String> = ["project.json", "thumbnail.png"]
            for layer in project.layers {
                let filename = "layer-\(layer.uuid.uuidString).png"
                let url = dir.appendingPathComponent(filename)
                if let data = layer.imagePNG {
                    if layer.imagePNGDirty || !fm.fileExists(atPath: url.path) {
                        try data.write(to: url, options: .atomic)
                        layer.imagePNGDirty = false
                    }
                    keepFilenames.insert(filename)
                } else if fm.fileExists(atPath: url.path) {
                    try? fm.removeItem(at: url)
                }
            }

            // 3. Reap orphan layer-*.png files (layers deleted since last save).
            if let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for url in entries {
                    let name = url.lastPathComponent
                    guard name.hasPrefix("layer-"), name.hasSuffix(".png") else { continue }
                    if !keepFilenames.contains(name) {
                        try? fm.removeItem(at: url)
                    }
                }
            }

            // 4. Finally, the index — `project.json` is written last so it
            //    only ever references sidecars already on disk.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(project)
            try jsonData.write(to: dir.appendingPathComponent("project.json"), options: .atomic)
        } catch {
            logger.error("Failed to save project \(project.uuid.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func delete(_ project: IconProject) {
        projects.removeAll { $0.uuid == project.uuid }
        let dir = directory(for: project.uuid)
        try? fm.removeItem(at: dir)
    }

    func delete(uuids: Set<UUID>) {
        let targets = projects.filter { uuids.contains($0.uuid) }
        for project in targets {
            delete(project)
        }
    }

    func project(withID uuid: UUID) -> IconProject? {
        projects.first { $0.uuid == uuid }
    }

    // MARK: - Internals

    private func directory(for uuid: UUID) -> URL {
        baseURL.appendingPathComponent(uuid.uuidString, isDirectory: true)
    }
}
