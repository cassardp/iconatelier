import SwiftUI
import SwiftData
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

@Model
final class Layer {
    var uuid: UUID = UUID()
    var name: String = ""
    var kindRaw: String = LayerKind.aiOverlay.rawValue
    var orderIndex: Int = 0

    @Attribute(.externalStorage) var imagePNG: Data?
    var sourcePrompt: String?

    var symbolName: String = "star.fill"
    var emoji: String = "✨"
    var text: String = "Aa"
    var fontWeightRaw: String = LayerFontWeight.bold.rawValue

    var storedTintColor: StoredColor = StoredColor.white

    var offsetW: Double = 0
    var offsetH: Double = 0
    var scaleValue: Double = 1.0
    var rotationRadians: Double = 0
    var opacity: Double = 1.0

    var shadowOpacity: Double = 0
    var shadowRadius: Double = 0.04
    var shadowOffsetX: Double = 0
    var shadowOffsetY: Double = 0.02

    var isHidden: Bool = false
    var isLocked: Bool = false

    var project: IconProject?

    init(
        uuid: UUID = UUID(),
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
        self.uuid = uuid
        self.name = name
        self.kindRaw = kind.rawValue
        self.imagePNG = image?.pngData()
        self.sourcePrompt = sourcePrompt
        self.symbolName = symbolName
        self.emoji = emoji
        self.text = text
        self.fontWeightRaw = fontWeight.rawValue
        self.storedTintColor = StoredColor(tintColor)
    }

    // MARK: - Bridged properties

    var kind: LayerKind {
        get { LayerKind(rawValue: kindRaw) ?? .aiOverlay }
        set { kindRaw = newValue.rawValue }
    }

    var fontWeight: LayerFontWeight {
        get { LayerFontWeight(rawValue: fontWeightRaw) ?? .bold }
        set { fontWeightRaw = newValue.rawValue }
    }

    var image: UIImage? {
        get { imagePNG.flatMap { UIImage(data: $0) } }
        set { imagePNG = newValue?.pngData() }
    }

    var tintColor: Color {
        get { storedTintColor.color }
        set { storedTintColor = StoredColor(newValue) }
    }

    var offset: CGSize {
        get { CGSize(width: offsetW, height: offsetH) }
        set { offsetW = Double(newValue.width); offsetH = Double(newValue.height) }
    }

    var scale: CGFloat {
        get { CGFloat(scaleValue) }
        set { scaleValue = Double(newValue) }
    }

    var rotation: Angle {
        get { .radians(rotationRadians) }
        set { rotationRadians = newValue.radians }
    }
}

// MARK: - Snapshot for undo

struct LayerSnapshot {
    let uuid: UUID
    let kind: LayerKind
    let name: String
    let imagePNG: Data?
    let sourcePrompt: String?
    let symbolName: String
    let emoji: String
    let text: String
    let fontWeight: LayerFontWeight
    let tintColor: StoredColor
    let offsetW: Double
    let offsetH: Double
    let scaleValue: Double
    let rotationRadians: Double
    let opacity: Double
    let shadowOpacity: Double
    let shadowRadius: Double
    let shadowOffsetX: Double
    let shadowOffsetY: Double
    let isHidden: Bool
    let isLocked: Bool
    let orderIndex: Int
}

extension Layer {
    func snapshot() -> LayerSnapshot {
        LayerSnapshot(
            uuid: uuid,
            kind: kind,
            name: name,
            imagePNG: imagePNG,
            sourcePrompt: sourcePrompt,
            symbolName: symbolName,
            emoji: emoji,
            text: text,
            fontWeight: fontWeight,
            tintColor: storedTintColor,
            offsetW: offsetW,
            offsetH: offsetH,
            scaleValue: scaleValue,
            rotationRadians: rotationRadians,
            opacity: opacity,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffsetX: shadowOffsetX,
            shadowOffsetY: shadowOffsetY,
            isHidden: isHidden,
            isLocked: isLocked,
            orderIndex: orderIndex
        )
    }

    func apply(_ s: LayerSnapshot) {
        kindRaw = s.kind.rawValue
        name = s.name
        imagePNG = s.imagePNG
        sourcePrompt = s.sourcePrompt
        symbolName = s.symbolName
        emoji = s.emoji
        text = s.text
        fontWeightRaw = s.fontWeight.rawValue
        storedTintColor = s.tintColor
        offsetW = s.offsetW
        offsetH = s.offsetH
        scaleValue = s.scaleValue
        rotationRadians = s.rotationRadians
        opacity = s.opacity
        shadowOpacity = s.shadowOpacity
        shadowRadius = s.shadowRadius
        shadowOffsetX = s.shadowOffsetX
        shadowOffsetY = s.shadowOffsetY
        isHidden = s.isHidden
        isLocked = s.isLocked
        orderIndex = s.orderIndex
    }
}
