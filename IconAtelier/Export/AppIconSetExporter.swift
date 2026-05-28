import Foundation
import UIKit

enum AppIconSetExporter {

    struct Variants {
        var light: UIImage
        var dark: UIImage?
        var tinted: UIImage?
    }

    struct Platforms: OptionSet {
        let rawValue: Int
        static let iOS = Platforms(rawValue: 1 << 0)
        static let macOS = Platforms(rawValue: 1 << 1)
        static let watchOS = Platforms(rawValue: 1 << 2)
    }

    enum ExportError: Error {
        case missingLightImage
        case pngEncodingFailed
        case fileWriteFailed
    }

    static func writeAppIconSet(
        variants: Variants,
        platforms: Platforms,
        baseName: String
    ) throws -> URL {
        let fm = FileManager.default
        let cleanName = sanitize(baseName)
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("IconAtelier-\(UUID().uuidString)", isDirectory: true)
        let directory = workDir.appendingPathComponent("\(cleanName).appiconset", isDirectory: true)

        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        let opaqueLight = opaque(variants.light)

        let lightFile = "icon-1024.png"
        try writePNG(opaqueLight, to: directory.appendingPathComponent(lightFile))

        var images: [[String: Any]] = []

        if platforms.contains(.iOS) {
            images.append(imageEntry(filename: lightFile, platform: .iOS, appearance: nil))

            if let dark = variants.dark {
                let darkFile = "icon-dark-1024.png"
                try writePNG(dark, to: directory.appendingPathComponent(darkFile))
                images.append(imageEntry(filename: darkFile, platform: .iOS, appearance: .dark))
            }

            if let tinted = variants.tinted {
                let tintedFile = "icon-tinted-1024.png"
                try writePNG(tinted, to: directory.appendingPathComponent(tintedFile))
                images.append(imageEntry(filename: tintedFile, platform: .iOS, appearance: .tinted))
            }
        }

        if platforms.contains(.macOS) {
            try appendMacOSEntries(
                into: &images,
                directory: directory,
                light: opaqueLight,
                sharedLightFile: lightFile
            )
        }

        if platforms.contains(.watchOS) {
            images.append(imageEntry(filename: lightFile, platform: .watchOS, appearance: nil))
        }

        let contents: [String: Any] = [
            "images": images,
            "info": ["author": "xcode", "version": 1] as [String: Any]
        ]

        let data = try JSONSerialization.data(
            withJSONObject: contents,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: directory.appendingPathComponent("Contents.json"))

        return try ZipWriter.zip(directory: directory, named: "\(cleanName).appiconset.zip")
    }

    // MARK: - Helpers

    private enum Appearance {
        case dark
        case tinted

        var luminosity: String {
            switch self {
            case .dark: "dark"
            case .tinted: "tinted"
            }
        }
    }

    private enum SinglePlatform {
        case iOS
        case macOS
        case watchOS
    }

    private static func imageEntry(
        filename: String,
        platform: SinglePlatform,
        appearance: Appearance?
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "filename": filename,
            "size": "1024x1024"
        ]
        switch platform {
        case .iOS:
            entry["idiom"] = "universal"
            entry["platform"] = "ios"
        case .macOS:
            entry["idiom"] = "mac"
        case .watchOS:
            entry["idiom"] = "universal"
            entry["platform"] = "watchos"
        }
        if let appearance {
            entry["appearances"] = [[
                "appearance": "luminosity",
                "value": appearance.luminosity
            ]]
        }
        return entry
    }

    private static func writePNG(_ image: UIImage, to url: URL) throws {
        guard let data = image.pngData() else { throw ExportError.pngEncodingFailed }
        try data.write(to: url)
    }

    private static func opaque(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    // MARK: - macOS size matrix

    private struct MacSlot {
        let size: String
        let scale: String
        let pixels: CGFloat
    }

    private static let macSlots: [MacSlot] = [
        .init(size: "16x16",   scale: "1x", pixels: 16),
        .init(size: "16x16",   scale: "2x", pixels: 32),
        .init(size: "32x32",   scale: "1x", pixels: 32),
        .init(size: "32x32",   scale: "2x", pixels: 64),
        .init(size: "128x128", scale: "1x", pixels: 128),
        .init(size: "128x128", scale: "2x", pixels: 256),
        .init(size: "256x256", scale: "1x", pixels: 256),
        .init(size: "256x256", scale: "2x", pixels: 512),
        .init(size: "512x512", scale: "1x", pixels: 512),
        .init(size: "512x512", scale: "2x", pixels: 1024)
    ]

    private static func appendMacOSEntries(
        into images: inout [[String: Any]],
        directory: URL,
        light: UIImage,
        sharedLightFile: String
    ) throws {

        var fileByPixels: [CGFloat: String] = [1024: sharedLightFile]
        let distinctSizes = Set(macSlots.map { $0.pixels }).subtracting([1024])

        for px in distinctSizes.sorted() {
            let resized = downscale(light, to: px)
            let filename = "icon-\(Int(px)).png"
            try writePNG(resized, to: directory.appendingPathComponent(filename))
            fileByPixels[px] = filename
        }

        for slot in macSlots {
            guard let filename = fileByPixels[slot.pixels] else { continue }
            images.append([
                "filename": filename,
                "idiom": "mac",
                "size": slot.size,
                "scale": slot.scale
            ])
        }
    }

    private static func downscale(_ image: UIImage, to side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        )
        return renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
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
