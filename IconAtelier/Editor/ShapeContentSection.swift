import SwiftUI

struct ShapeContentSection: View {
    @Binding var layer: Layer
    let project: IconProject

    var body: some View {

        if hasFamilySliders {
            PanelSection(title: shapeFamilyTitle) {
                if isPolygonFamily {
                    polygonSliders
                } else if isStarFamily {
                    starSliders
                } else if isEllipseFamily {
                    ellipseSliders
                } else if isDropFamily {
                    dropSliders
                }
            }
            SectionDivider()
        }
        PanelSection(
            title: "Fill",
            isOn: Binding(
                get: { layer.fillEnabled },
                set: { newVal in
                    project.recordUndo()
                    layer.fillEnabled = newVal
                }
            )
        ) {
            PaintEditor(
                paint: Binding(
                    get: { layer.fillPaint },
                    set: { layer.fillPaint = $0 }
                ),
                onBeginEditing: { project.recordUndo() }
            )
        }
    }

    private var hasFamilySliders: Bool {
        isPolygonFamily || isStarFamily || isEllipseFamily || isDropFamily
    }

    private var shapeFamilyTitle: String {
        guard let spec = layer.shapeSpec else { return "Shape" }
        if case let .polygon(preset, sides, _) = spec.deepestBase, preset == .free {
            return polygonTitle(forSides: sides)
        }
        return spec.displayName
    }

    private func polygonTitle(forSides sides: Int) -> String {
        switch sides {
        case 3: return "Triangle"
        case 4: return "Square"
        case 5: return "Pentagon"
        case 6: return "Hexagon"
        case 8: return "Octagon"
        default: return "Custom"
        }
    }

    private var isIosSquircle: Bool {
        if case .iosSquircle = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isCustomPath: Bool {
        if case .customPath = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isPolygonFamily: Bool {
        if case .polygon = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isStarFamily: Bool {
        if case .star = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isDropFamily: Bool {
        if case .drop = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    private var isEllipseFamily: Bool {
        if case .ellipse = layer.shapeSpec?.deepestBase { return true }
        return false
    }

    // MARK: - Family-specific sliders

    @ViewBuilder
    private var polygonSliders: some View {
        DialSliderRow(
            label: "Sides",
            value: polygonSidesBinding,
            range: 3 ... 24,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 4,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Roundness",
            value: polygonRoundnessBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private var starSliders: some View {
        DialSliderRow(
            label: "Points",
            value: starPointsBinding,
            range: 3 ... 24,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 5,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Inner Depth",
            value: starInnerDepthBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 50,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Roundness",
            value: starRoundnessBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
    }

    @ViewBuilder
    private var ellipseSliders: some View {
        DialSliderRow(
            label: "Roundness",
            value: ellipseRoundnessBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: 100,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Arc Sweep",
            value: ellipseArcSweepBinding,
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))%" },
            defaultValue: 100,
            onBeginEditing: { project.recordUndo() }
        )

        if currentEllipseParams.arcSweep < 1.0 - 1e-6 {
            DialSliderRow(
                label: "Arc Start",
                value: ellipseArcStartBinding,
                range: -180 ... 180,
                valueText: { String(format: "%.0f°", $0) },
                defaultValue: -90,
                onBeginEditing: { project.recordUndo() }
            )
        }
    }

    @ViewBuilder
    private var dropSliders: some View {
        DialSliderRow(
            label: "Pointiness",
            value: dropBinding(\.pointiness, scale: 100),
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropParams.canonical.pointiness * 100,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Bulb Size",
            value: dropBinding(\.bulbSize, scale: 100),
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropParams.canonical.bulbSize * 100,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Tail Offset",
            value: dropBinding(\.tailOffset, scale: 100),
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropParams.canonical.tailOffset * 100,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Tip Roundness",
            value: dropBinding(\.tipRoundness, scale: 100),
            range: 0 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropParams.canonical.tipRoundness * 100,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Bend",
            value: dropBinding(\.bend, scale: 100),
            range: -100 ... 100,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: DropParams.canonical.bend * 100,
            onBeginEditing: { project.recordUndo() }
        )
    }

    // MARK: - Polygon parameter plumbing

    private struct PolygonParams: Equatable {
        var preset: PolygonPreset
        var sides: Int
        var roundness: Double

        static let fallback = PolygonParams(
            preset: .square, sides: 4, roundness: 0
        )
    }

    private var currentPolygonParams: PolygonParams {
        if case let .polygon(preset, sides, roundness)
            = layer.shapeSpec?.deepestBase {
            return PolygonParams(preset: preset, sides: sides, roundness: roundness)
        }
        return .fallback
    }

    private func applyPolygonParams(_ p: PolygonParams) {
        let newBase = ShapeSpec.polygon(
            preset: p.preset, sides: p.sides, roundness: p.roundness
        )
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    private var polygonSidesBinding: Binding<Double> {
        Binding(
            get: { Double(currentPolygonParams.sides) },
            set: { newVal in
                var p = currentPolygonParams
                p.sides = max(3, min(24, Int(newVal.rounded())))
                p.preset = .free
                applyPolygonParams(p)
            }
        )
    }

    private var polygonRoundnessBinding: Binding<Double> {
        Binding(
            get: { currentPolygonParams.roundness * 100 },
            set: { newPercent in
                var p = currentPolygonParams
                p.roundness = min(1, max(0, newPercent / 100))
                p.preset = .free
                applyPolygonParams(p)
            }
        )
    }

    // MARK: - Star parameter plumbing

    private struct StarParams: Equatable {
        var preset: PolygonPreset
        var points: Int
        var innerDepth: Double
        var roundness: Double

        static let fallback = StarParams(
            preset: .star5, points: 5, innerDepth: 0.5, roundness: 0
        )
    }

    private var currentStarParams: StarParams {
        if case let .star(preset, points, innerDepth, roundness)
            = layer.shapeSpec?.deepestBase {
            return StarParams(
                preset: preset, points: points,
                innerDepth: innerDepth, roundness: roundness
            )
        }
        return .fallback
    }

    private func applyStarParams(_ p: StarParams) {
        let newBase = ShapeSpec.star(
            preset: p.preset, points: p.points,
            innerDepth: p.innerDepth, roundness: p.roundness
        )
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    private var starPointsBinding: Binding<Double> {
        Binding(
            get: { Double(currentStarParams.points) },
            set: { newVal in
                var p = currentStarParams
                p.points = max(3, min(24, Int(newVal.rounded())))
                p.preset = .free
                applyStarParams(p)
            }
        )
    }

    private var starInnerDepthBinding: Binding<Double> {
        Binding(
            get: { currentStarParams.innerDepth * 100 },
            set: { newPercent in
                var p = currentStarParams
                p.innerDepth = min(1, max(0, newPercent / 100))
                p.preset = .free
                applyStarParams(p)
            }
        )
    }

    private var starRoundnessBinding: Binding<Double> {
        Binding(
            get: { currentStarParams.roundness * 100 },
            set: { newPercent in
                var p = currentStarParams
                p.roundness = min(1, max(0, newPercent / 100))
                p.preset = .free
                applyStarParams(p)
            }
        )
    }

    // MARK: - Ellipse parameter plumbing

    private struct EllipseParams: Equatable {
        var roundness: Double
        var arcStart: Double
        var arcSweep: Double

        static let fallback = EllipseParams(roundness: 1.0, arcStart: -90, arcSweep: 1.0)
    }

    private var currentEllipseParams: EllipseParams {
        if case let .ellipse(roundness, arcStart, arcSweep) = layer.shapeSpec?.deepestBase {
            return EllipseParams(roundness: roundness, arcStart: arcStart, arcSweep: arcSweep)
        }
        return .fallback
    }

    private func applyEllipseParams(_ p: EllipseParams) {
        let newBase = ShapeSpec.ellipse(
            roundness: p.roundness, arcStart: p.arcStart, arcSweep: p.arcSweep
        )
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    private var ellipseRoundnessBinding: Binding<Double> {
        Binding(
            get: { currentEllipseParams.roundness * 100 },
            set: { newPercent in
                var p = currentEllipseParams
                p.roundness = min(1, max(0, newPercent / 100))
                applyEllipseParams(p)
            }
        )
    }

    private var ellipseArcSweepBinding: Binding<Double> {
        Binding(
            get: { currentEllipseParams.arcSweep * 100 },
            set: { newPercent in
                var p = currentEllipseParams
                p.arcSweep = min(1, max(0, newPercent / 100))
                applyEllipseParams(p)
            }
        )
    }

    private var ellipseArcStartBinding: Binding<Double> {
        Binding(
            get: { currentEllipseParams.arcStart },
            set: { newDeg in
                var p = currentEllipseParams
                p.arcStart = max(-180, min(180, newDeg))
                applyEllipseParams(p)
            }
        )
    }

    // MARK: - Drop parameter plumbing

    private var currentDropParams: DropParams {
        if case let .drop(pointiness, bulbSize, tailOffset, bend, tipRoundness)
            = layer.shapeSpec?.deepestBase {
            return DropParams(
                pointiness: pointiness, bulbSize: bulbSize,
                tailOffset: tailOffset, bend: bend,
                tipRoundness: tipRoundness
            )
        }
        return DropParams.canonical
    }

    private func applyDropParams(_ p: DropParams) {
        let newBase = ShapeSpec.drop(
            pointiness: p.pointiness, bulbSize: p.bulbSize,
            tailOffset: p.tailOffset, bend: p.bend,
            tipRoundness: p.tipRoundness
        )
        layer.shapeSpec = (layer.shapeSpec ?? .defaultShape)
            .replacingBase(with: newBase)
    }

    private func dropBinding(
        _ keyPath: WritableKeyPath<DropParams, Double>,
        scale: Double
    ) -> Binding<Double> {
        Binding(
            get: { currentDropParams[keyPath: keyPath] * scale },
            set: { newScaled in
                var p = currentDropParams
                let raw = newScaled / scale

                if keyPath == \DropParams.bend {
                    p[keyPath: keyPath] = max(-1, min(1, raw))
                } else {
                    p[keyPath: keyPath] = max(0, min(1, raw))
                }
                applyDropParams(p)
            }
        )
    }

}
