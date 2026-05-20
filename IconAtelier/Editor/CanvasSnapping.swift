import SwiftUI

struct SnapGuide: Equatable {
    enum Orientation: Hashable { case vertical, horizontal }
    let orientation: Orientation
    let position: CGFloat
    let extentStart: CGFloat
    let extentEnd: CGFloat
}

struct DragSnapState: Equatable {
    var translation: CGSize = .zero
    var objectGuides: [SnapGuide] = []
    var isActive: Bool = false
}

struct RotationSnapState: Equatable {
    var delta: Angle = .zero
    var isSnapped: Bool = false
}

enum CanvasSnapping {

    static let rotationSnapThresholdDegrees: Double = 5
    static let objectSnapThresholdPoints: CGFloat = 6

    // MARK: - Layer bounding box in normalized canvas units

    static func layerNormalizedBounds(_ layer: Layer) -> CGRect {
        let frame = LayerGeometry.baseUnitFraction(for: layer.kind) * layer.scale
        var unitCenterX: CGFloat = 0
        var unitCenterY: CGFloat = 0
        var unitHalfW: CGFloat = 0.5
        var unitHalfH: CGFloat = 0.5
        if layer.kind == .image,
           let img = layer.image,
           img.size.width > 0, img.size.height > 0 {
            let aspect = img.size.width / img.size.height
            if aspect >= 1 {
                unitHalfH = 0.5 / aspect
            } else {
                unitHalfW = 0.5 * aspect
            }
        } else if layer.kind == .parametricShape, let spec = layer.shapeSpec {
            let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
            let path = spec.anyShape().path(in: unit)
            let pathRect = path.boundingRect
            if pathRect.width > 0, pathRect.height > 0 {
                unitCenterX = pathRect.midX - 0.5
                unitCenterY = pathRect.midY - 0.5
                unitHalfW = pathRect.width / 2
                unitHalfH = pathRect.height / 2
            }
        }
        if layer.isFlippedHorizontally { unitCenterX = -unitCenterX }
        if layer.isFlippedVertically { unitCenterY = -unitCenterY }
        let theta = CGFloat(layer.rotation.radians)
        let cosT = cos(theta)
        let sinT = sin(theta)
        let corners: [(CGFloat, CGFloat)] = [
            (unitCenterX - unitHalfW, unitCenterY - unitHalfH),
            (unitCenterX + unitHalfW, unitCenterY - unitHalfH),
            (unitCenterX - unitHalfW, unitCenterY + unitHalfH),
            (unitCenterX + unitHalfW, unitCenterY + unitHalfH)
        ]
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        for (x, y) in corners {
            let rx = x * cosT - y * sinT
            let ry = x * sinT + y * cosT
            minX = min(minX, rx)
            maxX = max(maxX, rx)
            minY = min(minY, ry)
            maxY = max(maxY, ry)
        }
        let width = (maxX - minX) * frame
        let height = (maxY - minY) * frame
        let centerOffsetX = (minX + maxX) / 2 * frame
        let centerOffsetY = (minY + maxY) / 2 * frame
        return CGRect(
            x: layer.offset.width + centerOffsetX - width / 2,
            y: layer.offset.height + centerOffsetY - height / 2,
            width: width,
            height: height
        )
    }

    // MARK: - Snapping to other-layer edges/centers

    static func snappedToLayerGuides(
        translation: CGSize,
        draggedBounds: CGRect,
        others: [Layer],
        side: CGFloat
    ) -> (effective: CGSize, guides: [SnapGuide]) {
        guard side > 0 else { return (translation, []) }
        let threshold = objectSnapThresholdPoints / side
        let dx = translation.width / side
        let dy = translation.height / side
        let candidate = draggedBounds.offsetBy(dx: dx, dy: dy)
        var xTargets: [(pos: CGFloat, source: CGRect, isLayerCenter: Bool)] = [
            (-0.5, CGRect(x: -0.5, y: -0.5, width: 0, height: 1), false),
            (0,    CGRect(x: 0,    y: -0.5, width: 0, height: 1), false),
            (0.5,  CGRect(x: 0.5,  y: -0.5, width: 0, height: 1), false)
        ]
        var yTargets: [(pos: CGFloat, source: CGRect, isLayerCenter: Bool)] = [
            (-0.5, CGRect(x: -0.5, y: -0.5, width: 1, height: 0), false),
            (0,    CGRect(x: -0.5, y: 0,    width: 1, height: 0), false),
            (0.5,  CGRect(x: -0.5, y: 0.5,  width: 1, height: 0), false)
        ]
        for other in others {
            let b = layerNormalizedBounds(other)
            xTargets.append((b.minX, b, false))
            xTargets.append((b.midX, b, true))
            xTargets.append((b.maxX, b, false))
            yTargets.append((b.minY, b, false))
            yTargets.append((b.midY, b, true))
            yTargets.append((b.maxY, b, false))
        }
        let candXs: [CGFloat] = [candidate.minX, candidate.midX, candidate.maxX]
        let candYs: [CGFloat] = [candidate.minY, candidate.midY, candidate.maxY]
        func bestSnap(
            candidates: [CGFloat],
            targets: [(pos: CGFloat, source: CGRect, isLayerCenter: Bool)]
        ) -> (delta: CGFloat, guideAt: CGFloat, source: CGRect)? {
            var best: (delta: CGFloat, guideAt: CGFloat, source: CGRect)?
            for c in candidates {
                for t in targets where !t.isLayerCenter {
                    let d = t.pos - c
                    if abs(d) < threshold,
                       best == nil || abs(d) < abs(best!.delta) {
                        best = (d, t.pos, t.source)
                    }
                }
            }
            if best != nil { return best }
            for c in candidates {
                for t in targets where t.isLayerCenter {
                    let d = t.pos - c
                    if abs(d) < threshold,
                       best == nil || abs(d) < abs(best!.delta) {
                        best = (d, t.pos, t.source)
                    }
                }
            }
            return best
        }
        let bestX = bestSnap(candidates: candXs, targets: xTargets)
        let bestY = bestSnap(candidates: candYs, targets: yTargets)
        var effective = translation
        var guides: [SnapGuide] = []
        if let bx = bestX {
            effective.width += bx.delta * side
            let yMin = min(candidate.minY, bx.source.minY)
            let yMax = max(candidate.maxY, bx.source.maxY)
            guides.append(SnapGuide(
                orientation: .vertical,
                position: bx.guideAt,
                extentStart: yMin,
                extentEnd: yMax
            ))
        }
        if let by = bestY {
            effective.height += by.delta * side
            let xMin = min(candidate.minX, by.source.minX)
            let xMax = max(candidate.maxX, by.source.maxX)
            guides.append(SnapGuide(
                orientation: .horizontal,
                position: by.guideAt,
                extentStart: xMin,
                extentEnd: xMax
            ))
        }
        return (effective, guides)
    }

    // MARK: - Rotation snapping

    static func normalized(_ angle: Angle) -> Angle {
        let d = angle.degrees
        guard d.isFinite else { return .zero }
        let r = d.truncatingRemainder(dividingBy: 360)
        if r > 180 { return .degrees(r - 360) }
        if r <= -180 { return .degrees(r + 360) }
        return .degrees(r)
    }

    static func snappedRotation(
        layerRotation: Angle,
        rawDelta: Angle
    ) -> (delta: Angle, isSnapped: Bool) {
        let total = (layerRotation + rawDelta).degrees
        let nearest = (total / 90).rounded() * 90
        if abs(total - nearest) < rotationSnapThresholdDegrees {
            return (.degrees(nearest) - layerRotation, true)
        }
        return (rawDelta, false)
    }

    static func snappedRotationDelta(rawDelta: Angle) -> (delta: Angle, isSnapped: Bool) {
        let degrees = rawDelta.degrees
        let nearest = (degrees / 90).rounded() * 90
        if abs(degrees - nearest) < rotationSnapThresholdDegrees {
            return (.degrees(nearest), true)
        }
        return (rawDelta, false)
    }
}
