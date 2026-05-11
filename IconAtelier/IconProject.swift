import SwiftUI
import UIKit

struct IconProjectSnapshot {
    let background: BackgroundSnapshot
    let layers: [LayerSnapshot]
    let selectedLayerID: UUID?
}

@MainActor
@Observable
final class IconProject {
    var background: Background = Background()

    var layers: [Layer] = [] {
        didSet { enforceSelectionInvariant() }
    }
    var selectedLayerID: Layer.ID? {
        didSet {
            if selectedLayerID != nil { isBackgroundSelected = false }
            enforceSelectionInvariant()
        }
    }
    var isBackgroundSelected: Bool = false

    private func enforceSelectionInvariant() {
        guard !layers.isEmpty else {
            if selectedLayerID != nil { selectedLayerID = nil }
            return
        }
        if let id = selectedLayerID, layers.contains(where: { $0.id == id }) {
            return
        }
        selectedLayerID = layers.last?.id
    }

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

    // MARK: - Snapshot / undo

    private func currentSnapshot() -> IconProjectSnapshot {
        IconProjectSnapshot(
            background: background.snapshot(),
            layers: layers.map { $0.snapshot() },
            selectedLayerID: selectedLayerID
        )
    }

    private func apply(_ snapshot: IconProjectSnapshot) {
        background = Background(snapshot: snapshot.background)
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

    // MARK: - Layer add helpers

    private func append(_ layer: Layer) {
        layers.append(layer)
        selectedLayerID = layer.id
    }

    private func nextName(for kind: LayerKind, baseFallback: String) -> String {
        let n = layers.filter { $0.kind == kind }.count + 1
        return n == 1 ? baseFallback : "\(baseFallback) \(n)"
    }

    func addAIOverlay(image: UIImage, prompt: String) {
        recordUndo()
        let layer = Layer(
            kind: .aiOverlay,
            name: nextName(for: .aiOverlay, baseFallback: "Overlay"),
            image: image,
            sourcePrompt: prompt
        )
        append(layer)
    }

    func addEmptyAIOverlay() {
        recordUndo()
        let layer = Layer(
            kind: .aiOverlay,
            name: nextName(for: .aiOverlay, baseFallback: "Overlay")
        )
        append(layer)
    }

    func addSymbolOverlay() {
        recordUndo()
        let layer = Layer(
            kind: .symbol,
            name: "star.fill"
        )
        append(layer)
    }

    func addEmojiOverlay() {
        recordUndo()
        let layer = Layer(
            kind: .emoji,
            name: "✨"
        )
        append(layer)
    }

    func addTextOverlay() {
        recordUndo()
        let layer = Layer(
            kind: .text,
            name: "Aa"
        )
        append(layer)
    }

    func fillSelectedEmptyOverlayOrAdd(image: UIImage, prompt: String) {
        if let selected = selectedLayer,
           selected.kind == .aiOverlay,
           selected.image == nil {
            recordUndo()
            selected.image = image
            selected.sourcePrompt = prompt
        } else {
            addAIOverlay(image: image, prompt: prompt)
        }
    }

    // MARK: - Background

    func setBackgroundAI(image: UIImage, prompt: String) {
        recordUndo()
        background.kind = .ai
        background.aiImage = image
        background.aiPrompt = prompt
    }

    // MARK: - Layer mutations

    func remove(_ layer: Layer) {
        recordUndo()
        layers.removeAll { $0.id == layer.id }
        if selectedLayerID == layer.id {
            selectedLayerID = layers.last?.id
        }
    }

    func duplicate(_ layer: Layer) {
        recordUndo()
        let copy = Layer(snapshot: layer.snapshot())
        // New identity for the copy
        let renamed = Layer(
            id: UUID(),
            kind: copy.kind,
            name: copy.name + " copy",
            image: copy.image,
            sourcePrompt: copy.sourcePrompt,
            symbolName: copy.symbolName,
            emoji: copy.emoji,
            text: copy.text,
            fontWeight: copy.fontWeight,
            tintColor: copy.tintColor
        )
        renamed.offset = copy.offset
        renamed.scale = copy.scale
        renamed.rotation = copy.rotation
        renamed.opacity = copy.opacity
        renamed.shadowOpacity = copy.shadowOpacity
        renamed.shadowRadius = copy.shadowRadius
        renamed.shadowOffsetX = copy.shadowOffsetX
        renamed.shadowOffsetY = copy.shadowOffsetY

        if let idx = layers.firstIndex(where: { $0.id == layer.id }) {
            layers.insert(renamed, at: idx + 1)
        } else {
            layers.append(renamed)
        }
        selectedLayerID = renamed.id
    }

    func move(from source: IndexSet, to destination: Int) {
        recordUndo()
        layers.move(fromOffsets: source, toOffset: destination)
    }

    func toggleVisibility(_ layer: Layer) {
        recordUndo()
        layer.isHidden.toggle()
    }

    func resetTransform(_ layer: Layer) {
        recordUndo()
        layer.offset = .zero
        layer.scale = 1.0
        layer.rotation = .zero
        layer.opacity = 1.0
        layer.shadowOpacity = 0
        layer.shadowRadius = 0.04
        layer.shadowOffsetX = 0
        layer.shadowOffsetY = 0.02
    }
}
