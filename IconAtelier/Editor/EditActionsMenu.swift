import SwiftUI
import UIKit

struct EditActionsMenu: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    @Binding var showImportPicker: Bool

    var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder
    private var menuContent: some View {
        let canPaste = LayerClipboard.hasContent

        if hasActiveLayers || canPaste {
            ControlGroup {
                if hasActiveLayers {
                    Button {
                        copyActiveLayers()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button {
                        cutActiveLayers()
                    } label: {
                        Label("Cut", systemImage: "scissors")
                    }
                }
                if canPaste {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                }
            }
            Divider()
        }

        if session.isBackgroundSelected {
            let background = project.safeBackground
            Button {
                project.recordUndo()
                background.isHidden.toggle()
            } label: {
                Label(
                    background.isHidden ? "Show Background" : "Hide Background",
                    systemImage: background.isHidden ? "eye" : "eye.slash"
                )
            }
            Button {
                withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
                    let layer = project.addShapeLayer(spec: .iosSquircle)
                    session.selectLayer(layer.uuid)
                }
            } label: {
                Label("Add App Silhouette", systemImage: "app.fill")
            }
            Divider()
        } else if hasActiveLayers {
            if let single = singleActiveLayer {
                Button {
                    project.toggleVisibility(single)
                } label: {
                    Label(
                        single.isHidden ? "Show" : "Hide",
                        systemImage: single.isHidden ? "eye" : "eye.slash"
                    )
                }
            }
            Button {
                duplicateActiveLayers()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button {
                bringActiveLayersToFront()
            } label: {
                Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled")
            }
            Button {
                sendActiveLayersToBack()
            } label: {
                Label("Send to Back", systemImage: "square.3.layers.3d.bottom.filled")
            }
            Button {
                flipActiveLayers(horizontal: true)
            } label: {
                Label("Flip Horizontal", systemImage: "arrow.left.and.right")
            }
            Button {
                flipActiveLayers(horizontal: false)
            } label: {
                Label("Flip Vertical", systemImage: "arrow.up.and.down")
            }
            Divider()
        }

        if !project.layers.isEmpty {
            Button {
                selectAllLayers()
            } label: {
                Label("Select All", systemImage: "square.on.square.dashed")
            }
        }
        Button {
            showImportPicker = true
        } label: {
            Label("Import Image", systemImage: "square.and.arrow.down")
        }

        if hasActiveLayers {
            Divider()
            Button(role: .destructive) {
                deleteActiveLayers()
            } label: {
                Label(
                    activeLayerUUIDs.count > 1 ? "Delete Layers" : "Delete Layer",
                    systemImage: "trash"
                )
            }
        }
    }

    // MARK: - Selection helpers

    private var activeLayerUUIDs: [UUID] {
        if session.isMultiSelecting {
            return Array(session.lassoSelectedLayerUUIDs)
        }
        if !session.isBackgroundSelected,
           let uuid = session.selectedLayerUUID,
           project.layer(withID: uuid) != nil {
            return [uuid]
        }
        return []
    }

    private var hasActiveLayers: Bool { !activeLayerUUIDs.isEmpty }

    private var singleActiveLayer: Layer? {
        guard activeLayerUUIDs.count == 1, let uuid = activeLayerUUIDs.first else { return nil }
        return project.layer(withID: uuid)
    }

    // MARK: - Actions

    private func copyActiveLayers() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        let selected = project.layers.filter { uuids.contains($0.uuid) }
        guard !selected.isEmpty else { return }
        LayerClipboard.copy(selected)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func cutActiveLayers() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        let selected = project.layers.filter { uuids.contains($0.uuid) }
        guard !selected.isEmpty else { return }
        LayerClipboard.copy(selected)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            project.removeLayers(uuids: uuids)
            session.clearLassoSelection()
            if let top = project.layers.last {
                session.selectLayer(top.uuid)
            } else {
                session.selectBackground()
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func duplicateActiveLayers() {
        let uuids = activeLayerUUIDs
        guard !uuids.isEmpty else { return }
        let sources = project.layers.filter { uuids.contains($0.uuid) }
        guard !sources.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            var copies: [Layer] = []
            for source in sources {
                copies.append(project.duplicate(source))
            }
            session.clearLassoSelection()
            if let last = copies.last {
                session.selectLayer(last.uuid)
            }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func flipActiveLayers(horizontal: Bool) {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        let targets = project.layers.filter { uuids.contains($0.uuid) }
        guard !targets.isEmpty else { return }
        project.recordUndo()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            for layer in targets {
                if horizontal {
                    layer.isFlippedHorizontally.toggle()
                } else {
                    layer.isFlippedVertically.toggle()
                }
            }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func bringActiveLayersToFront() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            project.bringToFront(uuids: uuids)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func sendActiveLayersToBack() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            project.sendToBack(uuids: uuids)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func selectAllLayers() {
        let uuids = Set(project.layers.map(\.uuid))
        guard !uuids.isEmpty else { return }
        if uuids.count >= 2 {
            session.setLassoSelection(uuids)
        } else if let only = uuids.first {
            session.selectLayer(only)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func deleteActiveLayers() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            project.removeLayers(uuids: uuids)
            session.clearLassoSelection()
            if let top = project.layers.last {
                session.selectLayer(top.uuid)
            } else {
                session.selectBackground()
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func pasteFromClipboard() {
        guard let pasted = LayerClipboard.paste(), !pasted.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            let inserted = project.addPastedLayers(pasted)
            if let top = inserted.last {
                session.clearLassoSelection()
                session.selectLayer(top.uuid)
            }
        }
    }
}
