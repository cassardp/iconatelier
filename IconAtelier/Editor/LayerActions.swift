import SwiftUI
import UIKit

struct LayerActions {
    let project: IconProject
    let session: ProjectSession

    // MARK: - Selection

    var activeLayerUUIDs: [UUID] {
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

    var hasActiveLayers: Bool { !activeLayerUUIDs.isEmpty }

    var singleActiveLayer: Layer? {
        guard activeLayerUUIDs.count == 1, let uuid = activeLayerUUIDs.first else { return nil }
        return project.layer(withID: uuid)
    }

    var canPaste: Bool { LayerClipboard.hasContent }

    // MARK: - Clipboard

    func copy() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        let selected = project.layers.filter { uuids.contains($0.uuid) }
        guard !selected.isEmpty else { return }
        LayerClipboard.copy(selected)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func cut() {
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

    func paste() {
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

    // MARK: - Layer ops

    func duplicate() {
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

    func delete() {
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

    func toggleLock(_ layer: Layer) {
        project.toggleLock(layer)
    }

    var allSelectedLocked: Bool {
        let uuids = activeLayerUUIDs
        guard !uuids.isEmpty else { return false }
        let targets = project.layers.filter { uuids.contains($0.uuid) }
        guard !targets.isEmpty else { return false }
        return targets.allSatisfy(\.isLocked)
    }

    func toggleLockSelection() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        let targets = project.layers.filter { uuids.contains($0.uuid) }
        guard !targets.isEmpty else { return }
        let shouldLock = !targets.allSatisfy(\.isLocked)
        project.recordUndo()
        for layer in targets {
            layer.isLocked = shouldLock
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func flip(horizontal: Bool) {
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

    func bringToFront() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            project.bringToFront(uuids: uuids)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func sendToBack() {
        let uuids = Set(activeLayerUUIDs)
        guard !uuids.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            project.sendToBack(uuids: uuids)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func selectAll() {
        let uuids = Set(project.layers.map(\.uuid))
        guard !uuids.isEmpty else { return }
        if uuids.count >= 2 {
            session.setLassoSelection(uuids)
        } else if let only = uuids.first {
            session.selectLayer(only)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
