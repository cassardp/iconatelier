import SwiftUI
import UIKit

struct PaintEditor: View {
    @Environment(PresetStore.self) private var presetStore

    @Binding var paint: Paint

    let onBeginEditing: () -> Void

//    @State private var showSaveAlert = false
//    @State private var newPresetName = ""
//    @State private var showResetConfirm = false
//    @State private var showExportConfirm = false

    var body: some View {

        VStack(spacing: 7) {
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
        VStack(spacing: 6) {
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
//            presetActionsRow
        }
    }

    // MARK: - Preset actions
    /* --- Background save system (save / reset / export user presets) — disabled, uncomment to re-enable ---

    private var presetActionsRow: some View {
        HStack(spacing: 28) {
            Spacer()
            Button {
                newPresetName = defaultCustomName
                showSaveAlert = true
            } label: {
                Image(systemName: "plus.square")
            }
            .accessibilityLabel("Save current as preset")

            Button {
                showResetConfirm = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(userPresetCountForKind == 0)
            .accessibilityLabel("Reset presets")

            Button {
                copyExportToPasteboard()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Export presets JSON")

            Spacer()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .font(.title2)
        .padding(.top, 4)
        .alert("Save preset", isPresented: $showSaveAlert) {
            TextField("Name", text: $newPresetName)
            Button("Save") { savePresetFromAlert() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add the current \(paint.kind.label.lowercased()) settings to your presets.")
        }
        .alert("Reset \(paint.kind.label) presets?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                presetStore.reset(kind: paint.kind)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes your saved \(paint.kind.label.lowercased()) presets and restores the originals.")
        }
        .alert("Copied", isPresented: $showExportConfirm) {
            Button("OK") {}
        } message: {
            Text("\(paint.kind.label) presets JSON is on the clipboard.")
        }
    }

    private var userPresetCountForKind: Int {
        let counts = presetStore.userCount
        switch paint.kind {
        case .solid: return 0
        case .linearGradient: return counts.linear
        case .radialGradient: return counts.radial
        case .meshGradient: return counts.mesh
        }
    }

    private var defaultCustomName: String {
        "Custom \(userPresetCountForKind + 1)"
    }

    private func savePresetFromAlert() {
        let trimmed = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? defaultCustomName : trimmed
        switch paint.kind {
        case .solid: return
        case .linearGradient: presetStore.addLinear(name: name, from: paint)
        case .radialGradient: presetStore.addRadial(name: name, from: paint)
        case .meshGradient: presetStore.addMesh(name: name, from: paint)
        }
    }

    private func copyExportToPasteboard() {
        UIPasteboard.general.string = presetStore.exportJSON(kind: paint.kind)
        showExportConfirm = true
    }
    --- end background save system --- */

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
            presets: presetStore.linear,
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
            /*,
            canDelete: { preset in
                presetStore.isUserPreset(kind: .linearGradient, name: preset.name)
            },
            onDelete: { preset in
                presetStore.removeUserPreset(kind: .linearGradient, name: preset.name)
            }*/
        )
    }

    // MARK: - Radial presets

    private var radialPresetsRow: some View {
        BackgroundPresetsRow(
            presets: presetStore.radial,
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
                paint.gradientCenter = preset.center.map { StoredPoint($0) }
                    ?? StoredPoint(x: 0.5, y: 0.5)
                paint.radialSpread = preset.spread ?? 0.75
            }
            /*,
            canDelete: { preset in
                presetStore.isUserPreset(kind: .radialGradient, name: preset.name)
            },
            onDelete: { preset in
                presetStore.removeUserPreset(kind: .radialGradient, name: preset.name)
            }*/
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
            presets: presetStore.mesh,
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

                if let corners = preset.cornerPoints, corners.count == 4 {
                    paint.meshCornerPoints = corners.map { StoredPoint($0) }
                } else {
                    paint.meshCornerPoints = Paint.defaultMeshCornerPoints
                }
                paint.meshRotationDegrees = preset.rotationDegrees ?? 0
            }
            /*,
            canDelete: { preset in
                presetStore.isUserPreset(kind: .meshGradient, name: preset.name)
            },
            onDelete: { preset in
                presetStore.removeUserPreset(kind: .meshGradient, name: preset.name)
            }*/
        )
    }
}
