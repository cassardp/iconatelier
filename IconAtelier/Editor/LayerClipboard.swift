import UIKit

enum LayerClipboard {
    static let pasteboardType = "com.iconatelier.layers.v1"

    private struct Payload: Codable {
        struct Item: Codable {
            let layer: Layer
            let imagePNG: Data?
        }
        let items: [Item]
    }

    static func copy(_ layers: [Layer]) {
        guard !layers.isEmpty else { return }
        let payload = Payload(items: layers.map { Payload.Item(layer: $0, imagePNG: $0.imagePNG) })
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UIPasteboard.general.setData(data, forPasteboardType: pasteboardType)
    }

    static func paste() -> [Layer]? {
        guard let data = UIPasteboard.general.data(forPasteboardType: pasteboardType),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            return nil
        }
        return payload.items.map { item in
            item.layer.imagePNG = item.imagePNG
            return item.layer
        }
    }

    static var hasContent: Bool {
        UIPasteboard.general.contains(pasteboardTypes: [pasteboardType])
    }
}
