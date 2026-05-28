import SwiftUI
import UIKit
import os

@MainActor
@Observable
final class ProjectStore {
    private(set) var projects: [IconProject] = []
    private(set) var failedToLoad: [String] = []

    private let fm = FileManager.default
    private let baseURL: URL
    private let logger = Logger(subsystem: "fr.cassard.IconAtelier", category: "ProjectStore")

    init() {
        let docs = URL.documentsDirectory
        baseURL = docs.appendingPathComponent("Projects", isDirectory: true)
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
        seedIfNeeded()
        load()
    }

    // MARK: - Seed

    private static let didSeedKey = "didSeedInitialProjects"

    private func seedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didSeedKey) else { return }
        defaults.set(true, forKey: Self.didSeedKey)

        guard let zipURL = Bundle.main.url(forResource: "SeedLibrary", withExtension: "zip") else {
            logger.error("Seed library missing from bundle")
            return
        }
        do {
            _ = try LibraryImporter.importBundle(from: zipURL, into: self)
        } catch {
            logger.error("Failed to seed initial projects: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Load

    func load() {
        guard let entries = try? fm.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            projects = []
            failedToLoad = []
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var loaded: [IconProject] = []
        var failures: [String] = []
        for dir in entries where (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            let jsonURL = dir.appendingPathComponent("project.json")

            guard fm.fileExists(atPath: jsonURL.path) else { continue }

            let data: Data
            do {
                data = try Data(contentsOf: jsonURL)
            } catch {
                failures.append(dir.lastPathComponent)
                logger.error("Failed to read project at \(dir.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                continue
            }

            let project: IconProject
            do {
                project = try decoder.decode(IconProject.self, from: data)
            } catch {
                failures.append(dir.lastPathComponent)
                logger.error("Failed to decode project at \(dir.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
                continue
            }

            if let thumbData = try? Data(contentsOf: dir.appendingPathComponent("thumbnail.png")) {
                project.thumbnailPNG = thumbData
            }
            project.thumbnailPNGDirty = false

            for idx in project.layers.indices {
                let uuid = project.layers[idx].uuid
                let layerURL = dir.appendingPathComponent("layer-\(uuid.uuidString).png")
                if let imageData = try? Data(contentsOf: layerURL) {
                    project.layers[idx].imagePNG = imageData
                }
                project.layers[idx].imagePNGDirty = false
            }

            loaded.append(project)
        }

        projects = loaded.sorted { $0.createdAt > $1.createdAt }
        failedToLoad = failures
        if !failures.isEmpty {
            logger.error("Loaded \(loaded.count) project(s), \(failures.count) failed to load")
        }
    }

    // MARK: - Mutations

    @discardableResult
    func add(_ project: IconProject) -> IconProject {
        if !projects.contains(where: { $0.uuid == project.uuid }) {
            projects.insert(project, at: 0)
        }
        save(project)
        return project
    }

    func save(_ project: IconProject) {
        project.updatedAt = .now
        let dir = directory(for: project.uuid)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)

            let thumbURL = dir.appendingPathComponent("thumbnail.png")
            if let thumb = project.thumbnailPNG {
                if project.thumbnailPNGDirty || !fm.fileExists(atPath: thumbURL.path) {
                    try thumb.write(to: thumbURL, options: .atomic)
                    project.thumbnailPNGDirty = false
                }
            } else if fm.fileExists(atPath: thumbURL.path) {
                try? fm.removeItem(at: thumbURL)
            }

            var keepFilenames: Set<String> = ["project.json", "thumbnail.png"]
            for idx in project.layers.indices {
                let layer = project.layers[idx]
                let filename = "layer-\(layer.uuid.uuidString).png"
                let url = dir.appendingPathComponent(filename)
                if let data = layer.imagePNG {
                    if layer.imagePNGDirty || !fm.fileExists(atPath: url.path) {
                        try data.write(to: url, options: .atomic)
                        project.layers[idx].imagePNGDirty = false
                    }
                    keepFilenames.insert(filename)
                } else if fm.fileExists(atPath: url.path) {
                    try? fm.removeItem(at: url)
                }
            }

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
