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

struct MagnifySnapState: Equatable {
    var scale: CGFloat = 1.0
    var objectGuides: [SnapGuide] = []
}

struct RotationSnapState: Equatable {
    var delta: Angle = .zero
    var isSnapped: Bool = false
}

enum CanvasSnapping {

    static let rotationSnapThresholdDegrees: Double = 5
    static let objectSnapThresholdPoints: CGFloat = 6

    // MARK: - Grid configuration (4×4 cells → 3 internal lines per axis)

    static let gridLineOffsets: [CGFloat] = [-0.25, 0, 0.25]

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
            let path = ShapeRenderer.path(for: spec, in: unit)
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
        if let bx = bestX { effective.width += bx.delta * side }
        if let by = bestY { effective.height += by.delta * side }

        let snapped = candidate.offsetBy(
            dx: (bestX?.delta ?? 0),
            dy: (bestY?.delta ?? 0)
        )
        let matchEpsilon: CGFloat = 0.5 / side
        let snappedXs: [CGFloat] = [snapped.minX, snapped.midX, snapped.maxX]
        let snappedYs: [CGFloat] = [snapped.minY, snapped.midY, snapped.maxY]

        func guides(
            orientation: SnapGuide.Orientation,
            candidates: [CGFloat],
            targets: [(pos: CGFloat, source: CGRect, isLayerCenter: Bool)],
            extentStart: (CGRect) -> CGFloat,
            extentEnd: (CGRect) -> CGFloat,
            candidateExtentStart: CGFloat,
            candidateExtentEnd: CGFloat
        ) -> [SnapGuide] {
            var bySources: [CGFloat: [CGRect]] = [:]
            for c in candidates {
                for t in targets where abs(t.pos - c) < matchEpsilon {
                    bySources[t.pos, default: []].append(t.source)
                }
            }
            return bySources.map { (pos, sources) in
                var start = candidateExtentStart
                var end = candidateExtentEnd
                for s in sources {
                    start = min(start, extentStart(s))
                    end = max(end, extentEnd(s))
                }
                return SnapGuide(
                    orientation: orientation,
                    position: pos,
                    extentStart: start,
                    extentEnd: end
                )
            }
        }

        var allGuides: [SnapGuide] = []
        if bestX != nil {
            allGuides.append(contentsOf: guides(
                orientation: .vertical,
                candidates: snappedXs,
                targets: xTargets,
                extentStart: { $0.minY },
                extentEnd: { $0.maxY },
                candidateExtentStart: snapped.minY,
                candidateExtentEnd: snapped.maxY
            ))
        }
        if bestY != nil {
            allGuides.append(contentsOf: guides(
                orientation: .horizontal,
                candidates: snappedYs,
                targets: yTargets,
                extentStart: { $0.minX },
                extentEnd: { $0.maxX },
                candidateExtentStart: snapped.minX,
                candidateExtentEnd: snapped.maxX
            ))
        }
        return (effective, allGuides)
    }

    // MARK: - Snap during uniform scale (pinch)

    static func snappedMagnification(
        magnification: CGFloat,
        layer: Layer,
        others: [Layer],
        side: CGFloat
    ) -> (effective: CGFloat, guides: [SnapGuide]) {
        guard side > 0,
              magnification.isFinite,
              magnification > 0
        else { return (magnification, []) }
        let threshold = objectSnapThresholdPoints / side
        let minAnchorDist: CGFloat = 0.001

        var candidateLayer = layer
        candidateLayer.scale = layer.scale * magnification
        let candidate = layerNormalizedBounds(candidateLayer)
        let ox = layer.offset.width
        let oy = layer.offset.height

        var xTargets: [(pos: CGFloat, source: CGRect)] = [
            (-0.5, CGRect(x: -0.5, y: -0.5, width: 0, height: 1)),
            (0,    CGRect(x: 0,    y: -0.5, width: 0, height: 1)),
            (0.5,  CGRect(x: 0.5,  y: -0.5, width: 0, height: 1))
        ]
        var yTargets: [(pos: CGFloat, source: CGRect)] = [
            (-0.5, CGRect(x: -0.5, y: -0.5, width: 1, height: 0)),
            (0,    CGRect(x: -0.5, y: 0,    width: 1, height: 0)),
            (0.5,  CGRect(x: -0.5, y: 0.5,  width: 1, height: 0))
        ]
        for other in others {
            let b = layerNormalizedBounds(other)
            xTargets.append((b.minX, b))
            xTargets.append((b.midX, b))
            xTargets.append((b.maxX, b))
            yTargets.append((b.minY, b))
            yTargets.append((b.midY, b))
            yTargets.append((b.maxY, b))
        }

        let candXs: [CGFloat] = [candidate.minX, candidate.midX, candidate.maxX]
        let candYs: [CGFloat] = [candidate.minY, candidate.midY, candidate.maxY]

        var bestRatio: CGFloat = 1
        var bestScore: CGFloat = .infinity

        for cand in candXs {
            let anchorDist = cand - ox
            guard abs(anchorDist) > minAnchorDist else { continue }
            for t in xTargets {
                let d = t.pos - cand
                guard abs(d) < threshold else { continue }
                let ratio = (t.pos - ox) / anchorDist
                guard ratio > 0.05, ratio.isFinite else { continue }
                let score = abs(ratio - 1)
                if score < bestScore {
                    bestScore = score
                    bestRatio = ratio
                }
            }
        }
        for cand in candYs {
            let anchorDist = cand - oy
            guard abs(anchorDist) > minAnchorDist else { continue }
            for t in yTargets {
                let d = t.pos - cand
                guard abs(d) < threshold else { continue }
                let ratio = (t.pos - oy) / anchorDist
                guard ratio > 0.05, ratio.isFinite else { continue }
                let score = abs(ratio - 1)
                if score < bestScore {
                    bestScore = score
                    bestRatio = ratio
                }
            }
        }

        let effective = magnification * bestRatio
        var snappedLayer = layer
        snappedLayer.scale = layer.scale * effective
        let snapped = layerNormalizedBounds(snappedLayer)

        let matchEpsilon: CGFloat = 0.5 / side
        let snappedXs = [snapped.minX, snapped.midX, snapped.maxX]
        let snappedYs = [snapped.minY, snapped.midY, snapped.maxY]

        func collect(
            orientation: SnapGuide.Orientation,
            candidates: [CGFloat],
            targets: [(pos: CGFloat, source: CGRect)],
            extentStart: (CGRect) -> CGFloat,
            extentEnd: (CGRect) -> CGFloat,
            candidateExtentStart: CGFloat,
            candidateExtentEnd: CGFloat
        ) -> [SnapGuide] {
            var bySources: [CGFloat: [CGRect]] = [:]
            for c in candidates {
                for t in targets where abs(t.pos - c) < matchEpsilon {
                    bySources[t.pos, default: []].append(t.source)
                }
            }
            return bySources.map { (pos, sources) in
                var start = candidateExtentStart
                var end = candidateExtentEnd
                for s in sources {
                    start = min(start, extentStart(s))
                    end = max(end, extentEnd(s))
                }
                return SnapGuide(
                    orientation: orientation,
                    position: pos,
                    extentStart: start,
                    extentEnd: end
                )
            }
        }

        var allGuides: [SnapGuide] = []
        allGuides.append(contentsOf: collect(
            orientation: .vertical,
            candidates: snappedXs,
            targets: xTargets,
            extentStart: { $0.minY },
            extentEnd: { $0.maxY },
            candidateExtentStart: snapped.minY,
            candidateExtentEnd: snapped.maxY
        ))
        allGuides.append(contentsOf: collect(
            orientation: .horizontal,
            candidates: snappedYs,
            targets: yTargets,
            extentStart: { $0.minX },
            extentEnd: { $0.maxX },
            candidateExtentStart: snapped.minX,
            candidateExtentEnd: snapped.maxX
        ))
        return (effective, allGuides)
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
        let nearest = (total / 45).rounded() * 45
        if abs(total - nearest) < rotationSnapThresholdDegrees {
            return (.degrees(nearest) - layerRotation, true)
        }
        return (rawDelta, false)
    }

    static func snappedRotationDelta(rawDelta: Angle) -> (delta: Angle, isSnapped: Bool) {
        let degrees = rawDelta.degrees
        let nearest = (degrees / 45).rounded() * 45
        if abs(degrees - nearest) < rotationSnapThresholdDegrees {
            return (.degrees(nearest), true)
        }
        return (rawDelta, false)
    }

    // MARK: - Snapping to grid lines

    static func snappedToGridLines(
        translation: CGSize,
        draggedBounds: CGRect,
        side: CGFloat
    ) -> (effective: CGSize, guides: [SnapGuide]) {
        guard side > 0 else { return (translation, []) }
        let threshold = objectSnapThresholdPoints / side
        let dx = translation.width / side
        let dy = translation.height / side
        let candidate = draggedBounds.offsetBy(dx: dx, dy: dy)
        let candXs: [CGFloat] = [candidate.minX, candidate.midX, candidate.maxX]
        let candYs: [CGFloat] = [candidate.minY, candidate.midY, candidate.maxY]

        func bestSnap(candidates: [CGFloat]) -> CGFloat? {
            var best: CGFloat?
            for c in candidates {
                for line in gridLineOffsets {
                    let d = line - c
                    if abs(d) < threshold, best == nil || abs(d) < abs(best!) {
                        best = d
                    }
                }
            }
            return best
        }

        let bestX = bestSnap(candidates: candXs)
        let bestY = bestSnap(candidates: candYs)
        var effective = translation
        if let bx = bestX { effective.width += bx * side }
        if let by = bestY { effective.height += by * side }

        let snapped = candidate.offsetBy(dx: bestX ?? 0, dy: bestY ?? 0)
        let snappedXs: [CGFloat] = [snapped.minX, snapped.midX, snapped.maxX]
        let snappedYs: [CGFloat] = [snapped.minY, snapped.midY, snapped.maxY]
        let matchEpsilon: CGFloat = 0.5 / side

        var guides: [SnapGuide] = []
        for line in gridLineOffsets {
            if snappedXs.contains(where: { abs($0 - line) < matchEpsilon }) {
                guides.append(SnapGuide(
                    orientation: .vertical,
                    position: line,
                    extentStart: -0.5,
                    extentEnd: 0.5
                ))
            }
            if snappedYs.contains(where: { abs($0 - line) < matchEpsilon }) {
                guides.append(SnapGuide(
                    orientation: .horizontal,
                    position: line,
                    extentStart: -0.5,
                    extentEnd: 0.5
                ))
            }
        }

        return (effective, guides)
    }

    static func snappedMagnificationToGridLines(
        magnification: CGFloat,
        layer: Layer,
        side: CGFloat
    ) -> (effective: CGFloat, guides: [SnapGuide]) {
        guard side > 0, magnification.isFinite, magnification > 0 else {
            return (magnification, [])
        }
        let threshold = objectSnapThresholdPoints / side
        let minAnchorDist: CGFloat = 0.001

        var candidateLayer = layer
        candidateLayer.scale = layer.scale * magnification
        let candidate = layerNormalizedBounds(candidateLayer)
        let ox = layer.offset.width
        let oy = layer.offset.height

        let candXs: [CGFloat] = [candidate.minX, candidate.midX, candidate.maxX]
        let candYs: [CGFloat] = [candidate.minY, candidate.midY, candidate.maxY]

        var bestRatio: CGFloat = 1
        var bestScore: CGFloat = .infinity

        for cand in candXs {
            let anchorDist = cand - ox
            guard abs(anchorDist) > minAnchorDist else { continue }
            for line in gridLineOffsets {
                let d = line - cand
                guard abs(d) < threshold else { continue }
                let ratio = (line - ox) / anchorDist
                guard ratio > 0.05, ratio.isFinite else { continue }
                let score = abs(ratio - 1)
                if score < bestScore {
                    bestScore = score
                    bestRatio = ratio
                }
            }
        }
        for cand in candYs {
            let anchorDist = cand - oy
            guard abs(anchorDist) > minAnchorDist else { continue }
            for line in gridLineOffsets {
                let d = line - cand
                guard abs(d) < threshold else { continue }
                let ratio = (line - oy) / anchorDist
                guard ratio > 0.05, ratio.isFinite else { continue }
                let score = abs(ratio - 1)
                if score < bestScore {
                    bestScore = score
                    bestRatio = ratio
                }
            }
        }

        let effective = magnification * bestRatio
        var snappedLayer = layer
        snappedLayer.scale = layer.scale * effective
        let snapped = layerNormalizedBounds(snappedLayer)

        let matchEpsilon: CGFloat = 0.5 / side
        let snappedXs = [snapped.minX, snapped.midX, snapped.maxX]
        let snappedYs = [snapped.minY, snapped.midY, snapped.maxY]

        var guides: [SnapGuide] = []
        for line in gridLineOffsets {
            if snappedXs.contains(where: { abs($0 - line) < matchEpsilon }) {
                guides.append(SnapGuide(
                    orientation: .vertical,
                    position: line,
                    extentStart: -0.5,
                    extentEnd: 0.5
                ))
            }
            if snappedYs.contains(where: { abs($0 - line) < matchEpsilon }) {
                guides.append(SnapGuide(
                    orientation: .horizontal,
                    position: line,
                    extentStart: -0.5,
                    extentEnd: 0.5
                ))
            }
        }

        return (effective, guides)
    }
}
