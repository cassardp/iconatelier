import SwiftUI
import UIKit

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: IconProject

    @State private var lightImage: UIImage?
    @State private var darkImage: UIImage?
    @State private var tintedImage: UIImage?

    @State private var iconSetURL: URL?
    @State private var lightPNGURL: URL?
    @State private var playStoreURL: URL?
    @State private var faviconsURL: URL?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroPreview
                    formatsSection
                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Color.appPageBackground.ignoresSafeArea())
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { regenerate() }
        }
    }

    // MARK: - Hero preview

    private var heroPreview: some View {
        VStack(spacing: 14) {
            heroIconTile
            VStack(spacing: 2) {
                Text(project.title.isEmpty ? "Untitled Icon" : project.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text("1024 × 1024 master")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var heroIconTile: some View {
        // iOS app icon corner mask: ~22.37% of the side — continuous curve.
        let side: CGFloat = 180
        let radius = side * 0.2237
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return ZStack {
            if let lightImage {
                Image(uiImage: lightImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(uiColor: .secondarySystemBackground)
                ProgressView()
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay(shape.stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Export format list

    private var formatsSection: some View {
        PanelSection(title: "Export Format") {
            VStack(spacing: 8) {
                ExportFormatCard(
                    title: "Apple App Icon Set",
                    subtitle: "iOS · macOS · watchOS — Light + Dark + Tinted",
                    systemImage: "applelogo",
                    url: iconSetURL,
                    previewTitle: "\(displayTitle) AppIcon",
                    previewImage: previewImage
                )
                ExportFormatCard(
                    title: "Single PNG",
                    subtitle: "1024 × 1024 light icon",
                    systemImage: "photo",
                    url: lightPNGURL,
                    previewTitle: "\(displayTitle) Icon",
                    previewImage: previewImage
                )
                ExportFormatCard(
                    title: "Google Play Pack",
                    subtitle: "512 hi-res + 5 mipmap densities",
                    systemImage: "play.rectangle.fill",
                    url: playStoreURL,
                    previewTitle: "\(displayTitle) Play Store",
                    previewImage: previewImage
                )
                ExportFormatCard(
                    title: "Web Favicons",
                    subtitle: ".ico, apple-touch-icon, PWA manifest",
                    systemImage: "globe",
                    url: faviconsURL,
                    previewTitle: "\(displayTitle) Favicons",
                    previewImage: previewImage
                )
            }
        }
    }

    // MARK: - Derived

    private var displayTitle: String {
        project.title.isEmpty ? "AppIcon" : project.title
    }

    private var previewImage: Image {
        lightImage.map { Image(uiImage: $0) } ?? Image(systemName: "app")
    }

    // MARK: - Rendering / writes

    private func regenerate() {
        lightImage   = IconRenderer.render(project, side: 1024, includeBackground: true)
        darkImage    = IconRenderer.render(project, side: 1024, includeBackground: false)
        tintedImage  = IconRenderer.renderTinted(project, side: 1024)
        rebuildSinglePNG()
        rebuildPlayStore()
        rebuildFavicons()
        rebuildAppleSet()
    }

    private func rebuildSinglePNG() {
        guard let light = lightImage, let data = light.pngData() else {
            lightPNGURL = nil
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedFilename(displayTitle)).png")
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try data.write(to: url)
            lightPNGURL = url
        } catch {
            lightPNGURL = nil
        }
    }

    private func rebuildPlayStore() {
        guard let light = lightImage else {
            playStoreURL = nil
            return
        }
        do {
            playStoreURL = try PlayStoreIconExporter.writeBundle(light: light, baseName: displayTitle)
        } catch {
            playStoreURL = nil
        }
    }

    private func rebuildFavicons() {
        guard let light = lightImage else {
            faviconsURL = nil
            return
        }
        do {
            faviconsURL = try FaviconExporter.writeBundle(light: light, baseName: displayTitle)
        } catch {
            faviconsURL = nil
        }
    }

    private func rebuildAppleSet() {
        guard let light = lightImage else {
            iconSetURL = nil
            return
        }
        do {
            iconSetURL = try AppIconSetExporter.writeAppIconSet(
                variants: .init(light: light, dark: darkImage, tinted: tintedImage),
                platforms: [.iOS, .macOS, .watchOS],
                baseName: displayTitle
            )
            error = nil
        } catch {
            self.error = error.localizedDescription
            iconSetURL = nil
        }
    }

    private func sanitizedFilename(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        let chars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let cleaned = String(chars).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return cleaned.isEmpty ? "AppIcon" : cleaned
    }
}

// MARK: - Format card

private struct ExportFormatCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let url: URL?
    let previewTitle: String
    let previewImage: Image

    var body: some View {
        if let url {
            ShareLink(
                item: url,
                preview: SharePreview(previewTitle, image: previewImage)
            ) {
                cardContent(isReady: true)
            }
            .buttonStyle(.plain)
        } else {
            cardContent(isReady: false)
        }
    }

    private func cardContent(isReady: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PanelStyle.rowFillActive)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(isReady ? subtitle : "Preparing…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "square.and.arrow.up")
                .font(.body.weight(.medium))
                .foregroundStyle(isReady ? Color.primary : Color.secondary.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
        .opacity(isReady ? 1 : 0.55)
    }
}
