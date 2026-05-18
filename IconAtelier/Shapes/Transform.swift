import SwiftUI

struct TransformedShape: Shape {
    var base: AnyShape
    var stretchX: Double
    var stretchY: Double
    var rotationDegrees: Double

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        guard side > 0 else { return Path() }

        let baseRect = CGRect(
            x: -side / 2, y: -side / 2, width: side, height: side
        )
        let basePath = base.path(in: baseRect)
        if basePath.isEmpty { return Path() }

        let rad = rotationDegrees * .pi / 180
        let sx = max(0.01, stretchX)
        let sy = max(0.01, stretchY)
        let rotateThenScale = CGAffineTransform(rotationAngle: CGFloat(rad))
            .concatenating(CGAffineTransform(scaleX: CGFloat(sx), y: CGFloat(sy)))
        let transformed = basePath.applying(rotateThenScale)

        let bbox = transformed.boundingRect
        guard bbox.width > 0, bbox.height > 0 else { return Path() }

        let fit = CGFloat(side) / max(bbox.width, bbox.height)
        let fitTransform = CGAffineTransform.identity
            .translatedBy(x: rect.midX, y: rect.midY)
            .scaledBy(x: fit, y: fit)
            .translatedBy(x: -bbox.midX, y: -bbox.midY)
        return transformed.applying(fitTransform)
    }
}
