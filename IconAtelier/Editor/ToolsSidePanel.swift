import SwiftUI

struct EditTabContent: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let layer = project.layer(withID: session.selectedLayerUUID) {
                    contentSection(for: layer)
                    // Parametric shapes fold Transform + Offset into their
                    // own "Shape" section (everything geometry-related stays
                    // grouped). Other kinds still get the generic stack.
                    if layer.kind != .parametricShape {
                        SectionDivider()
                        transformOffsetSection(for: layer)
                    }
                    SectionDivider()
                    shadowSection(for: layer)
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

    // MARK: - Content (per kind)

    @ViewBuilder
    private func contentSection(for layer: Layer) -> some View {
        switch layer.kind {
        case .image:
            ImageContentSection(layer: layer, project: project)
        case .text, .emoji:
            TextContentSection(layer: layer, project: project)
        case .parametricShape:
            ParametricShapeContentSection(layer: layer, project: project)
        }
    }

    // MARK: - Transform / Offset (non-parametric only)

    @ViewBuilder
    private func transformOffsetSection(for layer: Layer) -> some View {
        PanelSection(title: "Transform") {
            TransformSliders(layer: layer, project: project)
        }

        SectionDivider()
        PanelSection(title: "Offset") {
            OffsetSliders(layer: layer, project: project)
        }
    }

    // MARK: - Shadow

    @ViewBuilder
    private func shadowSection(for layer: Layer) -> some View {
        PanelSection(title: "Shadow") {
            ColorPickerRow(
                title: "Color",
                color: Binding(
                    get: { layer.shadowColor },
                    set: { layer.shadowColor = $0 }
                ),
                project: project
            )

            DialSliderRow(
                label: "Opacity",
                value: Binding(
                    get: { layer.shadowOpacity },
                    set: { layer.shadowOpacity = $0 }
                ),
                range: 0 ... 1,
                valueText: { String(format: "%.0f%%", $0 * 100) },
                defaultValue: 0,
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
                defaultValue: 0,
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
                defaultValue: 0,
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
                defaultValue: 0,
                onBeginEditing: { project.recordUndo() }
            )
        }
    }
}

// MARK: - Shared transform/offset rows

struct TransformSliders: View {
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

        DialSliderRow(
            label: "Scale",
            value: Binding(
                get: { Double(layer.scale) },
                set: { layer.scale = CGFloat($0) }
            ),
            range: 0.1 ... 5.0,
            valueText: { String(format: "%.2f", $0) },
            defaultValue: 1.0,
            onBeginEditing: { project.recordUndo() }
        )

        DialSliderRow(
            label: "Rotation",
            value: Binding(
                get: {
                    let d = layer.rotation.degrees
                    return d.isFinite ? IconCanvasView.normalized(.degrees(d)).degrees : 0
                },
                set: { layer.rotation = IconCanvasView.normalized(.degrees($0)) }
            ),
            range: -180 ... 180,
            valueText: { String(format: "%.0f°", $0) },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
    }
}

struct OffsetSliders: View {
    @Bindable var layer: Layer
    let project: IconProject

    var body: some View {
        DialSliderRow(
            label: "Offset X",
            value: Binding(
                get: { Double(layer.offset.width) },
                set: { layer.offset = CGSize(width: CGFloat($0), height: layer.offset.height) }
            ),
            range: -1.0 ... 1.0,
            valueText: { String(format: "%+.2f", $0) },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )

        DialSliderRow(
            label: "Offset Y",
            value: Binding(
                get: { Double(layer.offset.height) },
                set: { layer.offset = CGSize(width: layer.offset.width, height: CGFloat($0)) }
            ),
            range: -1.0 ... 1.0,
            valueText: { String(format: "%+.2f", $0) },
            defaultValue: 0,
            onBeginEditing: { project.recordUndo() }
        )
    }
}
