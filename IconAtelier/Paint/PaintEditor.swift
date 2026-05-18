import SwiftUI

struct PaintEditor: View {
    @Binding var paint: Paint

    let onBeginEditing: () -> Void

    var body: some View {

        VStack(spacing: 14) {
            editorRows
        }
    }

    static func sectionTitle(for kind: PaintKind) -> String {
        kind == .solid ? "Color" : "Gradient"
    }

    @ViewBuilder
    private var editorRows: some View {
        kindPickerRow
        if hasPresets {
            presetsSection
        }
        geometryBlock
        if paint.kind == .meshGradient {
            meshAngleSlider
        }
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

    @ViewBuilder
    private var geometryBlock: some View {
        switch paint.kind {
        case .solid:
            solidColorRow
        case .linearGradient:
            gradientPadBlock {
                LinearGradientPad(paint: $paint, onBeginEditing: onBeginEditing)
            }
        case .radialGradient:
            gradientPadBlock {
                RadialGradientPad(paint: $paint, onBeginEditing: onBeginEditing)
            }
        case .meshGradient:
            gradientPadBlock {
                MeshGradientPad(paint: $paint, onBeginEditing: onBeginEditing)
            }
        }
    }

    @ViewBuilder
    private func gradientPadBlock<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.vertical, padBlockVerticalPadding)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(
                    cornerRadius: PanelStyle.cornerRadius,
                    style: .continuous
                )
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
    }

    private let padBlockVerticalPadding: CGFloat = 48

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
            linearPresetsRow
        case .radialGradient:
            radialPresetsRow
        case .meshGradient:
            meshPresetsRow
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

                paint.meshCornerPoints = Paint.defaultMeshCornerPoints
                paint.meshRotationDegrees = 0
            }
        )
    }
}
