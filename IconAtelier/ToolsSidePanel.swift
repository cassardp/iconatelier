import SwiftUI

struct EditTabContent: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @Environment(\.dismiss) private var dismiss
    @Namespace private var kindPickerNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let layer = project.layer(withID: session.selectedLayerUUID) {
                    actionsRow(for: layer)
                    SectionDivider()
                    if layer.kind != .aiOverlay {
                        kindPicker(for: layer)
                    }
                    contentSection(for: layer)
                    SectionDivider()
                    transformSection(for: layer)
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

    // MARK: - Kind picker (text vs symbol)

    private enum OverlayMode: String, CaseIterable, Identifiable {
        case text
        case symbol
        var id: String { rawValue }
        var label: String { self == .text ? "Text" : "Symbol" }
    }

    @ViewBuilder
    private func kindPicker(for layer: Layer) -> some View {
        let current: OverlayMode = layer.kind == .symbol ? .symbol : .text
        HStack(spacing: 4) {
            ForEach(OverlayMode.allCases) { mode in
                let isSelected = mode == current
                Button {
                    guard !isSelected else { return }
                    let newKind: LayerKind = mode == .symbol ? .symbol : .text
                    project.recordUndo()
                    if layer.kind == .emoji, newKind == .text, !layer.emoji.isEmpty {
                        layer.text = layer.emoji
                    }
                    withAnimation(.smooth(duration: 0.25)) {
                        layer.kind = newKind
                    }
                } label: {
                    Text(mode.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary.opacity(isSelected ? 1 : 0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if isSelected {
                                RoundedRectangle(
                                    cornerRadius: PanelStyle.cornerRadius - 4,
                                    style: .continuous
                                )
                                .fill(PanelStyle.rowFillActive)
                                .matchedGeometryEffect(
                                    id: "kindPickerSelection",
                                    in: kindPickerNamespace
                                )
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }

    // MARK: - Content (per kind)

    @ViewBuilder
    private func contentSection(for layer: Layer) -> some View {
        switch layer.kind {
        case .aiOverlay:
            AIOverlayContentSection(layer: layer, project: project)
        case .symbol:
            SymbolContentSection(layer: layer, project: project)
        case .text, .emoji:
            TextContentSection(layer: layer, project: project)
        }
    }

    // MARK: - Quick actions

    @ViewBuilder
    private func actionsRow(for layer: Layer) -> some View {
        HStack(spacing: 8) {
            CompactActionButton(
                title: layer.isHidden ? "Show" : "Hide",
                systemImage: layer.isHidden ? "eye" : "eye.slash"
            ) {
                project.toggleVisibility(layer)
            }
            CompactActionButton(
                title: "Flip Horizontal",
                systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right"
            ) {
                withAnimation(.smooth(duration: 0.25)) {
                    project.flipHorizontally(layer)
                }
            }
            CompactActionButton(
                title: "Flip Vertical",
                systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down"
            ) {
                withAnimation(.smooth(duration: 0.25)) {
                    project.flipVertically(layer)
                }
            }
            CompactActionButton(
                title: "Reset",
                systemImage: "arrow.counterclockwise"
            ) {
                project.resetTransform(layer)
            }
            CompactActionButton(
                title: "Duplicate",
                systemImage: "square.on.square"
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    let copy = project.duplicate(layer)
                    session.selectLayer(copy.uuid)
                }
            }
            CompactActionButton(
                title: "Delete",
                systemImage: "trash"
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    let wasSelected = session.selectedLayerUUID == layer.uuid
                    project.remove(layer)
                    if wasSelected {
                        session.selectedLayerUUID = project.layers.last?.uuid
                    }
                }
            }
        }
    }

    // MARK: - Transform

    @ViewBuilder
    private func transformSection(for layer: Layer) -> some View {
        PanelSection(title: "Transform") {
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
                    get: { layer.rotation.degrees },
                    set: { layer.rotation = .degrees($0) }
                ),
                range: -180 ... 180,
                valueText: { String(format: "%.0f°", $0) },
                defaultValue: 0,
                onBeginEditing: { project.recordUndo() }
            )
        }

        SectionDivider()
        PanelSection(title: "Offset") {
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

        SectionDivider()
        PanelSection(title: "Shadow") {
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
