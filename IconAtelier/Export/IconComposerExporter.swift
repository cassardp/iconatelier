import Foundation
import UIKit

enum IconComposerExporter {

    struct LayerImage {
        let name: String
        let image: UIImage
    }

    enum ExportError: Error {
        case missingImage
        case pngEncodingFailed
    }

    private static let neutralFill = "srgb:1.00000,1.00000,1.00000,1.00000"

    static func writeIconPackage(
        layers: [LayerImage],
        backgroundImage: UIImage?,
        baseName: String
    ) throws -> URL {
        let fm = FileManager.default
        let cleanName = sanitize(baseName)
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("IconAtelier-\(UUID().uuidString)", isDirectory: true)
        let packageDir = workDir.appendingPathComponent("\(cleanName).icon", isDirectory: true)
        let assetsDir = packageDir.appendingPathComponent("Assets", isDirectory: true)

        try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        var groups: [[String: Any]] = []

        if !layers.isEmpty {
            var entries: [[String: Any]] = []
            for (index, layer) in layers.enumerated() {
                let displayName = layer.name.isEmpty ? "Layer \(index + 1)" : layer.name
                let file = "\(index)-\(sanitize(displayName)).png"
                try writePNG(layer.image, to: assetsDir.appendingPathComponent(file))
                entries.append(makeLayer(name: displayName, file: file))
            }
            groups.append(makeGroup(name: "Layers", layers: entries, specular: true))
        }

        if let backgroundImage {
            try writePNG(backgroundImage, to: assetsDir.appendingPathComponent("Background.png"))
            let entry = makeLayer(name: "Background", file: "Background.png")
            groups.append(makeGroup(name: "Background", layers: [entry], specular: false))
        }

        guard !groups.isEmpty else { throw ExportError.missingImage }

        let manifest: [String: Any] = [
            "fill-specializations": [
                ["value": ["automatic-gradient": neutralFill]],
                ["appearance": "light", "value": ["automatic-gradient": neutralFill]]
            ],
            "groups": groups,
            "supported-platforms": [
                "circles": ["watchOS"],
                "squares": "shared"
            ]
        ]

        let data = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: packageDir.appendingPathComponent("icon.json"))

        return try ZipWriter.zip(directory: packageDir, named: "\(cleanName).icon.zip")
    }

    // MARK: - Helpers

    private static func makeGroup(name: String, layers: [[String: Any]], specular: Bool) -> [String: Any] {
        [
            "layers": layers,
            "name": name,
            "shadow": ["kind": "neutral", "opacity": 0.5],
            "specular": specular,
            "translucency": ["enabled": false, "value": 0.5]
        ]
    }

    private static func makeLayer(name: String, file: String) -> [String: Any] {
        [
            "glass": false,
            "hidden": false,
            "image-name": file,
            "name": name
        ]
    }

    private static func writePNG(_ image: UIImage, to url: URL) throws {
        guard let data = image.pngData() else { throw ExportError.pngEncodingFailed }
        try data.write(to: url)
    }

    private static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "AppIcon"
        guard !trimmed.isEmpty else { return fallback }
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        let scalars = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return cleaned.isEmpty ? fallback : cleaned
    }
}
