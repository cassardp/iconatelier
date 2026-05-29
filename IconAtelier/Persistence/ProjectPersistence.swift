import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum IconRenderer {
    @MainActor
    static func render(
        _ project: IconProject,
        side: CGFloat,
        includeBackground: Bool = true
    ) -> UIImage? {
        let view = ZStack {
            if includeBackground, let bg = project.background {
                BackgroundView(background: bg, side: side)
            }
            ForEach(project.layers) { layer in
                LayerView(layer: layer, side: side)
            }
        }
        .frame(width: side, height: side)
        .compositingGroup()

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = .init(width: side, height: side)
        return renderer.uiImage
    }

    @MainActor
    static func renderBackground(_ project: IconProject, side: CGFloat) -> UIImage? {
        guard let bg = project.background else { return nil }
        let view = BackgroundView(background: bg, side: side)
            .frame(width: side, height: side)
            .compositingGroup()

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = .init(width: side, height: side)
        return renderer.uiImage
    }

    @MainActor
    static func renderLayer(_ layer: Layer, side: CGFloat) -> UIImage? {
        let view = LayerView(layer: layer, side: side)
            .frame(width: side, height: side)
            .compositingGroup()

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = .init(width: side, height: side)
        return renderer.uiImage
    }

    @MainActor
    static func renderTinted(_ project: IconProject, side: CGFloat) -> UIImage? {
        guard let foreground = render(project, side: side, includeBackground: false),
              let ciForeground = CIImage(image: foreground) else { return nil }

        let desaturate = CIFilter.colorControls()
        desaturate.inputImage = ciForeground
        desaturate.saturation = 0
        guard let mono = desaturate.outputImage else { return nil }

        let black = CIImage(color: CIColor.black).cropped(to: ciForeground.extent)
        let composed = mono.composited(over: black)

        let context = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
        guard let cg = context.createCGImage(composed, from: composed.extent) else { return nil }
        return UIImage(cgImage: cg, scale: 1.0, orientation: .up)
    }

    @MainActor
    static func updateThumbnail(_ project: IconProject) {
        let img = render(project, side: 512)
        project.thumbnailPNG = img?.pngData()
        project.updatedAt = .now
    }
}
