import SwiftUI

struct LayerEditorContent: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let id = session.selectedLayerUUID,
                   let layerBinding = project.layerBinding(id: id) {
                    let layer = layerBinding.wrappedValue
                    LayerQuickActionsRow(project: project, session: session)
                    SectionDivider()
                    layerSection(layerBinding: layerBinding)
                    SectionDivider()
                    contentSection(layerBinding: layerBinding, kind: layer.kind)

                    if supportsBorder(layer) {
                        SectionDivider()
                        borderSection(layerBinding: layerBinding, kind: layer.kind)
                    }

                    SectionDivider()
                    shadowSection(layerBinding: layerBinding)

                    if supportsTransform(layer) {
                        SectionDivider()
                        transformSection(layerBinding: layerBinding)
                    }

                    if supportsRadialRepeat(layer) {
                        SectionDivider()
                        radialRepeatSection(layerBinding: layerBinding, kind: layer.kind)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 14)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .onChange(of: session.selectedLayerUUID) { _, newID in
            if newID == nil { dismiss() }
        }
    }

    // MARK: - Layer (cross-kind: opacity, etc.)

    @ViewBuilder
    private func layerSection(layerBinding: Binding<Layer>) -> some View {
        PanelSection(title: "Layer") {
            OpacitySlider(layer: layerBinding, project: project)
        }
    }

    // MARK: - Content (per kind)

    @ViewBuilder
    private func contentSection(layerBinding: Binding<Layer>, kind: LayerKind) -> some View {
        switch kind {
        case .image:
            ImageContentSection(layer: layerBinding, project: project)
        case .text:
            TextContentSection(layer: layerBinding, project: project)
        case .parametricShape:
            ShapeContentSection(layer: layerBinding, project: project)
        }
    }

    // MARK: - Border (text + shape, with kind-specific defaults/range)

    @ViewBuilder
    private func borderSection(layerBinding: Binding<Layer>, kind: LayerKind) -> some View {

        let isText = kind == .text
        let widthDefault = isText ? BorderDefaults.textWidth : BorderDefaults.shapeWidth
        let widthRange: ClosedRange<Double> = isText ? 0 ... 0.2 : 0 ... 0.5
        let valueScale: Double = isText ? 500 : 200

        PanelSection(
            title: "Border",
            isOn: BorderPanelContent.enabledBinding(
                layer: layerBinding,
                project: project,
                widthDefault: widthDefault
            )
        ) {
            BorderPanelContent(
                layer: layerBinding,
                project: project,
                widthRange: widthRange,
                widthDefault: widthDefault,
                widthValueText: { String(format: "%.0f%%", $0 * valueScale) }
            )
        }
    }

    // MARK: - Shadow

    @ViewBuilder
    private func shadowSection(layerBinding: Binding<Layer>) -> some View {
        PanelSection(
            title: "Shadow",
            isOn: ShadowPanelContent.enabledBinding(layer: layerBinding, project: project)
        ) {
            ShadowPanelContent(layer: layerBinding, project: project)
        }
    }

    // MARK: - Transform (shape only, when family supports stretch)

    @ViewBuilder
    private func transformSection(layerBinding: Binding<Layer>) -> some View {
        PanelSection(
            title: "Transform",
            isOn: TransformPanelContent.enabledBinding(layer: layerBinding, project: project)
        ) {
            TransformPanelContent(layer: layerBinding, project: project)
        }
    }

    // MARK: - Radial repeat (text + shape, with kind-specific wrap base)

    @ViewBuilder
    private func radialRepeatSection(layerBinding: Binding<Layer>, kind: LayerKind) -> some View {
        PanelSection(
            title: "Radial repeat",
            isOn: RadialRepeatPanelContent.enabledBinding(
                layer: layerBinding,
                project: project
            )
        ) {
            RadialRepeatPanelContent(layer: layerBinding, project: project)
        }
    }

    // MARK: - Per-kind capability gates

    private func supportsBorder(_ layer: Layer) -> Bool {
        switch layer.kind {
        case .image: return false
        case .text, .parametricShape: return true
        }
    }

    private func supportsTransform(_ layer: Layer) -> Bool {
        guard layer.kind == .parametricShape else { return false }
        return layer.shapeSpec?.supportsTransform ?? false
    }

    private func supportsRadialRepeat(_ layer: Layer) -> Bool {
        switch layer.kind {
        case .image: return false
        case .text, .parametricShape: return true
        }
    }
}

// MARK: - Opacity row

struct OpacitySlider: View {
    @Binding var layer: Layer
    let project: IconProject

    var body: some View {
        DialSliderRow(
            label: "Opacity",
            value: Binding(
                get: { layer.opacity },
                set: { layer.opacity = $0 }
            ),
            range: 0 ... 1,
            valueText: { String(format: "%.0f%%", $0 * 100) },
            defaultValue: 1.0,
            onBeginEditing: { project.recordUndo() }
        )
    }
}
