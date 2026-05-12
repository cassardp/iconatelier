import SwiftUI
import UIKit

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: IconProject

    @State private var includeDark: Bool = true
    @State private var includeTinted: Bool = true

    @State private var includeIOS: Bool = true
    @State private var includeMacOS: Bool = false
    @State private var includeWatchOS: Bool = false

    @State private var lightImage: UIImage?
    @State private var darkImage: UIImage?
    @State private var tintedImage: UIImage?

    @State private var preparedURL: URL?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        VariantPreview(
                            title: "Light",
                            image: lightImage,
                            style: .light,
                            isSelected: .constant(true),
                            isLocked: true
                        )
                        VariantPreview(
                            title: "Dark",
                            image: darkImage,
                            style: .dark,
                            isSelected: $includeDark,
                            isLocked: false
                        )
                        VariantPreview(
                            title: "Tinted",
                            image: tintedImage,
                            style: .tinted,
                            isSelected: $includeTinted,
                            isLocked: false
                        )
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                } footer: {
                    Text("Tap a variant to include or exclude it. Light is always included.")
                }

                Section {
                    Toggle("iOS", isOn: $includeIOS)
                    Toggle("macOS", isOn: $includeMacOS)
                    Toggle("watchOS", isOn: $includeWatchOS)
                } header: {
                    Text("Platforms")
                } footer: {
                    Text("visionOS isn't supported — its app icons use a layered .solidimagestack format with two or three parallax layers.")
                }

                Section {
                    if let preparedURL, hasAnyPlatform {
                        ShareLink(
                            item: preparedURL,
                            preview: SharePreview(
                                "\(project.title) AppIcon",
                                image: lightImage.map { Image(uiImage: $0) } ?? Image(systemName: "app")
                            )
                        ) {
                            Label("Save Icon Set", systemImage: "square.and.arrow.up")
                        }
                    } else if !hasAnyPlatform {
                        Label("Select at least one platform", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Preparing…", systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Exports an .appiconset folder. Drag it into your Xcode project's asset catalog.")
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .task { regenerate() }
            .onChange(of: includeDark) { _, _ in rebuildURL() }
            .onChange(of: includeTinted) { _, _ in rebuildURL() }
            .onChange(of: includeIOS) { _, _ in rebuildURL() }
            .onChange(of: includeMacOS) { _, _ in rebuildURL() }
            .onChange(of: includeWatchOS) { _, _ in rebuildURL() }
        }
    }

    private var hasAnyPlatform: Bool {
        includeIOS || includeMacOS || includeWatchOS
    }

    private var selectedPlatforms: AppIconSetExporter.Platforms {
        var result: AppIconSetExporter.Platforms = []
        if includeIOS { result.insert(.iOS) }
        if includeMacOS { result.insert(.macOS) }
        if includeWatchOS { result.insert(.watchOS) }
        return result
    }

    private func regenerate() {
        lightImage = IconRenderer.render(project, side: 1024, includeBackground: true)
        darkImage = IconRenderer.render(project, side: 1024, includeBackground: false)
        tintedImage = IconRenderer.renderTinted(project, side: 1024)
        rebuildURL()
    }

    private func rebuildURL() {
        guard let light = lightImage, hasAnyPlatform else {
            preparedURL = nil
            return
        }
        do {
            let url = try AppIconSetExporter.writeAppIconSet(
                variants: .init(
                    light: light,
                    dark: includeIOS && includeDark ? darkImage : nil,
                    tinted: includeIOS && includeTinted ? tintedImage : nil
                ),
                platforms: selectedPlatforms,
                baseName: project.title.isEmpty ? "AppIcon" : project.title
            )
            preparedURL = url
            error = nil
        } catch {
            self.error = error.localizedDescription
            preparedURL = nil
        }
    }
}

private struct VariantPreview: View {
    enum Style {
        case light
        case dark
        case tinted
    }

    let title: String
    let image: UIImage?
    let style: Style
    @Binding var isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                background
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                            lineWidth: isSelected ? 2 : 1)
            )
            .opacity(isLocked || isSelected ? 1 : 0.4)

            Text(title)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.primary : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isLocked else { return }
            isSelected.toggle()
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .light:
            Color.clear
        case .dark:
            LinearGradient(
                colors: [Color(red: 0.192, green: 0.192, blue: 0.192),
                         Color(red: 0.078, green: 0.078, blue: 0.078)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .tinted:
            Color.black
        }
    }
}
