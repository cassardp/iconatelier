import SwiftUI
import UIKit

enum IconRenderer {
    @MainActor
    static func render(_ project: IconProject, side: CGFloat) -> UIImage? {
        let view = ZStack {
            if let bg = project.background, !bg.isHidden {
                BackgroundView(background: bg, side: side)
            }
            ForEach(project.layers) { layer in
                if !layer.isHidden {
                    let s = CGFloat(layer.scale)
                    LayerContentView(layer: layer, side: side, scale: s)
                        .shadow(
                            color: .black.opacity(layer.shadowOpacity),
                            radius: side * CGFloat(layer.shadowRadius) * s,
                            x: side * CGFloat(layer.shadowOffsetX) * s,
                            y: side * CGFloat(layer.shadowOffsetY) * s
                        )
                        .rotationEffect(layer.rotation)
                        .opacity(layer.opacity)
                        .offset(
                            x: layer.offset.width * side,
                            y: layer.offset.height * side
                        )
                }
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
    static func updateThumbnail(_ project: IconProject) {
        let img = render(project, side: 512)
        project.thumbnailPNG = img?.pngData()
        project.updatedAt = .now
    }
}
