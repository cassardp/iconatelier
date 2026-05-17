import SwiftUI

// MARK: - Border (apply toggle + conditional controls)

/// Tuned defaults applied the first time the user enables a border. Width
/// units differ between shape (×200) and text (×500) layers so the same
/// "30%" visual yields two different raw values.
enum BorderDefaults {
    /// 0.10 → "20%" with the parametric-shape units (`$0 * 200`).
    static let shapeWidth: Double = 0.10
    /// 0.04 → "20%" with the text units (`$0 * 500`).
    static let textWidth: Double = 0.04
    static let color: Color = .black
    static let position: BorderPosition = .outer
}

struct BorderPanelContent: View {
    @Bindable var layer: Layer
    let project: IconProject
    let widthRange: ClosedRange<Double>
    let widthDefault: Double
    let widthValueText: (Double) -> String

    var body: some View {
        PanelToggleRow(
            label: "Apply",
            isOn: Binding(
                get: { layer.borderWidth > 0 },
                set: { newVal in toggleBorder(to: newVal) }
            )
        )
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
            LineCapRow(layer: layer, project: project)
            ColorPickerRow(
                title: "Color",
                color: $layer.borderColor,
                onChange: { project.recordUndo() }
            )
        }
    }

    private func toggleBorder(to enable: Bool) {
        project.recordUndo()
        if enable {
            layer.borderWidth = widthDefault
            layer.borderColor = BorderDefaults.color
            layer.borderPosition = BorderDefaults.position
        } else {
            layer.borderWidth = 0
        }
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
    @Bindable var layer: Layer
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

/// Tuned defaults applied the first time the user enables a shadow. Picks a
/// soft, slightly-down drop shadow that reads as "pro" out of the box.
enum ShadowDefaults {
    static let opacity: Double = 0.35
    static let radius: Double = 0.06
    static let offsetX: Double = 0
    static let offsetY: Double = 0.04
    static let color: Color = .black
}

struct ShadowPanelContent: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        PanelToggleRow(
            label: "Apply",
            isOn: Binding(
                get: { layer.shadowOpacity > 0 },
                set: { newVal in toggleShadow(to: newVal) }
            )
        )
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

    private func toggleShadow(to enable: Bool) {
        project.recordUndo()
        if enable {
            layer.shadowOpacity = ShadowDefaults.opacity
            layer.shadowRadius = ShadowDefaults.radius
            layer.shadowOffsetX = ShadowDefaults.offsetX
            layer.shadowOffsetY = ShadowDefaults.offsetY
            layer.shadowColor = ShadowDefaults.color
        } else {
            layer.shadowOpacity = 0
        }
    }
}

// MARK: - Radial repeat (apply toggle + conditional sliders)

/// Toggle + 4 sliders for the radial-repeat wrap, driven through
/// `layer.shapeSpec`. Used by both parametric shapes (where the spec also
/// carries the base polygon) and text layers (where the base is a sentinel
/// — only the repeat params matter; the actual base is the live
/// `TextGlyphShape` at render time).
///
/// `wrapBase` provides the base to wrap when enabling the toggle.
/// `disabledShapeSpec` decides what `shapeSpec` becomes when disabling —
/// for parametric shapes it returns the unwrapped polygon; for text it
/// returns nil so the layer goes back to "no spec at all".
struct RadialRepeatPanelContent: View {
    @Bindable var layer: Layer
    let project: IconProject
    let wrapBase: () -> ShapeSpec
    let disabledShapeSpec: () -> ShapeSpec?

    var body: some View {
        repeatToggleRow
        if layer.shapeSpec?.radialRepeatParams != nil {
            sliders
        }
    }

    private var repeatToggleRow: some View {
        PanelToggleRow(
            label: "Apply",
            isOn: Binding(
                get: { layer.shapeSpec?.radialRepeatParams != nil },
                set: { newVal in toggleRepeat(to: newVal) }
            )
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
        DialSliderRow(
            label: "Phase",
            value: doubleBinding(
                get: { $0.phaseDegrees },
                set: { p, v in var p = p; p.phaseDegrees = v; return p }
            ),
            range: -180 ... 180,
            valueText: { String(format: "%.0f°", $0) },
            defaultValue: ShapeSpec.defaultRadialRepeat.phaseDegrees,
            onBeginEditing: { project.recordUndo() }
        )
        DialSliderRow(
            label: "Alternate",
            value: doubleBinding(
                get: { $0.alternateScale },
                set: { p, v in var p = p; p.alternateScale = v; return p }
            ),
            range: 0.2 ... 1.0,
            valueText: { String(format: "%.2f", $0) },
            defaultValue: ShapeSpec.defaultRadialRepeat.alternateScale,
            onBeginEditing: { project.recordUndo() }
        )
    }

    private func toggleRepeat(to enable: Bool) {
        project.recordUndo()
        if enable {
            let base = layer.shapeSpec ?? wrapBase()
            layer.shapeSpec = base.wrappingInRadialRepeat(ShapeSpec.defaultRadialRepeat)
        } else {
            layer.shapeSpec = disabledShapeSpec()
        }
    }

    private func doubleBinding(
        get: @escaping (RadialRepeatParams) -> Double,
        set: @escaping (RadialRepeatParams, Double) -> RadialRepeatParams
    ) -> Binding<Double> {
        Binding(
            get: {
                layer.shapeSpec?.radialRepeatParams.map(get) ?? 0
            },
            set: { newVal in
                guard let spec = layer.shapeSpec,
                      let params = spec.radialRepeatParams else { return }
                let updated = set(params, newVal)
                layer.shapeSpec = spec.wrappingInRadialRepeat(updated)
            }
        )
    }
}
