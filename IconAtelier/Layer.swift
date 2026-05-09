import SwiftUI
import UIKit

enum LayerKind: Equatable {
    case aiBackground
    case aiOverlay
}

@MainActor
@Observable
final class Layer: Identifiable {
    let id = UUID()
    var name: String
    var kind: LayerKind
    var image: UIImage?
    var sourcePrompt: String?

    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var opacity: Double = 1.0

    var isHidden: Bool = false
    var isLocked: Bool = false

    init(
        kind: LayerKind,
        name: String,
        image: UIImage? = nil,
        sourcePrompt: String? = nil
    ) {
        self.kind = kind
        self.name = name
        self.image = image
        self.sourcePrompt = sourcePrompt
    }

    var fillsCanvas: Bool { kind == .aiBackground }
}
