#if DEBUG
import SwiftUI
import UIKit

enum DevSampleAssets {
    static let canvasSide: CGFloat = 1024

    static func makeBackground() -> UIImage {
        let size = CGSize(width: canvasSide, height: canvasSide)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.36, green: 0.20, blue: 0.95, alpha: 1.0).cgColor,
                UIColor(red: 0.92, green: 0.36, blue: 0.55, alpha: 1.0).cgColor,
                UIColor(red: 1.00, green: 0.78, blue: 0.36, alpha: 1.0).cgColor
            ]
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(
                colorsSpace: space,
                colors: colors as CFArray,
                locations: [0.0, 0.55, 1.0]
            )!
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }

    static func makeOverlay() -> UIImage {
        let size = CGSize(width: canvasSide, height: canvasSide)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let config = UIImage.SymbolConfiguration(pointSize: 640, weight: .bold)
            let base = UIImage(systemName: "sparkles", withConfiguration: config)
                ?? UIImage(systemName: "star.fill", withConfiguration: config)
            guard let symbol = base?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
                return
            }
            let rect = CGRect(
                x: (size.width - symbol.size.width) / 2,
                y: (size.height - symbol.size.height) / 2,
                width: symbol.size.width,
                height: symbol.size.height
            )
            symbol.draw(in: rect)
        }
    }
}

extension IconProject {
    static func devSample() -> IconProject {
        let project = IconProject()
        project.setOrReplaceBackground(
            image: DevSampleAssets.makeBackground(),
            prompt: "Dev sample · gradient"
        )
        project.addOverlay(
            image: DevSampleAssets.makeOverlay(),
            prompt: "Dev sample · sparkles"
        )
        project.selectedLayerID = project.overlays.first?.id
        project.clearHistory()
        return project
    }
}
#endif
