import SwiftUI

// MARK: - Border (apply toggle + conditional controls)

enum BorderDefaults {

    static let shapeWidth: Double = 0.10

    static let textWidth: Double = 0.04
    static let color: Color = .black
    static let position: BorderPosition = .outer
}

struct BorderPanelContent: View {
    @Binding var layer: Layer
    let project: IconProject
    let widthRange: ClosedRange<Double>
    let widthDefault: Double
    let widthValueText: (Double) -> String

    var body: some View {
        if layer.borderWidth > 0 {
            DialSliderRow(
                label: "Width",
                value: $layer.borderWidth,
                range: widthRange,
                valueText: widthValueText,
                defaultValue: widthDefault,
                onBeginEditing: { project.recordUndo() }
            )
            BorderPositionRow(position: $layer.borderPosition, project: project)
            LineCapRow(layer: $layer, project: project)
            ColorPickerRow(
                title: "Color",
                color: $layer.borderColor,
                onChange: { project.recordUndo() }
            )
        }
    }

    static func enabledBinding(
        layer: Binding<Layer>,
        project: IconProject,
        widthDefault: Double
    ) -> Binding<Bool> {
        Binding(
            get: { layer.wrappedValue.borderWidth > 0 },
            set: { newVal in
                project.recordUndo()
                if newVal {
                    layer.wrappedValue.borderWidth = widthDefault
                    layer.wrappedValue.borderColor = BorderDefaults.color
                    layer.wrappedValue.borderPosition = BorderDefaults.position
                } else {
                    layer.wrappedValue.borderWidth = 0
                }
            }
        )
    }
}

private struct BorderPositionRow: View {
    @Binding var position: BorderPosition
    let project: IconProject

    var body: some View {
        PanelSegmentedRow(
            label: "Position",
            options: BorderPosition.allCases,
            selection: Binding(
                get: { position },
                set: { position = $0 }
            ),
            optionLabel: { $0.displayName },
            onChange: { project.recordUndo() }
        )
    }
}

private struct LineCapRow: View {
    @Binding var layer: Layer
    let project: IconProject

    var body: some View {
        PanelSegmentedRow(
            label: "Cap",
            options: LayerLineCap.allCases,
            selection: Binding(
                get: { layer.lineCap },
                set: { layer.lineCap = $0 }
            ),
            optionLabel: { $0.displayName },
            onChange: { project.recordUndo() }
        )
    }
}

// MARK: - Shadow (apply toggle + conditional controls)

enum ShadowDefaults {
    static let opacity: Double = 0.35
    static let radius: Double = 0.06
    static let offsetX: Double = 0
    static let offsetY: Double = 0.04
    static let color: Color = .black
}

struct ShadowPanelContent: View {
    @Binding var layer: Layer
    let project: IconProject

    var body: some View {
        if layer.shadowOpacity > 0 {
            ColorPickerRow(
                title: "Color",
                color: Binding(
                    get: { layer.shadowColor },
                    set: { layer.shadowColor = $0 }
                ),
                onChange: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Opacity",
                value: Binding(
                    get: { layer.shadowOpacity },
                    set: { layer.shadowOpacity = $0 }
                ),
                range: 0 ... 1,
                valueText: { String(format: "%.0f%%", $0 * 100) },
                defaultValue: ShadowDefaults.opacity,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Blur",
                value: Binding(
                    get: { layer.shadowRadius },
                    set: { layer.shadowRadius = $0 }
                ),
                range: 0 ... 0.2,
                valueText: { String(format: "%.0f%%", $0 * 100) },
                defaultValue: ShadowDefaults.radius,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Offset X",
                value: Binding(
                    get: { layer.shadowOffsetX },
                    set: { layer.shadowOffsetX = $0 }
                ),
                range: -0.2 ... 0.2,
                valueText: { String(format: "%+.2f", $0) },
                defaultValue: ShadowDefaults.offsetX,
                onBeginEditing: { project.recordUndo() }
            )
            DialSliderRow(
                label: "Offset Y",
                value: Binding(
                    get: { layer.shadowOffsetY },
                    set: { layer.shadowOffsetY = $0 }
                ),
                range: -0.2 ... 0.2,
                valueText: { String(format: "%+.2f", $0) },
                defaultValue: ShadowDefaults.offsetY,
                onBeginEditing: { project.recordUndo() }
            )
        }
    }

    static func enabledBinding(layer: Binding<Layer>, project: IconProject) -> Binding<Bool> {
        Binding(
            get: { layer.wrappedValue.shadowOpacity > 0 },
            set: { newVal in
                project.recordUndo()
                if newVal {
                    layer.wrappedValue.shadowOpacity = ShadowDefaults.opacity
                    layer.wrappedValue.shadowRadius = ShadowDefaults.radius
                    layer.wrappedValue.shadowOffsetX = ShadowDefaults.offsetX
                    layer.wrappedValue.shadowOffsetY = ShadowDefaults.offsetY
                    layer.wrappedValue.shadowColor = ShadowDefaults.color
                } else {
                    layer.wrappedValue.shadowOpacity = 0
                }
            }
        )
    }
}

// MARK: - Transform (apply toggle + Stretch X/Y sliders)

enum TransformDefaults {
    static let stretchX: Double = 1.5
    static let stretchY: Double = 1.0
}

struct TransformPanelContent: View {
    @Binding var layer: Layer
    let project: IconProject

    var body: some View {
        if layer.shapeSpec?.transformParams != nil {
            sliders
        }
    }

    static func enabledBinding(layer: Binding<Layer>, project: IconProject) -> Binding<Bool> {
        Binding(
            get: { layer.wrappedValue.shapeSpec?.transformParams != nil },
            set: { newVal in
                project.recordUndo()
                let spec = layer.wrappedValue.shapeSpec ?? .defaultShape
                if newVal {
                    layer.wrappedValue.shapeSpec = spec.applyingTransform(TransformParams(
                        stretchX: TransformDefaults.stretchX,
                        stretchY: TransformDefaults.stretchY,
                        rotation: 0
                    ))
                } else {
                    layer.wrappedValue.shapeSpec = spec.applyingTransform(ShapeSpec.identityTransform)
                }
            }
        )
    }

    private var currentTransform: TransformParams {
        layer.shapeSpec?.transformParams ?? ShapeSpec.identityTransform
    }

    private func stretchBinding(
        _ keyPath: WritableKeyPath<TransformParams, Double>
    ) -> Binding<Double> {
        Binding(
            get: { currentTransform[keyPath: keyPath] },
            set: { newVal in
                var t = currentTransform
                t[keyPath: keyPath] = max(0.3, min(3, newVal))
                let spec = layer.shapeSpec ?? .defaultShape
                layer.shapeSpec = spec.applyingTransform(t)
            }
        )
    }

    @ViewBuilder
    private var sliders: some View {
        DialSliderRow(
            label: "Stretch X",
            value: stretchBinding(\.stretchX),
            range: 0.3 ... 3,
            valueText: { String(format: "%.2f×", $0) },
            defaultValue: 1,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Stretch Y",
            value: stretchBinding(\.stretchY),
            range: 0.3 ... 3,
            valueText: { String(format: "%.2f×", $0) },
            defaultValue: 1,
            onBeginEditing: { project.recordUndo() }
        )
    }
}

// MARK: - Radial repeat (apply toggle + conditional sliders)

struct RadialRepeatPanelContent: View {
    @Binding var layer: Layer
    let project: IconProject
    let session: ProjectSession

    var body: some View {
        if layer.radialRepeatParams != nil {
            sliders
        }
    }

    private var showsOrientation: Bool {
        guard layer.kind == .parametricShape,
              let base = layer.shapeSpec?.deepestBase else { return true }
        if case let .ellipse(roundness, _, arcSweep) = base {
            return roundness < 1.0 - 1e-6 || arcSweep < 1.0 - 1e-6
        }
        return true
    }

    static func enabledBinding(
        layer: Binding<Layer>,
        project: IconProject
    ) -> Binding<Bool> {
        Binding(
            get: { layer.wrappedValue.radialRepeatParams != nil },
            set: { newVal in
                project.recordUndo()
                if newVal {
                    layer.wrappedValue.radialRepeatParams = ShapeSpec.defaultRadialRepeat
                } else {
                    layer.wrappedValue.radialRepeatParams = nil
                }
            }
        )
    }

    @ViewBuilder
    private var sliders: some View {
        DialSliderRow(
            label: "Count",
            value: doubleBinding(
                get: { Double($0.count) },
                set: { p, v in var p = p; p.count = Int(v.rounded()); return p }
            ),
            range: 2 ... 24,
            valueText: { "\(Int($0.rounded()))" },
            defaultValue: Double(ShapeSpec.defaultRadialRepeat.count),
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Center Hole",
            value: doubleBinding(
                get: { $0.centerHole },
                set: { p, v in var p = p; p.centerHole = v; return p }
            ),
            range: -0.5 ... 0.5,
            valueText: { String(format: "%.0f%%", $0 * 200) },
            defaultValue: ShapeSpec.defaultRadialRepeat.centerHole,
            onBeginEditing: { project.recordUndo() }
        )
        if showsOrientation {
            DialSliderRow(
                label: "Orientation",
                value: doubleBinding(
                    get: { $0.orientation * 180 / .pi },
                    set: { p, v in
                        var p = p
                        p.orientation = v * .pi / 180
                        return p
                    }
                ),
                range: -180 ... 180,
                valueText: { String(format: "%.0f°", $0) },
                defaultValue: ShapeSpec.defaultRadialRepeat.orientation,
                onBeginEditing: { project.recordUndo() }
            )
        }
        ActionRow(title: "Break apart") {
            let sourceID = layer.uuid
            if let newIDs = project.explodeRadialRepeat(layerID: sourceID),
               let first = newIDs.first {
                session.selectLayer(first)
            }
        }
    }

    private func doubleBinding(
        get: @escaping (RadialRepeatParams) -> Double,
        set: @escaping (RadialRepeatParams, Double) -> RadialRepeatParams
    ) -> Binding<Double> {
        Binding(
            get: {
                layer.radialRepeatParams.map(get) ?? 0
            },
            set: { newVal in
                guard let params = layer.radialRepeatParams else { return }
                layer.radialRepeatParams = set(params, newVal)
            }
        )
    }
}
