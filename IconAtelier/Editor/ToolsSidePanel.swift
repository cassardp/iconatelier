import SwiftUI

struct EditTabContent: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let layer = project.layer(withID: session.selectedLayerUUID) {
                    LayerActionsRow(project: project, session: session, layer: layer)
                    SectionDivider()
                    contentSection(for: layer)
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
