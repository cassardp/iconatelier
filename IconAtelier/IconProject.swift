import SwiftUI
import UIKit

struct IconProjectSnapshot {
    let layers: [LayerSnapshot]
    let selectedLayerID: UUID?
}

@MainActor
@Observable
final class IconProject {
    var layers: [Layer] = []
    var selectedLayerID: Layer.ID?

    var isGenerating: Bool = false
    var lastError: String?

    private var undoStack: [IconProjectSnapshot] = []
    private var redoStack: [IconProjectSnapshot] = []
    private let maxUndoSteps = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var selectedLayer: Layer? {
        guard let id = selectedLayerID else { return nil }
        return layers.first { $0.id == id }
    }

    var hasContent: Bool { !layers.isEmpty }

    var background: Layer? {
        layers.first { $0.kind == .aiBackground }
    }

    var overlays: [Layer] {
        layers.filter { $0.kind == .aiOverlay }
    }

    // MARK: - Snapshot / undo

    private func currentSnapshot() -> IconProjectSnapshot {
        IconProjectSnapshot(
            layers: layers.map { $0.snapshot() },
            selectedLayerID: selectedLayerID
        )
    }

    private func apply(_ snapshot: IconProjectSnapshot) {
        layers = snapshot.layers.map { Layer(snapshot: $0) }
        selectedLayerID = snapshot.selectedLayerID
    }

    func recordUndo() {
        undoStack.append(currentSnapshot())
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst(undoStack.count - maxUndoSteps)
        }
        redoStack.removeAll()
    }

    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        apply(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        apply(next)
    }

    // MARK: - Mutations

    private func performAdd(_ layer: Layer) {
        if layer.kind == .aiBackground {
            layers.insert(layer, at: 0)
        } else {
            layers.append(layer)
        }
        selectedLayerID = layer.id
    }

    func remove(_ layer: Layer) {
        recordUndo()
        layers.removeAll { $0.id == layer.id }
        if selectedLayerID == layer.id {
            selectedLayerID = layers.last?.id
        }
    }

    func duplicate(_ layer: Layer) {
        recordUndo()
        let copy = Layer(
            kind: layer.kind,
            name: layer.name + " copy",
            image: layer.image,
            sourcePrompt: layer.sourcePrompt
        )
        copy.offset = layer.offset
        copy.scale = layer.scale
        copy.rotation = layer.rotation
        copy.opacity = layer.opacity

        if let idx = layers.firstIndex(where: { $0.id == layer.id }) {
            layers.insert(copy, at: idx + 1)
        } else {
            layers.append(copy)
        }
        selectedLayerID = copy.id
    }

    func move(from source: IndexSet, to destination: Int) {
        recordUndo()
        layers.move(fromOffsets: source, toOffset: destination)
    }

    func setOrReplaceBackground(image: UIImage, prompt: String) {
        recordUndo()
        if let existing = background {
            existing.image = image
            existing.sourcePrompt = prompt
            selectedLayerID = existing.id
        } else {
            let bg = Layer(
                kind: .aiBackground,
                name: "Background",
                image: image,
                sourcePrompt: prompt
            )
            performAdd(bg)
        }
    }

    func addOverlay(image: UIImage, prompt: String) {
        recordUndo()
        let index = overlays.count + 1
        let name = index == 1 ? "Overlay" : "Overlay \(index)"
        let layer = Layer(
            kind: .aiOverlay,
            name: name,
            image: image,
            sourcePrompt: prompt
        )
        performAdd(layer)
    }

    func toggleVisibility(_ layer: Layer) {
        recordUndo()
        layer.isHidden.toggle()
    }
}
