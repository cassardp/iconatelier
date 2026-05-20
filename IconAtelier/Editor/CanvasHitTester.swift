import SwiftUI
import UIKit

enum CanvasHitTester {

    static func hitTestLayer(
        in project: IconProject,
        at point: CGPoint,
        side: CGFloat,
        canvasSize: CGSize
    ) -> Layer? {
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        for layer in project.layers.reversed() {
            guard !layer.isLocked else { continue }
            let halfSide = LayerGeometry.frameSide(for: layer, canvasSide: side) / 2
            guard halfSide > 0 else { continue }
            let layerCenterX = centerX + layer.offset.width * side
            let layerCenterY = centerY + layer.offset.height * side
            let dx = point.x - layerCenterX
            let dy = point.y - layerCenterY
            let angle = -CGFloat(layer.rotation.radians)
            let cosA = cos(angle)
            let sinA = sin(angle)
            let rx = dx * cosA - dy * sinA
            let ry = dx * sinA + dy * cosA
            guard abs(rx) <= halfSide && abs(ry) <= halfSide else { continue }
            if layer.kind == .image {
                let frameSide = halfSide * 2
                if imageHasOpaquePixel(in: layer, atLocal: CGPoint(x: rx, y: ry), frameSide: frameSide) {
                    return layer
                }
                continue
            }
            if layer.kind == .parametricShape {
                if parametricShapeContains(layer: layer, localX: rx, localY: ry, halfSide: halfSide) {
                    return layer
                }
                continue
            }
            return layer
        }
        return nil
    }

    static func parametricShapeContains(
        layer: Layer,
        localX: CGFloat,
        localY: CGFloat,
        halfSide: CGFloat
    ) -> Bool {
        guard let spec = layer.shapeSpec, halfSide > 0 else { return true }
        if spec.isOpenPath { return true }
        let lx = layer.isFlippedHorizontally ? -localX : localX
        let ly = layer.isFlippedVertically ? -localY : localY
        let shapeSide = halfSide * 2
        let path = spec.anyShape().path(in: CGRect(x: 0, y: 0, width: shapeSide, height: shapeSide))
        let pathPoint = CGPoint(x: lx + halfSide, y: ly + halfSide)
        if path.contains(pathPoint) { return true }
        let borderWidth = shapeSide * CGFloat(layer.borderWidth)
        if borderWidth > 0 {
            let stroked = path.strokedPath(StrokeStyle(lineWidth: borderWidth * 2))
            return stroked.contains(pathPoint)
        }
        return false
    }

    static func imageHasOpaquePixel(
        in layer: Layer,
        atLocal point: CGPoint,
        frameSide: CGFloat
    ) -> Bool {
        guard let uiImage = layer.image, let cgImage = uiImage.cgImage else { return true }
        let lx = layer.isFlippedHorizontally ? -point.x : point.x
        let ly = layer.isFlippedVertically ? -point.y : point.y
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        guard w > 0, h > 0, frameSide > 0 else { return true }
        let aspect = w / h
        let renderedW: CGFloat
        let renderedH: CGFloat
        if aspect >= 1 {
            renderedW = frameSide
            renderedH = frameSide / aspect
        } else {
            renderedW = frameSide * aspect
            renderedH = frameSide
        }
        let imgX = lx + renderedW / 2
        let imgY = ly + renderedH / 2
        guard imgX >= 0, imgX < renderedW, imgY >= 0, imgY < renderedH else { return false }
        let px = Int((imgX / renderedW * w).rounded(.down))
        let py = Int((imgY / renderedH * h).rounded(.down))
        let clampedX = max(0, min(cgImage.width - 1, px))
        let clampedY = max(0, min(cgImage.height - 1, py))
        return sampleAlpha(cgImage: cgImage, x: clampedX, y: clampedY) > 0.05
    }

    static func sampleAlpha(cgImage: CGImage, x: Int, y: Int) -> CGFloat {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return 1 }
        context.interpolationQuality = .none
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let drawRect = CGRect(
            x: -CGFloat(x),
            y: CGFloat(y) - height + 1,
            width: width,
            height: height
        )
        context.draw(cgImage, in: drawRect)
        return CGFloat(pixel[3]) / 255.0
    }
}
