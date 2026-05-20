import SwiftUI
import UIKit

enum BooleanOpKind: Hashable, CaseIterable {
    case union, intersect, subtract

    var label: String {
        switch self {
        case .union:     return "Union"
        case .subtract:  return "Subtract"
        case .intersect: return "Intersect"
        }
    }

    @ViewBuilder
    var icon: some View {
        switch self {
        case .union:     Image(systemName: "plus")
        case .subtract:  Image(systemName: "minus")
        case .intersect: Image(systemName: "line.diagonal")
        }
    }
}

struct BooleanOpResult {
    let image: UIImage

    let centerInUnit: CGPoint

    let sizeInUnit: CGFloat
}

struct BooleanVectorResult {
    let path: Path

    let canvasSide: CGFloat
}

enum BooleanOpRenderer {

    static let workingPixelSide: CGFloat = 1024

    @MainActor
    static func vectorCompose(
        layers: [Layer],
        op: BooleanOpKind
    ) -> BooleanVectorResult? {
        guard layers.count >= 2 else { return nil }

        let canvasSide = workingPixelSide
        var sourcePaths: [CGPath] = []
        sourcePaths.reserveCapacity(layers.count)
        for layer in layers {
            guard let p = vectorPath(for: layer, canvasSide: canvasSide) else {
                return nil
            }
            sourcePaths.append(p.cgPath)
        }
        guard sourcePaths.count >= 2 else { return nil }

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

    @MainActor
    private static func vectorPath(for layer: Layer, canvasSide: CGFloat) -> Path? {
        let shape: AnyShape
        let baseSide: CGFloat
        switch layer.kind {
        case .parametricShape:
            guard let spec = layer.shapeSpec else { return nil }

            shape = ShapeRenderer.anyShape(for: spec)
            baseSide = canvasSide * LayerGeometry.baseUnitFraction(for: .parametricShape)
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
                    centerHole: params.centerHole,
                    orientation: params.orientation
                ))
            } else {
                shape = AnyShape(glyph)
            }
            baseSide = canvasSide * LayerGeometry.baseUnitFraction(for: .text)
        case .image:
            return nil
        }

        let shapeSide = baseSide * CGFloat(layer.scale)

        let rect = CGRect(
            x: -shapeSide / 2,
            y: -shapeSide / 2,
            width: shapeSide,
            height: shapeSide
        )

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

    @MainActor
    static func compose(
        layers: [Layer],
        op: BooleanOpKind
    ) -> BooleanOpResult? {
        guard layers.count >= 2 else { return nil }

        let side = workingPixelSide
        var images: [UIImage] = []
        images.reserveCapacity(layers.count)
        for layer in layers {
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
        let view = ZStack {
            Color.clear
            LayerView(layer: layer, side: side, includeEffects: false)
        }
        .frame(width: side, height: side)
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

                for image in images {
                    image.draw(in: fullRect, blendMode: .normal, alpha: 1)
                }

            case .subtract:

                images[0].draw(in: fullRect, blendMode: .normal, alpha: 1)
                for image in images.dropFirst() {
                    image.draw(in: fullRect, blendMode: .destinationOut, alpha: 1)
                }

            case .intersect:

                images[0].draw(in: fullRect, blendMode: .normal, alpha: 1)
                for image in images.dropFirst() {
                    image.draw(in: fullRect, blendMode: .destinationIn, alpha: 1)
                }
            }
        }
    }

    // MARK: - Cropping to non-transparent bounding box

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

