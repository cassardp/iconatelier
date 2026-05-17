import SwiftUI

struct BackgroundEditorContent: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    var body: some View {
        @Bindable var background = project.safeBackground
        ScrollView {
            VStack(spacing: 18) {
                BackgroundActionsRow(project: project)
                SectionDivider()
                kindPicker(for: background)
                SectionDivider()
                kindControls(for: background)
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 14)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    // MARK: - Kind picker

    private static let pickerKinds: [BackgroundKind] = [
        .solid, .linearGradient, .radialGradient, .meshGradient
    ]

    @ViewBuilder
    private func kindPicker(for background: Background) -> some View {
        PanelSection(title: "Type") {
            PanelSegmentedControl(
                options: Self.pickerKinds,
                selection: Binding(
                    get: { background.kind },
                    set: { background.kind = $0 }
                ),
                label: { $0.label },
                onChange: { project.recordUndo() }
            )
        }
    }

    // MARK: - Per-kind controls

    @ViewBuilder
    private func kindControls(for background: Background) -> some View {
        switch background.kind {
        case .solid:
            PanelSection(title: "Color") {
                ColorPickerRow(
                    title: "Fill",
                    color: Binding(
                        get: { background.solidColor },
                        set: {
                            project.recordUndo()
                            background.solidColor = $0
                        }
                    )
                )
            }
        case .linearGradient:
            linearPresetsSection(for: background)
            SectionDivider()
            gradientStopsSection(for: background, kind: .linearGradient)
            SectionDivider()
            linearAngleSlider(for: background)
        case .radialGradient:
            radialPresetsSection(for: background)
            SectionDivider()
            gradientStopsSection(for: background, kind: .radialGradient)
            SectionDivider()
            radialSpreadSlider(for: background)
        case .meshGradient:
            meshPresetsSection(for: background)
            SectionDivider()
            meshCornersSection(for: background)
            SectionDivider()
            meshAngleSlider(for: background)
        }
    }

    // MARK: - Presets sections

    private func linearPresetsSection(for background: Background) -> some View {
        PanelSection(title: "Presets") {
            BackgroundPresetsRow(
                presets: BackgroundPresets.linear,
                thumbnail: { preset in
                    LinearGradient(colors: preset.colors, startPoint: preset.start, endPoint: preset.end)
                },
                onSelect: { preset in
                    project.recordUndo()
                    background.gradientColors = preset.colors
                    background.linearStart = preset.start
                    background.linearEnd = preset.end
                }
            )
        }
    }

    @ViewBuilder
    private func radialSpreadSlider(for background: Background) -> some View {
        DialSliderRow(
            label: "Spread",
            value: Binding(
                get: { background.radialSpread },
                set: { background.radialSpread = $0 }
            ),
            range: 0.2 ... 1.5,
            valueText: { String(format: "%.0f%%", $0 * 100) },
            defaultValue: 0.75,
            onBeginEditing: { project.recordUndo() }
        )
    }

    private func radialPresetsSection(for background: Background) -> some View {
        PanelSection(title: "Presets") {
            BackgroundPresetsRow(
                presets: BackgroundPresets.radial,
                thumbnail: { preset in
                    RadialGradient(colors: preset.colors,
                                   center: .center,
                                   startRadius: 0,
                                   endRadius: 38)
                },
                onSelect: { preset in
                    project.recordUndo()
                    background.gradientColors = preset.colors
                }
            )
        }
    }

    private func meshPresetsSection(for background: Background) -> some View {
        PanelSection(title: "Presets") {
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
                    project.recordUndo()
                    background.meshColors = preset.meshColors
                }
            )
        }
    }

    /// Linear stops read as "Start / End"; radial reads as "Center / Edge"
    /// (more meaningful than the generic "Stop 1 / Stop 2"). Extra stops
    /// past the 2 ends fall back to a numbered "Mid N" label.
    private func gradientStopsSection(for background: Background, kind: BackgroundKind) -> some View {
        PanelSection(title: "Colors") {
            ForEach(background.gradientColors.indices, id: \.self) { idx in
                ColorPickerRow(
                    title: stopLabel(at: idx, total: background.gradientColors.count, kind: kind),
                    color: Binding(
                        get: { background.gradientColors[idx] },
                        set: {
                            project.recordUndo()
                            background.gradientColors[idx] = $0
                        }
                    )
                )
            }
        }
    }

    private func stopLabel(at idx: Int, total: Int, kind: BackgroundKind) -> String {
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

    @ViewBuilder
    private func linearAngleSlider(for background: Background) -> some View {
        DialSliderRow(
            label: "Angle",
            value: Binding(
                get: { Self.angle(from: background.linearStart, to: background.linearEnd) },
                set: { newAngle in
                    let (s, e) = Self.unitPoints(forAngle: newAngle)
                    background.linearStart = s
                    background.linearEnd = e
                }
            ),
            range: 0 ... 360,
            valueText: { String(format: "%.0f°", $0) },
            defaultValue: 90,
            onBeginEditing: { project.recordUndo() }
        )
    }

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

    @ViewBuilder
    private func meshAngleSlider(for background: Background) -> some View {
        DialSliderRow(
            label: "Angle",
            value: Binding(
                get: { background.meshRotationDegrees },
                set: { background.meshRotationDegrees = $0 }
            ),
            range: 0 ... 360,
            valueText: { String(format: "%.0f°", $0) },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
    }

    private func meshCornersSection(for background: Background) -> some View {
        PanelSection(title: "Corners") {
            ColorPickerRow(
                title: "Top-left",
                color: meshBinding(for: background, index: 0)
            )
            ColorPickerRow(
                title: "Top-right",
                color: meshBinding(for: background, index: 2)
            )
            ColorPickerRow(
                title: "Bottom-left",
                color: meshBinding(for: background, index: 6)
            )
            ColorPickerRow(
                title: "Bottom-right",
                color: meshBinding(for: background, index: 8)
            )
        }
    }

    private func meshBinding(for background: Background, index: Int) -> Binding<Color> {
        Binding(
            get: { background.meshColors[index] },
            set: { newColor in
                project.recordUndo()
                background.meshColors[index] = newColor
                background.meshColors = Color.mesh3x3(
                    topLeft: background.meshColors[0],
                    topRight: background.meshColors[2],
                    bottomLeft: background.meshColors[6],
                    bottomRight: background.meshColors[8]
                )
            }
        )
    }

}

private extension BackgroundKind {
    var label: String {
        switch self {
        case .solid:          return "Solid"
        case .linearGradient: return "Linear"
        case .radialGradient: return "Radial"
        case .meshGradient:   return "Mesh"
        }
    }
}

