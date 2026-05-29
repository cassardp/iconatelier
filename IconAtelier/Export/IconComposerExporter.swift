import Foundation
import UIKit

enum IconComposerExporter {

    enum ExportError: Error {
        case missingImage
        case pngEncodingFailed
    }

    private static let neutralFill = "srgb:1.00000,1.00000,1.00000,1.00000"

    static func writeIconPackage(
        foreground: UIImage?,
        backgroundImage: UIImage?,
        baseName: String,
        disableGlass: Bool
    ) throws -> URL {
        let fm = FileManager.default
        let cleanName = sanitize(baseName)
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("IconAtelier-\(UUID().uuidString)", isDirectory: true)
        let packageDir = workDir.appendingPathComponent("\(cleanName).icon", isDirectory: true)
        let assetsDir = packageDir.appendingPathComponent("Assets", isDirectory: true)

        try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        var layers: [[String: Any]] = []

        if let foreground {
            try writePNG(foreground, to: assetsDir.appendingPathComponent("Foreground.png"))
            layers.append(makeLayer(name: "Foreground", file: "Foreground.png", disableGlass: disableGlass))
        }

        if let backgroundImage {
            try writePNG(backgroundImage, to: assetsDir.appendingPathComponent("Background.png"))
            layers.append(makeLayer(name: "Background", file: "Background.png", disableGlass: disableGlass))
        }

        guard !layers.isEmpty else { throw ExportError.missingImage }

        var group: [String: Any] = [
            "layers": layers,
            "shadow": ["kind": "neutral", "opacity": 0.5],
            "specular": !disableGlass,
            "translucency": ["enabled": !disableGlass, "value": 0.5]
        ]
        if !disableGlass {
            group["blur-material"] = NSNull()
        }

        let manifest: [String: Any] = [
            "fill-specializations": [
                ["value": ["automatic-gradient": neutralFill]],
                ["appearance": "light", "value": ["automatic-gradient": neutralFill]]
            ],
            "groups": [group],
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

    private static func makeLayer(name: String, file: String, disableGlass: Bool) -> [String: Any] {
        [
            "glass": !disableGlass,
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
