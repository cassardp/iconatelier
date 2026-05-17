import SwiftUI
import UIKit

enum BooleanOpKind: Hashable, CaseIterable {
    case union, subtract, intersect

    var label: String {
        switch self {
        case .union:     return "Union"
        case .subtract:  return "Subtract"
        case .intersect: return "Intersect"
        }
    }

    var systemImage: String {
        switch self {
        case .union:     return "plus"
        case .subtract:  return "minus"
        case .intersect: return "circle.righthalf.filled"
        }
    }
}

struct BooleanOpResult {
    let image: UIImage
    /// Crop center in normalized canvas coordinates (-0.5 ... 0.5, origin at canvas center).
    let centerInUnit: CGPoint
    /// Crop side length in normalized canvas units (0 ... 1).
    let sizeInUnit: CGFloat
}

/// Vector-mode boolean result. Carries a Path expressed in canvas-centered
/// coordinates (origin = canvas center, units = pixels of `workingPixelSide`)
/// so callers can derive the new layer's offset and scale by inspecting the
/// path's bounding box. Path content is the raw silhouette — no per-layer
/// border, shadow, or fill — which matches user intent: the boolean op
/// freezes the *shape* of the combination, not its current styling.
struct BooleanVectorResult {
    let path: Path
    /// The canvas side used to express coordinates; callers normalize the
    /// path's bbox against this to derive a (-0.5...0.5) offset and a
    /// 0...1 size in canvas units.
    let canvasSide: CGFloat
}

enum BooleanOpRenderer {
    /// Pixel side of the working canvas. The boolean op runs on this square.
    /// Chosen large enough that even after cropping a small intersection we still
    /// keep a decent number of pixels for the resulting overlay.
    static let workingPixelSide: CGFloat = 1024

    /// Try to compose `layers` as a single vector path. Returns nil if any
    /// source layer can't be expressed as a Path (image) — caller
    /// should fall back to the raster `compose` path. When successful, the
    /// caller gets a Path expressed in canvas-centered pixel coords; the
    /// new layer's offset and scale can be derived from the path's bbox.
    @MainActor
    static func vectorCompose(
        layers: [Layer],
        op: BooleanOpKind
    ) -> BooleanVectorResult? {
        let visible = layers
            .filter { !$0.isHidden }
            .sorted { $0.orderIndex < $1.orderIndex }
        guard visible.count >= 2 else { return nil }

        let canvasSide = workingPixelSide
        var sourcePaths: [CGPath] = []
        sourcePaths.reserveCapacity(visible.count)
        for layer in visible {
            guard let p = vectorPath(for: layer, canvasSide: canvasSide) else {
                return nil
            }
            sourcePaths.append(p.cgPath)
        }
        guard sourcePaths.count >= 2 else { return nil }

        // `.winding` matches what SwiftUI's `shape.fill(color)` renders by
        // default (non-zero winding). `.evenOdd` would turn every overlap
        // between sub-paths into a hole — that's visible mostly with
        // `RadialRepeat`, whose petals overlap their neighbours and (with a
        // negative `centerHole`) cross through the center.
        var combined = sourcePaths[0]
        for next in sourcePaths.dropFirst() {
            switch op {
            case .union:
                combined = combined.union(next, using: .winding)
            case .intersect:
                combined = combined.intersection(next, using: .winding)
            case .subtract:
                combined = combined.subtracting(next, using: .winding)
            }
        }
        let path = Path(combined)
        guard !path.isEmpty else { return nil }
        return BooleanVectorResult(path: path, canvasSide: canvasSide)
    }

    /// Build the Path representation of a layer in canvas-centered pixel
    /// coordinates. Bakes offset/rotation/flip/scale into the path so the
    /// boolean op can operate on independent vectors. Returns nil for kinds
    /// that have no native vector silhouette (image).
    @MainActor
    private static func vectorPath(for layer: Layer, canvasSide: CGFloat) -> Path? {
        let shape: AnyShape
        let baseSide: CGFloat
        switch layer.kind {
        case .parametricShape:
            guard let spec = layer.shapeSpec else { return nil }
            // Mirrors `LayerContentView.parametricShape` — same shape, same
            // 0.5×canvas base frame, so the silhouette matches what's drawn.
            shape = spec.anyShape()
            baseSide = canvasSide * 0.5
        case .text:
            let glyph = TextGlyphShape(
                text: layer.text,
                weight: layer.fontWeight,
                design: layer.fontDesign
            )
            if let params = layer.shapeSpec?.radialRepeatParams {
                shape = AnyShape(RadialRepeat(
                    base: glyph,
                    count: params.count,
                    centerHole: params.centerHole
                ))
            } else {
                shape = AnyShape(glyph)
            }
            baseSide = canvasSide * 0.6
        case .image:
            return nil
        }

        let shapeSide = baseSide * CGFloat(layer.scale)
        // Draw the shape into a square centered at the origin so the
        // affine transform below can rotate around its center naturally.
        let rect = CGRect(
            x: -shapeSide / 2,
            y: -shapeSide / 2,
            width: shapeSide,
            height: shapeSide
        )

        // Same transform order as `IconCanvasView`: flip (innermost) →
        // rotate → translate (outermost). CGAffineTransform's chained
        // builders right-multiply, so `.scaledBy.rotated.translatedBy`
        // applies flip first, then rotate, then translate when a point
        // is passed through `.applying(_:)`.
        var t = CGAffineTransform.identity
        if layer.isFlippedHorizontally { t = t.scaledBy(x: -1, y: 1) }
        if layer.isFlippedVertically { t = t.scaledBy(x: 1, y: -1) }
        t = t.rotated(by: CGFloat(layer.rotationRadians))
        t = t.translatedBy(
            x: layer.offset.width * canvasSide,
            y: layer.offset.height * canvasSide
        )
        return shape.path(in: rect).applying(t)
    }

    /// Render N layers into a square canvas, apply the boolean op via CGBlendMode,
    /// then crop the result to a square bounding box of its visible pixels.
    @MainActor
    static func compose(
        layers: [Layer],
        op: BooleanOpKind
    ) -> BooleanOpResult? {
        let visible = layers
            .filter { !$0.isHidden }
            .sorted { $0.orderIndex < $1.orderIndex }
        guard visible.count >= 2 else { return nil }

        let side = workingPixelSide
        var images: [UIImage] = []
        images.reserveCapacity(visible.count)
        for layer in visible {
            guard let img = rasterize(layer, side: side) else { continue }
            images.append(img)
        }
        guard images.count >= 2 else { return nil }

        guard let composite = composite(images: images, op: op, side: side) else {
            return nil
        }
        return cropToContentBounds(composite, canvasSide: side)
    }

    // MARK: - Per-layer rasterization

    @MainActor
    private static func rasterize(_ layer: Layer, side: CGFloat) -> UIImage? {
        let view = LayerForBooleanRender(layer: layer, side: side)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        renderer.isOpaque = false
        return renderer.uiImage
    }

    // MARK: - Compositing with CGBlendMode

    private static func composite(
        images: [UIImage],
        op: BooleanOpKind,
        side: CGFloat
    ) -> UIImage? {
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let fullRect = CGRect(origin: .zero, size: size)
        return renderer.image { _ in
            switch op {
            case .union:
                // Plain source-over of every layer — overlap area stays opaque.
                for image in images {
                    image.draw(in: fullRect, blendMode: .normal, alpha: 1)
                }

            case .subtract:
                // Bottom layer is the base, each upper layer punches a hole.
                images[0].draw(in: fullRect, blendMode: .normal, alpha: 1)
                for image in images.dropFirst() {
                    image.draw(in: fullRect, blendMode: .destinationOut, alpha: 1)
                }

            case .intersect:
                // Bottom layer provides the pixels (colors stay intact); each
                // upper layer acts as a mask via destinationIn — only the area
                // covered by every upper silhouette survives.
                images[0].draw(in: fullRect, blendMode: .normal, alpha: 1)
                for image in images.dropFirst() {
                    image.draw(in: fullRect, blendMode: .destinationIn, alpha: 1)
                }
            }
        }
    }

    // MARK: - Cropping to non-transparent bounding box

    /// Scan the alpha channel, find the bbox of pixels above a small threshold,
    /// then crop a square (max of width/height + padding) around the centroid.
    private static func cropToContentBounds(
        _ image: UIImage,
        canvasSide: CGFloat
    ) -> BooleanOpResult? {
        guard let cgImage = image.cgImage else { return nil }
        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: w * h * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let info: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let scanCtx = CGContext(
            data: &pixels,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: info
        ) else { return nil }
        scanCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        let threshold: UInt8 = 6
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let rowOffset = y * bytesPerRow
            for x in 0..<w {
                let alpha = pixels[rowOffset + x * bytesPerPixel + 3]
                if alpha > threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        let bboxWidth = maxX - minX + 1
        let bboxHeight = maxY - minY + 1
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let padding = 8
        let squareSide = max(bboxWidth, bboxHeight) + padding * 2
        let originX = centerX - squareSide / 2
        let originY = centerY - squareSide / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let crop = UIGraphicsImageRenderer(
            size: CGSize(width: squareSide, height: squareSide),
            format: format
        ).image { _ in
            let drawRect = CGRect(
                x: -CGFloat(originX),
                y: -CGFloat(originY),
                width: CGFloat(w),
                height: CGFloat(h)
            )
            image.draw(in: drawRect)
        }

        let center = CGPoint(
            x: CGFloat(centerX) / CGFloat(w) - 0.5,
            y: CGFloat(centerY) / CGFloat(h) - 0.5
        )
        let sizeUnit = CGFloat(squareSide) / canvasSide

        return BooleanOpResult(image: crop, centerInUnit: center, sizeInUnit: sizeUnit)
    }
}

// MARK: - Stripped-down layer view for rasterization

/// Mirrors `OverlayLayerRender` but without the drop shadow — boolean ops should
/// operate on the layer silhouette only. Otherwise the soft shadow alpha would
/// participate in `.destinationIn` / `.destinationOut` masks and produce ghosting.
private struct LayerForBooleanRender: View {
    let layer: Layer
    let side: CGFloat

    var body: some View {
        ZStack {
            Color.clear
            LayerContentView(layer: layer, side: side, scale: layer.scale)
                .rotationEffect(layer.rotation)
                .opacity(layer.opacity)
                .offset(
                    x: layer.offset.width * side,
                    y: layer.offset.height * side
                )
        }
        .frame(width: side, height: side)
    }
}
