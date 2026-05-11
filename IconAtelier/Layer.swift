import SwiftUI
import UIKit

enum LayerKind: Equatable {
    case aiBackground
    case aiOverlay
}

@MainActor
@Observable
final class Layer: Identifiable {
    let id: UUID
    var name: String
    var kind: LayerKind
    var image: UIImage?
    var sourcePrompt: String?

    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var opacity: Double = 1.0

    var shadowOpacity: Double = 0
    var shadowRadius: CGFloat = 0.04
    var shadowOffsetX: CGFloat = 0
    var shadowOffsetY: CGFloat = 0.02

    var isHidden: Bool = false
    var isLocked: Bool = false

    init(
        id: UUID = UUID(),
        kind: LayerKind,
        name: String,
        image: UIImage? = nil,
        sourcePrompt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.image = image
        self.sourcePrompt = sourcePrompt
    }

    var fillsCanvas: Bool { kind == .aiBackground }
}

struct LayerSnapshot {
    let id: UUID
    let kind: LayerKind
    let name: String
    let image: UIImage?
    let sourcePrompt: String?
    let offset: CGSize
    let scale: CGFloat
    let rotation: Angle
    let opacity: Double
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowOffsetX: CGFloat
    let shadowOffsetY: CGFloat
    let isHidden: Bool
    let isLocked: Bool
}

extension Layer {
    func snapshot() -> LayerSnapshot {
        LayerSnapshot(
            id: id,
            kind: kind,
            name: name,
            image: image,
            sourcePrompt: sourcePrompt,
            offset: offset,
            scale: scale,
            rotation: rotation,
            opacity: opacity,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffsetX: shadowOffsetX,
            shadowOffsetY: shadowOffsetY,
            isHidden: isHidden,
            isLocked: isLocked
        )
    }

    convenience init(snapshot: LayerSnapshot) {
        self.init(
            id: snapshot.id,
            kind: snapshot.kind,
            name: snapshot.name,
            image: snapshot.image,
            sourcePrompt: snapshot.sourcePrompt
        )
        self.offset = snapshot.offset
        self.scale = snapshot.scale
        self.rotation = snapshot.rotation
        self.opacity = snapshot.opacity
        self.shadowOpacity = snapshot.shadowOpacity
        self.shadowRadius = snapshot.shadowRadius
        self.shadowOffsetX = snapshot.shadowOffsetX
        self.shadowOffsetY = snapshot.shadowOffsetY
        self.isHidden = snapshot.isHidden
        self.isLocked = snapshot.isLocked
    }
}
