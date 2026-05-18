import SwiftUI

/// Reusable editor for a `Paint` value — kind picker, geometry pad,
/// per-kind controls (mesh angle), and presets. Used both by the
/// background editor and by the shape/text fill section so a layer fill
/// can be any of the same gradients the canvas background supports.
///
/// Layout, top → bottom:
///   1. **Primary block** — segmented Type picker glued to the per-kind
///      geometry body without a divider: a `ColorPickerRow` for solid,
///      or the matching pad for the three gradient kinds. Each pad gets
///      its own vertical padding so colored handles have touch-room
///      above and below — they can drift past the pad edges (linear up
///      to ±50%, mesh up to ±25%). The mesh angle slider sits under the
///      mesh pad inside this same block.
///   2. **Presets** — its own titled section, after a `SectionDivider`.
///      Hidden for solid.
///
/// Two layout modes:
/// - `sectioned: true` (background editor) — top-level. The primary
///   block is wrapped in a titled `PanelSection` ("Color" or "Gradient")
///   so it reads as a real section in the panel.
/// - `sectioned: false` (shape/text fill, embedded in a parent "Fill"
///   `PanelSection`) — segmented + geometry emitted bare, no inner
///   title (parent's title speaks for them). The divider before Presets
///   is kept so the geometry/presets rhythm stays consistent with the
///   sectioned mode.
struct PaintEditor: View {
    @Binding var paint: Paint
    /// Called once per discrete edit (start of a slider drag, color
    /// picker tap, preset tap, kind switch…). Wire to
    /// `project.recordUndo()` — its own coalescing window dedupes the
    /// rapid-fire calls a `ColorPicker` produces.
    let onBeginEditing: () -> Void
    /// `true` for the background editor (top-level, gets section
    /// dividers). `false` when embedded inside a parent `PanelSection`
    /// like the shape "Fill" — no inner dividers, lighter rhythm.
    var sectioned: Bool = true

    var body: some View {
        if sectioned {
            VStack(spacing: 18) {
                PanelSection(title: primarySectionTitle) {
                    kindPickerRow
                    geometryBlock
                }
                if hasPresets {
                    SectionDivider()
                    presetsSection
                }
            }
        } else {
            // Flat mode: parent (e.g. "Fill") already owns the section
            // title — don't stack a second "Gradient"/"Color" header
            // inside it. Segmented + geometry stand alone, divider kept
            // before presets so the rhythm matches the sectioned mode.
            VStack(spacing: 14) {
                kindPickerRow
                geometryBlock
                if hasPresets {
                    SectionDivider()
                    presetsSection
                }
            }
        }
    }

    /// Header label for the primary section (sectioned mode only).
    /// "Color" for solid, "Gradient" for the three gradient kinds.
    private var primarySectionTitle: String {
        paint.kind == .solid ? "Color" : "Gradient"
    }

    // MARK: - Type picker

    private static let pickerKinds: [PaintKind] = [
        .solid, .linearGradient, .radialGradient, .meshGradient
    ]

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

    // MARK: - Geometry

    /// Per-kind editor body. Padding is applied directly on each pad
    /// (not on the whole block) so the mesh pad keeps its bottom
    /// breathing room *between the pad and the angle slider* — wrapping
    /// the whole `VStack` in padding would put the bottom buffer below
    /// the angle slider instead, leaving the pad's bottom handles
    /// pressed against the slider.
    @ViewBuilder
    private var geometryBlock: some View {
        switch paint.kind {
        case .solid:
            solidColorRow
        case .linearGradient:
            LinearGradientPad(paint: $paint, onBeginEditing: onBeginEditing)
                .padding(.vertical, padVerticalPadding)
        case .radialGradient:
            RadialGradientPad(paint: $paint, onBeginEditing: onBeginEditing)
                .padding(.vertical, padVerticalPadding)
        case .meshGradient:
            VStack(spacing: 0) {
                MeshGradientPad(paint: $paint, onBeginEditing: onBeginEditing)
                    .padding(.vertical, padVerticalPadding)
                meshAngleSlider
            }
        }
    }

    /// Top/bottom padding around a gradient pad — buys touch-room for
    /// handles that can drift past the pad's outer edge.
    private let padVerticalPadding: CGFloat = 12

    // MARK: - Presets

    private var hasPresets: Bool {
        paint.kind != .solid
    }

    @ViewBuilder
    private var presetsSection: some View {
        switch paint.kind {
        case .solid:
            EmptyView()
        case .linearGradient:
            PanelSection(title: "Presets") { linearPresetsRow }
        case .radialGradient:
            PanelSection(title: "Presets") { radialPresetsRow }
        case .meshGradient:
            PanelSection(title: "Presets") { meshPresetsRow }
        }
    }

    // MARK: - Solid

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

    // MARK: - Linear presets

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

    // MARK: - Radial presets

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

    // MARK: - Mesh

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

    private var meshPresetsRow: some View {
        BackgroundPresetsRow(
            presets: BackgroundPresets.mesh,
            thumbnail: { preset in
                MeshGradient(
                    width: 5,
                    height: 5,
                    points: Paint.mesh25Points(corners: Paint.defaultMeshCornerPoints),
                    colors: Paint.mesh25Colors(from: preset.meshColors)
                )
            },
            onSelect: { preset in
                onBeginEditing()
                paint.meshColors = preset.meshColors.map { StoredColor($0) }
                // Reset any previous corner warp + rotation so the preset
                // renders with the canonical layout shown in the thumbnail.
                paint.meshCornerPoints = Paint.defaultMeshCornerPoints
                paint.meshRotationDegrees = 0
            }
        )
    }
}
