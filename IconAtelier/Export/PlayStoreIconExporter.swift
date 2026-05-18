import Foundation
import UIKit

enum PlayStoreIconExporter {
    enum ExportError: Error {
        case pngEncodingFailed
    }

    private struct Mipmap {
        let folder: String
        let pixels: CGFloat
    }

    private static let mipmaps: [Mipmap] = [
        .init(folder: "mipmap-mdpi",    pixels: 48),
        .init(folder: "mipmap-hdpi",    pixels: 72),
        .init(folder: "mipmap-xhdpi",   pixels: 96),
        .init(folder: "mipmap-xxhdpi",  pixels: 144),
        .init(folder: "mipmap-xxxhdpi", pixels: 192)
    ]

    static func writeBundle(light: UIImage, baseName: String) throws -> URL {
        let fm = FileManager.default
        let clean = sanitize(baseName)
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("IconAtelier-PlayStore-\(UUID().uuidString)", isDirectory: true)
        let bundle = workDir.appendingPathComponent("\(clean)-play-store", isDirectory: true)
        try fm.createDirectory(at: bundle, withIntermediateDirectories: true)

        defer { try? fm.removeItem(at: workDir) }

        try writePNG(downscale(light, to: 512), to: bundle.appendingPathComponent("play-store-512.png"))

        let androidDir = bundle.appendingPathComponent("android", isDirectory: true)
        try fm.createDirectory(at: androidDir, withIntermediateDirectories: true)
        for mip in mipmaps {
            let dir = androidDir.appendingPathComponent(mip.folder, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try writePNG(downscale(light, to: mip.pixels), to: dir.appendingPathComponent("ic_launcher.png"))
        }

        try readme.data(using: .utf8)?.write(
            to: bundle.appendingPathComponent("README.txt"),
            options: .atomic
        )

        return try ZipWriter.zip(directory: bundle, named: "\(clean)-play-store.zip")
    }

    // MARK: - Helpers

    private static let readme = """
    Google Play & Android icons
    ===========================

    play-store-512.png
        High-resolution app icon for the Play Store listing.
        Specs: 512×512 px, 32-bit PNG with alpha, max 1024 KB.
        Upload in Play Console → Main store listing → Graphics → App icon.

    android/mipmap-*/ic_launcher.png
        Legacy launcher icons in five densities:
            mipmap-mdpi      48×48
            mipmap-hdpi      72×72
            mipmap-xhdpi     96×96
            mipmap-xxhdpi   144×144
            mipmap-xxxhdpi  192×192
        Drop the mipmap-* folders into your project's
        `app/src/main/res/` directory.

    For modern Android 8+ adaptive icons (separate foreground and
    background layers), feed the 512×512 PNG above into Android Studio's
    "Image Asset Studio" — IconAtelier exports a single composited image
    and can't split it into layers automatically.
    """

    private static func writePNG(_ image: UIImage, to url: URL) throws {
        guard let data = image.pngData() else { throw ExportError.pngEncodingFailed }
        try data.write(to: url, options: .atomic)
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
        guard !trimmed.isEmpty else { return "AppIcon" }
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        let chars = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(chars).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return cleaned.isEmpty ? "AppIcon" : cleaned
    }
}
