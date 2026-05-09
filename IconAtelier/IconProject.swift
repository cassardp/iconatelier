import SwiftUI
import UIKit

@MainActor
@Observable
final class IconProject {
    var layers: [Layer] = []
    var selectedLayerID: Layer.ID?

    var isGenerating: Bool = false
    var lastError: String?

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

    func add(_ layer: Layer) {
        if layer.kind == .aiBackground {
            layers.insert(layer, at: 0)
        } else {
            layers.append(layer)
        }
        selectedLayerID = layer.id
    }

    func remove(_ layer: Layer) {
        layers.removeAll { $0.id == layer.id }
        if selectedLayerID == layer.id {
            selectedLayerID = layers.last?.id
        }
    }

    func duplicate(_ layer: Layer) {
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
        layers.move(fromOffsets: source, toOffset: destination)
    }

    func setOrReplaceBackground(image: UIImage, prompt: String) {
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
            add(bg)
        }
    }

    func addOverlay(image: UIImage, prompt: String) {
        let index = overlays.count + 1
        let name = index == 1 ? "Overlay" : "Overlay \(index)"
        let layer = Layer(
            kind: .aiOverlay,
            name: name,
            image: image,
            sourcePrompt: prompt
        )
        add(layer)
    }
}
