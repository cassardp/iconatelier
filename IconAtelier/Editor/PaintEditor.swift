import SwiftUI

/// Reusable editor for a `Paint` value — kind picker, presets, color
/// stops, and per-kind controls (linear angle, radial spread, mesh
/// corners…). Used both by the background editor and by the shape/text
/// fill section so a layer fill can be any of the same gradients the
/// canvas background supports.
struct PaintEditor: View {
    @Binding var paint: Paint
    /// Called once per discrete edit (start of a slider drag, color
    /// picker tap, preset tap, kind switch…). Wire to
    /// `project.recordUndo()` — its own coalescing window dedupes the
    /// rapid-fire calls a `ColorPicker` produces.
    let onBeginEditing: () -> Void
    /// When `true` (default), each control group is wrapped in its own
    /// titled `PanelSection` separated by `SectionDivider`s — the look
    /// of the background editor.
    /// When `false`, controls are emitted as flat rows so the editor
    /// can be embedded inside a parent `PanelSection` (e.g. the shape
    /// "Fill" section, which already owns the section header and the
    /// on/off toggle).
    var sectioned: Bool = true

    var body: some View {
        if sectioned {
            VStack(spacing: 18) {
                kindPicker
                SectionDivider()
                kindControls
            }
        } else {
            kindPickerRow
            kindControls
        }
    }

    // MARK: - Kind picker

    private static let pickerKinds: [PaintKind] = [
        .solid, .linearGradient, .radialGradient, .meshGradient
    ]

    @ViewBuilder
    private var kindPicker: some View {
        PanelSection(title: "Type") {
            kindPickerRow
        }
    }

    @ViewBuilder
    private var kindPickerRow: some View {
        PanelSegmentedControl(
            options: Self.pickerKinds,
            selection: Binding(
                get: { paint.kind },
                set: { paint.kind = $0 }
            ),
            label: { $0.label },
            onChange: { onBeginEditing() }
        )
    }

    // MARK: - Per-kind controls

    @ViewBuilder
    private var kindControls: some View {
        switch paint.kind {
        case .solid:
            solidContent
        case .linearGradient:
            linearPresetsContent
            if sectioned { SectionDivider() }
            gradientStopsContent(kind: .linearGradient)
            if sectioned { SectionDivider() }
            linearAngleSlider
        case .radialGradient:
            radialPresetsContent
            if sectioned { SectionDivider() }
            gradientStopsContent(kind: .radialGradient)
            if sectioned { SectionDivider() }
            radialSpreadSlider
        case .meshGradient:
            meshPresetsContent
            if sectioned { SectionDivider() }
            meshCornersContent
            if sectioned { SectionDivider() }
            meshAngleSlider
        }
    }

    // MARK: - Solid

    @ViewBuilder
    private var solidContent: some View {
        if sectioned {
            PanelSection(title: "Color") { solidColorRow }
        } else {
            solidColorRow
        }
    }

    private var solidColorRow: some View {
        ColorPickerRow(
            title: "Color",
            color: Binding(
                get: { paint.solidColor.color },
                set: { paint.solidColor = StoredColor($0) }
            ),
            onChange: onBeginEditing
        )
    }

    // MARK: - Linear

    @ViewBuilder
    private var linearPresetsContent: some View {
        if sectioned {
            PanelSection(title: "Presets") { linearPresetsRow }
        } else {
            linearPresetsRow
        }
    }

    private var linearPresetsRow: some View {
        BackgroundPresetsRow(
            presets: BackgroundPresets.linear,
            thumbnail: { preset in
                LinearGradient(
                    colors: preset.colors,
                    startPoint: preset.start,
                    endPoint: preset.end
                )
            },
            onSelect: { preset in
                onBeginEditing()
                paint.gradientColors = preset.colors.map { StoredColor($0) }
                paint.linearStart = StoredPoint(preset.start)
                paint.linearEnd = StoredPoint(preset.end)
            }
        )
    }

    @ViewBuilder
    private var linearAngleSlider: some View {
        DialSliderRow(
            label: "Angle",
            value: Binding(
                get: {
                    PaintEditor.angle(
                        from: paint.linearStart.unitPoint,
                        to: paint.linearEnd.unitPoint
                    )
                },
                set: { newAngle in
                    let (s, e) = PaintEditor.unitPoints(forAngle: newAngle)
                    paint.linearStart = StoredPoint(s)
                    paint.linearEnd = StoredPoint(e)
                }
            ),
            range: 0 ... 360,
            valueText: { String(format: "%.0f°", $0) },
            defaultValue: 90,
            onBeginEditing: onBeginEditing
        )
    }

    // MARK: - Radial

    @ViewBuilder
    private var radialPresetsContent: some View {
        if sectioned {
            PanelSection(title: "Presets") { radialPresetsRow }
        } else {
            radialPresetsRow
        }
    }

    private var radialPresetsRow: some View {
        BackgroundPresetsRow(
            presets: BackgroundPresets.radial,
            thumbnail: { preset in
                RadialGradient(
                    colors: preset.colors,
                    center: .center,
                    startRadius: 0,
                    endRadius: 38
                )
            },
            onSelect: { preset in
                onBeginEditing()
                paint.gradientColors = preset.colors.map { StoredColor($0) }
            }
        )
    }

    @ViewBuilder
    private var radialSpreadSlider: some View {
        DialSliderRow(
            label: "Spread",
            value: Binding(
                get: { paint.radialSpread },
                set: { paint.radialSpread = $0 }
            ),
            range: 0.2 ... 1.5,
            valueText: { String(format: "%.0f%%", $0 * 100) },
            defaultValue: 0.75,
            onBeginEditing: onBeginEditing
        )
    }

    // MARK: - Mesh

    @ViewBuilder
    private var meshPresetsContent: some View {
        if sectioned {
            PanelSection(title: "Presets") { meshPresetsRow }
        } else {
            meshPresetsRow
        }
    }

    private var meshPresetsRow: some View {
        BackgroundPresetsRow(
            presets: BackgroundPresets.mesh,
            thumbnail: { preset in
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        .init(0, 0),   .init(0.5, 0),   .init(1, 0),
                        .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                        .init(0, 1),   .init(0.5, 1),   .init(1, 1),
                    ],
                    colors: preset.meshColors
                )
            },
            onSelect: { preset in
                onBeginEditing()
                paint.meshColors = preset.meshColors.map { StoredColor($0) }
            }
        )
    }

    @ViewBuilder
    private var meshAngleSlider: some View {
        DialSliderRow(
            label: "Angle",
            value: Binding(
                get: { paint.meshRotationDegrees },
                set: { paint.meshRotationDegrees = $0 }
            ),
            range: 0 ... 360,
            valueText: { String(format: "%.0f°", $0) },
            defaultValue: 0,
            onBeginEditing: onBeginEditing
        )
    }

    @ViewBuilder
    private var meshCornersContent: some View {
        if sectioned {
            PanelSection(title: "Corners") { meshCornersRows }
        } else {
            meshCornersRows
        }
    }

    @ViewBuilder
    private var meshCornersRows: some View {
        ColorPickerRow(
            title: "Top-left",
            color: meshBinding(index: 0),
            onChange: onBeginEditing
        )
        ColorPickerRow(
            title: "Top-right",
            color: meshBinding(index: 2),
            onChange: onBeginEditing
        )
        ColorPickerRow(
            title: "Bottom-left",
            color: meshBinding(index: 6),
            onChange: onBeginEditing
        )
        ColorPickerRow(
            title: "Bottom-right",
            color: meshBinding(index: 8),
            onChange: onBeginEditing
        )
    }

    private func meshBinding(index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard paint.meshColors.indices.contains(index) else { return .clear }
                return paint.meshColors[index].color
            },
            set: { newColor in
                ensureMeshColors()
                paint.meshColors[index] = StoredColor(newColor)
                // Re-interpolate the 5 mid cells from the 4 corners so the
                // mesh stays a smooth 3×3 gradient (same convention as
                // Background).
                paint.meshColors = Color.mesh3x3(
                    topLeft: paint.meshColors[0].color,
                    topRight: paint.meshColors[2].color,
                    bottomLeft: paint.meshColors[6].color,
                    bottomRight: paint.meshColors[8].color
                ).map { StoredColor($0) }
            }
        )
    }

    /// Layers freshly switched to `.meshGradient` may not have any
    /// mesh colors stored yet — top them up with the default 4-corner
    /// mesh so the corner color pickers don't index into an empty array.
    private func ensureMeshColors() {
        if paint.meshColors.count < 9 {
            paint.meshColors = Paint.defaultMeshStoredColors
        }
    }

    // MARK: - Gradient stops

    @ViewBuilder
    private func gradientStopsContent(kind: PaintKind) -> some View {
        if sectioned {
            PanelSection(title: "Colors") { gradientStopsRows(kind: kind) }
        } else {
            gradientStopsRows(kind: kind)
        }
    }

    @ViewBuilder
    private func gradientStopsRows(kind: PaintKind) -> some View {
        ForEach(paint.gradientColors.indices, id: \.self) { idx in
            ColorPickerRow(
                title: stopLabel(at: idx, total: paint.gradientColors.count, kind: kind),
                color: Binding(
                    get: { paint.gradientColors[idx].color },
                    set: { paint.gradientColors[idx] = StoredColor($0) }
                ),
                onChange: onBeginEditing
            )
        }
    }

    private func stopLabel(at idx: Int, total: Int, kind: PaintKind) -> String {
        let isFirst = idx == 0
        let isLast = idx == total - 1
        switch kind {
        case .linearGradient:
            if isFirst { return "Start" }
            if isLast  { return "End" }
            return "Mid \(idx)"
        case .radialGradient:
            if isFirst { return "Center" }
            if isLast  { return "Edge" }
            return "Mid \(idx)"
        default:
            return "Stop \(idx + 1)"
        }
    }

    // MARK: - Angle helpers (shared with background editor)

    fileprivate static func angle(from start: UnitPoint, to end: UnitPoint) -> Double {
        let dx = Double(end.x - start.x)
        let dy = Double(end.y - start.y)
        guard dx != 0 || dy != 0 else { return 90 }
        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return degrees
    }

    fileprivate static func unitPoints(forAngle degrees: Double) -> (UnitPoint, UnitPoint) {
        let radians = degrees * .pi / 180
        let dx = CGFloat(cos(radians)) * 0.5
        let dy = CGFloat(sin(radians)) * 0.5
        return (
            UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
        )
    }
}
