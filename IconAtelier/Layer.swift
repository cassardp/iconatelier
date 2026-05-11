import SwiftUI
import UIKit

enum LayerKind: String, Equatable, CaseIterable {
    case aiOverlay
    case symbol
    case emoji
    case text
}

enum LayerFontWeight: String, CaseIterable {
    case regular
    case medium
    case semibold
    case bold
    case heavy

    var swiftUI: Font.Weight {
        switch self {
        case .regular:  return .regular
        case .medium:   return .medium
        case .semibold: return .semibold
        case .bold:     return .bold
        case .heavy:    return .heavy
        }
    }
}

@MainActor
@Observable
final class Layer: Identifiable {
    let id: UUID
    var name: String
    var kind: LayerKind

    // AI overlay
    var image: UIImage?
    var sourcePrompt: String?

    // Symbol
    var symbolName: String

    // Emoji
    var emoji: String

    // Text
    var text: String
    var fontWeight: LayerFontWeight

    // Shared appearance (Symbol + Text)
    var tintColor: Color

    // Transform / appearance (all overlay kinds)
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
        sourcePrompt: String? = nil,
        symbolName: String = "star.fill",
        emoji: String = "✨",
        text: String = "Aa",
        fontWeight: LayerFontWeight = .bold,
        tintColor: Color = .white
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.image = image
        self.sourcePrompt = sourcePrompt
        self.symbolName = symbolName
        self.emoji = emoji
        self.text = text
        self.fontWeight = fontWeight
        self.tintColor = tintColor
    }
}

struct LayerSnapshot {
    let id: UUID
    let kind: LayerKind
    let name: String
    let image: UIImage?
    let sourcePrompt: String?
    let symbolName: String
    let emoji: String
    let text: String
    let fontWeight: LayerFontWeight
    let tintColor: Color
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
            symbolName: symbolName,
            emoji: emoji,
            text: text,
            fontWeight: fontWeight,
            tintColor: tintColor,
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

    convenience init(snapshot s: LayerSnapshot) {
        self.init(
            id: s.id,
            kind: s.kind,
            name: s.name,
            image: s.image,
            sourcePrompt: s.sourcePrompt,
            symbolName: s.symbolName,
            emoji: s.emoji,
            text: s.text,
            fontWeight: s.fontWeight,
            tintColor: s.tintColor
        )
        self.offset = s.offset
        self.scale = s.scale
        self.rotation = s.rotation
        self.opacity = s.opacity
        self.shadowOpacity = s.shadowOpacity
        self.shadowRadius = s.shadowRadius
        self.shadowOffsetX = s.shadowOffsetX
        self.shadowOffsetY = s.shadowOffsetY
        self.isHidden = s.isHidden
        self.isLocked = s.isLocked
    }
}
