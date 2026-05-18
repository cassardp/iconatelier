import Foundation
import UIKit

enum FaviconExporter {
    enum ExportError: Error {
        case pngEncodingFailed
    }

    /// Builds a zip with a standard web favicon set:
    ///
    ///     {baseName}-favicons/
    ///         favicon.ico              (multi-image: 16, 32, 48)
    ///         favicon-16.png
    ///         favicon-32.png
    ///         favicon-48.png
    ///         apple-touch-icon.png     (180×180)
    ///         icon-192.png             (PWA / Android Chrome)
    ///         icon-512.png             (PWA / Android Chrome)
    ///         site.webmanifest
    ///         README.txt               (HTML snippet to paste in <head>)
    static func writeBundle(light: UIImage, baseName: String) throws -> URL {
        let fm = FileManager.default
        let clean = sanitize(baseName)
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("IconAtelier-Favicons-\(UUID().uuidString)", isDirectory: true)
        let bundle = workDir.appendingPathComponent("\(clean)-favicons", isDirectory: true)
        try fm.createDirectory(at: bundle, withIntermediateDirectories: true)

        defer { try? fm.removeItem(at: workDir) }

        let png16 = downscale(light, to: 16)
        let png32 = downscale(light, to: 32)
        let png48 = downscale(light, to: 48)
        let png180 = downscale(light, to: 180)
        let png192 = downscale(light, to: 192)
        let png512 = downscale(light, to: 512)

        try writePNG(png16,  to: bundle.appendingPathComponent("favicon-16.png"))
        try writePNG(png32,  to: bundle.appendingPathComponent("favicon-32.png"))
        try writePNG(png48,  to: bundle.appendingPathComponent("favicon-48.png"))
        try writePNG(png180, to: bundle.appendingPathComponent("apple-touch-icon.png"))
        try writePNG(png192, to: bundle.appendingPathComponent("icon-192.png"))
        try writePNG(png512, to: bundle.appendingPathComponent("icon-512.png"))

        guard let ico = makeICO(images: [png16, png32, png48]) else {
            throw ExportError.pngEncodingFailed
        }
        try ico.write(to: bundle.appendingPathComponent("favicon.ico"), options: .atomic)

        let manifest = webManifest(title: clean)
        try manifest.data(using: .utf8)?.write(
            to: bundle.appendingPathComponent("site.webmanifest"),
            options: .atomic
        )

        try readme.data(using: .utf8)?.write(
            to: bundle.appendingPathComponent("README.txt"),
            options: .atomic
        )

        return try ZipWriter.zip(directory: bundle, named: "\(clean)-favicons.zip")
    }

    // MARK: - ICO (multi-image PNG-embedded)

    /// Builds a .ico container with PNG-embedded entries. PNG-in-ICO has been
    /// supported by Windows Vista and every modern browser; it keeps the file
    /// small and preserves alpha.
    private static func makeICO(images: [UIImage]) -> Data? {
        var pngs: [(width: UInt8, height: UInt8, data: Data)] = []
        for img in images {
            guard let png = img.pngData() else { return nil }
            let w = Int(img.size.width)
            let h = Int(img.size.height)
            // ICO stores 256 as the byte value 0.
            let wb: UInt8 = w >= 256 ? 0 : UInt8(w)
            let hb: UInt8 = h >= 256 ? 0 : UInt8(h)
            pngs.append((wb, hb, png))
        }

        var data = Data()

        // ICONDIR header (6 bytes)
        data.appendU16LE(0)               // reserved
        data.appendU16LE(1)               // type = ICO
        data.appendU16LE(UInt16(pngs.count))

        // ICONDIRENTRY for each image (16 bytes each)
        let headerSize = 6 + 16 * pngs.count
        var offset = UInt32(headerSize)
        for entry in pngs {
            data.append(entry.width)
            data.append(entry.height)
            data.append(0)                // color count (0 = no palette)
            data.append(0)                // reserved
            data.appendU16LE(1)           // color planes
            data.appendU16LE(32)          // bits per pixel
            data.appendU32LE(UInt32(entry.data.count))
            data.appendU32LE(offset)
            offset += UInt32(entry.data.count)
        }

        for entry in pngs {
            data.append(entry.data)
        }

        return data
    }

    // MARK: - Manifest / README

    private static func webManifest(title: String) -> String {
        let escaped = title.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        {
          "name": "\(escaped)",
          "short_name": "\(escaped)",
          "icons": [
            { "src": "icon-192.png", "sizes": "192x192", "type": "image/png" },
            { "src": "icon-512.png", "sizes": "512x512", "type": "image/png" }
          ],
          "theme_color": "#ffffff",
          "background_color": "#ffffff",
          "display": "standalone"
        }
        """
    }

    private static let readme = """
    Web favicons
    ============

    Drop every file into your site's root, then paste the snippet below
    into your HTML <head>:

        <link rel="icon" href="/favicon.ico" sizes="any">
        <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
        <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png">
        <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
        <link rel="manifest" href="/site.webmanifest">

    Files
    -----

    favicon.ico               Multi-image (16, 32, 48) — legacy + IE fallback.
    favicon-16.png            Browser tab on standard-density displays.
    favicon-32.png            Browser tab on hi-DPI displays.
    favicon-48.png            Windows site tiles, taskbar.
    apple-touch-icon.png      iOS "Add to Home Screen" icon (180×180).
    icon-192.png              PWA / Android Chrome.
    icon-512.png              PWA splash screen and high-res slot.
    site.webmanifest          Web app manifest referencing the PNG icons.

    Tweak site.webmanifest's name, theme_color and background_color to
    match your brand.
    """

    // MARK: - PNG / utility

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
        guard !trimmed.isEmpty else { return "Favicon" }
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        let chars = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(chars).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return cleaned.isEmpty ? "Favicon" : cleaned
    }
}

private extension Data {
    mutating func appendU16LE(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
    mutating func appendU32LE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
