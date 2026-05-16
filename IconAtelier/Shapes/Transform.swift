import SwiftUI

// Generic transform wrapper: take any Shape, apply a per-axis stretch and
// additional rotation, then refit the resulting bounding box to the target
// rect. Used by `.transform` ShapeSpec wrappers over non-polygon bases
// (`.iosSquircle`, `.customPath`) — `.polygon` bases push the same
// parameters into `StarPolygonShape`'s intrinsic fields, which is
// mathematically equivalent and avoids a second Path walk.
struct TransformedShape: Shape {
    var base: AnyShape
    var stretchX: Double
    var stretchY: Double
    var rotationDegrees: Double

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        guard side > 0 else { return Path() }

        // Render the base into a square centered on the origin so rotation
        // is a pure rotation around the shape's center.
        let baseRect = CGRect(
            x: -side / 2, y: -side / 2, width: side, height: side
        )
        let basePath = base.path(in: baseRect)
        if basePath.isEmpty { return Path() }

        // Rotate first, then stretch — matches the in-vertex order used by
        // StarPolygonShape for polygon bases so visual behavior agrees
        // across families.
        let rad = rotationDegrees * .pi / 180
        let sx = max(0.01, stretchX)
        let sy = max(0.01, stretchY)
        let rotateThenScale = CGAffineTransform(rotationAngle: CGFloat(rad))
            .concatenating(CGAffineTransform(scaleX: CGFloat(sx), y: CGFloat(sy)))
        let transformed = basePath.applying(rotateThenScale)

        let bbox = transformed.boundingRect
        guard bbox.width > 0, bbox.height > 0 else { return Path() }

        // Uniformly fit the transformed bbox into the target rect (touching
        // along its longer axis), recentered on the rect midpoint. Same
        // strategy as `StarPolygonShape.path(in:)` so a stretched square
        // and a stretched custom-path look like siblings, not strangers.
        let fit = CGFloat(side) / max(bbox.width, bbox.height)
        let fitTransform = CGAffineTransform.identity
            .translatedBy(x: rect.midX, y: rect.midY)
            .scaledBy(x: fit, y: fit)
            .translatedBy(x: -bbox.midX, y: -bbox.midY)
        return transformed.applying(fitTransform)
    }
}
