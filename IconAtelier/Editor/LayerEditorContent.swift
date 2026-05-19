import SwiftUI

struct LayerEditorContent: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let layer = project.layer(withID: session.selectedLayerUUID) {
                    layerSection(for: layer)
                    SectionDivider()
                    contentSection(for: layer)

                    if supportsBorder(layer) {
                        SectionDivider()
                        borderSection(for: layer)
                    }

                    SectionDivider()
                    shadowSection(for: layer)

                    if supportsTransform(layer) {
                        SectionDivider()
                        transformSection(for: layer)
                    }

                    if supportsRadialRepeat(layer) {
                        SectionDivider()
                        radialRepeatSection(for: layer)
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
    private func layerSection(for layer: Layer) -> some View {
        PanelSection(title: "Layer") {
            OpacitySlider(layer: layer, project: project)
        }
    }

    // MARK: - Content (per kind)

    @ViewBuilder
    private func contentSection(for layer: Layer) -> some View {
        switch layer.kind {
        case .image:
            ImageContentSection(layer: layer, project: project)
        case .text:
            TextContentSection(layer: layer, project: project)
        case .parametricShape:
            ShapeContentSection(layer: layer, project: project)
        }
    }

    // MARK: - Border (text + shape, with kind-specific defaults/range)

    @ViewBuilder
    private func borderSection(for layer: Layer) -> some View {

        let isText = layer.kind == .text
        let widthDefault = isText ? BorderDefaults.textWidth : BorderDefaults.shapeWidth
        let widthRange: ClosedRange<Double> = isText ? 0 ... 0.2 : 0 ... 0.5
        let valueScale: Double = isText ? 500 : 200

        PanelSection(
            title: "Border",
            isOn: BorderPanelContent.enabledBinding(
                layer: layer,
                project: project,
                widthDefault: widthDefault
            )
        ) {
            BorderPanelContent(
                layer: layer,
                project: project,
                widthRange: widthRange,
                widthDefault: widthDefault,
                widthValueText: { String(format: "%.0f%%", $0 * valueScale) }
            )
        }
    }

    // MARK: - Shadow

    @ViewBuilder
    private func shadowSection(for layer: Layer) -> some View {
        PanelSection(
            title: "Shadow",
            isOn: ShadowPanelContent.enabledBinding(layer: layer, project: project)
        ) {
            ShadowPanelContent(layer: layer, project: project)
        }
    }

    // MARK: - Transform (shape only, when family supports stretch)

    @ViewBuilder
    private func transformSection(for layer: Layer) -> some View {
        PanelSection(
            title: "Transform",
            isOn: TransformPanelContent.enabledBinding(layer: layer, project: project)
        ) {
            TransformPanelContent(layer: layer, project: project)
        }
    }

    // MARK: - Radial repeat (text + shape, with kind-specific wrap base)

    @ViewBuilder
    private func radialRepeatSection(for layer: Layer) -> some View {

        let isText = layer.kind == .text

        PanelSection(
            title: "Radial repeat",
            isOn: RadialRepeatPanelContent.enabledBinding(
                layer: layer,
                project: project,
                wrapBase: { isText ? .iosSquircle : (layer.shapeSpec ?? .defaultShape) },
                disabledShapeSpec: { isText ? nil : layer.shapeSpec?.unwrapped }
            )
        ) {
            RadialRepeatPanelContent(layer: layer, project: project)
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
    @Bindable var layer: Layer
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
