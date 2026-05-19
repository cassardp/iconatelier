import SwiftUI
import UIKit

enum LayerKind: String, Equatable, CaseIterable, Codable {
    case image
    case text
    case parametricShape
}

enum LayerFontWeight: String, CaseIterable, Codable {
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

enum BorderPosition: String, CaseIterable, Codable {
    case inner
    case center
    case outer

    var displayName: String {
        switch self {
        case .inner:  return "Inside"
        case .center: return "Center"
        case .outer:  return "Outside"
        }
    }
}

enum LayerLineCap: String, CaseIterable, Codable {
    case butt
    case round
    case square

    var displayName: String {
        switch self {
        case .butt:   return "Butt"
        case .round:  return "Round"
        case .square: return "Square"
        }
    }

    var cgLineCap: CGLineCap {
        switch self {
        case .butt:   return .butt
        case .round:  return .round
        case .square: return .square
        }
    }
}

enum LayerFontDesign: String, CaseIterable, Codable {
    case `default`
    case serif
    case rounded
    case monospaced

    var swiftUI: Font.Design {
        switch self {
        case .default:    return .default
        case .serif:      return .serif
        case .rounded:    return .rounded
        case .monospaced: return .monospaced
        }
    }

    var displayName: String {
        switch self {
        case .default:    return "System"
        case .serif:      return "Serif"
        case .rounded:    return "Rounded"
        case .monospaced: return "Mono"
        }
    }
}

@Observable
final class Layer: Codable, Identifiable {
    var uuid: UUID = UUID()
    var name: String = ""
    var kind: LayerKind = .image

    var imagePNG: Data? {
        didSet { imagePNGDirty = true }
    }

    @ObservationIgnored
    var imagePNGDirty: Bool = true

    var text: String = "Aa"
    var fontWeight: LayerFontWeight = .bold
    var fontDesign: LayerFontDesign = .rounded

    var storedTintColor: StoredColor = StoredColor.white

    var storedFillPaint: Paint?

    var shapeSpec: ShapeSpec?

    var cornerRadius: Double = 0
    var borderWidth: Double = 0
    var storedBorderColor: StoredColor = StoredColor.black
    var borderPosition: BorderPosition = .center
    var fillEnabled: Bool = true
    var lineCap: LayerLineCap = .round

    var offsetW: Double = 0
    var offsetH: Double = 0
    var scaleValue: Double = 1.0
    var rotationRadians: Double = 0
    var opacity: Double = 1.0

    var shadowOpacity: Double = 0
    var shadowRadius: Double = 0.04
    var shadowOffsetX: Double = 0
    var shadowOffsetY: Double = 0.02
    var storedShadowColor: StoredColor = StoredColor.black

    var isLocked: Bool = false
    var isFlippedHorizontally: Bool = false
    var isFlippedVertically: Bool = false

    var id: UUID { uuid }

    init(
        uuid: UUID = UUID(),
        kind: LayerKind,
        name: String,
        image: UIImage? = nil,
        text: String = "Aa",
        fontWeight: LayerFontWeight = .bold,
        fontDesign: LayerFontDesign = .rounded,
        tintColor: Color = .white,
        shapeSpec: ShapeSpec? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.kind = kind
        self.imagePNG = image?.pngData()
        self.text = text
        self.fontWeight = fontWeight
        self.fontDesign = fontDesign
        self.storedTintColor = StoredColor(tintColor)
        self.shapeSpec = shapeSpec
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case uuid, name
        case kind = "kindRaw"
        case text
        case fontWeight = "fontWeightRaw"
        case fontDesign = "fontDesignRaw"
        case storedTintColor, storedFillPaint, shapeSpec
        case cornerRadius, borderWidth, storedBorderColor
        case borderPosition = "borderPositionRaw"
        case fillEnabled
        case lineCap = "lineCapRaw"
        case offsetW, offsetH, scaleValue, rotationRadians, opacity
        case shadowOpacity, shadowRadius, shadowOffsetX, shadowOffsetY, storedShadowColor
        case isLocked, isFlippedHorizontally, isFlippedVertically
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""

        kind = (try? c.decodeIfPresent(LayerKind.self, forKey: .kind)) ?? .image
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? "Aa"
        fontWeight = (try? c.decodeIfPresent(LayerFontWeight.self, forKey: .fontWeight)) ?? .bold
        fontDesign = (try? c.decodeIfPresent(LayerFontDesign.self, forKey: .fontDesign)) ?? .rounded
        storedTintColor = try c.decodeIfPresent(StoredColor.self, forKey: .storedTintColor) ?? StoredColor.white
        storedFillPaint = try c.decodeIfPresent(Paint.self, forKey: .storedFillPaint)
        shapeSpec = try c.decodeIfPresent(ShapeSpec.self, forKey: .shapeSpec)
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0
        borderWidth = try c.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 0
        storedBorderColor = try c.decodeIfPresent(StoredColor.self, forKey: .storedBorderColor) ?? StoredColor.black
        borderPosition = (try? c.decodeIfPresent(BorderPosition.self, forKey: .borderPosition)) ?? .center
        fillEnabled = try c.decodeIfPresent(Bool.self, forKey: .fillEnabled) ?? true
        lineCap = (try? c.decodeIfPresent(LayerLineCap.self, forKey: .lineCap)) ?? .round
        offsetW = try c.decodeIfPresent(Double.self, forKey: .offsetW) ?? 0
        offsetH = try c.decodeIfPresent(Double.self, forKey: .offsetH) ?? 0
        scaleValue = try c.decodeIfPresent(Double.self, forKey: .scaleValue) ?? 1.0
        rotationRadians = try c.decodeIfPresent(Double.self, forKey: .rotationRadians) ?? 0
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        shadowOpacity = try c.decodeIfPresent(Double.self, forKey: .shadowOpacity) ?? 0
        shadowRadius = try c.decodeIfPresent(Double.self, forKey: .shadowRadius) ?? 0.04
        shadowOffsetX = try c.decodeIfPresent(Double.self, forKey: .shadowOffsetX) ?? 0
        shadowOffsetY = try c.decodeIfPresent(Double.self, forKey: .shadowOffsetY) ?? 0.02
        storedShadowColor = try c.decodeIfPresent(StoredColor.self, forKey: .storedShadowColor) ?? StoredColor.black
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isFlippedHorizontally = try c.decodeIfPresent(Bool.self, forKey: .isFlippedHorizontally) ?? false
        isFlippedVertically = try c.decodeIfPresent(Bool.self, forKey: .isFlippedVertically) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uuid, forKey: .uuid)
        try c.encode(name, forKey: .name)
        try c.encode(kind, forKey: .kind)
        try c.encode(text, forKey: .text)
        try c.encode(fontWeight, forKey: .fontWeight)
        try c.encode(fontDesign, forKey: .fontDesign)
        try c.encode(storedTintColor, forKey: .storedTintColor)
        try c.encodeIfPresent(storedFillPaint, forKey: .storedFillPaint)
        try c.encodeIfPresent(shapeSpec, forKey: .shapeSpec)
        try c.encode(cornerRadius, forKey: .cornerRadius)
        try c.encode(borderWidth, forKey: .borderWidth)
        try c.encode(storedBorderColor, forKey: .storedBorderColor)
        try c.encode(borderPosition, forKey: .borderPosition)
        try c.encode(fillEnabled, forKey: .fillEnabled)
        try c.encode(lineCap, forKey: .lineCap)
        try c.encode(offsetW, forKey: .offsetW)
        try c.encode(offsetH, forKey: .offsetH)
        try c.encode(scaleValue, forKey: .scaleValue)
        try c.encode(rotationRadians, forKey: .rotationRadians)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(shadowOpacity, forKey: .shadowOpacity)
        try c.encode(shadowRadius, forKey: .shadowRadius)
        try c.encode(shadowOffsetX, forKey: .shadowOffsetX)
        try c.encode(shadowOffsetY, forKey: .shadowOffsetY)
        try c.encode(storedShadowColor, forKey: .storedShadowColor)
        try c.encode(isLocked, forKey: .isLocked)
        try c.encode(isFlippedHorizontally, forKey: .isFlippedHorizontally)
        try c.encode(isFlippedVertically, forKey: .isFlippedVertically)
    }

    // MARK: - Bridged properties

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

    var shadowColor: Color {
        get { storedShadowColor.color }
        set { storedShadowColor = StoredColor(newValue) }
    }

    var borderColor: Color {
        get { storedBorderColor.color }
        set { storedBorderColor = StoredColor(newValue) }
    }

    var fillPaint: Paint {
        get { storedFillPaint ?? .solid(tintColor) }
        set {
            storedFillPaint = newValue
            if newValue.kind == .solid {
                storedTintColor = newValue.solidColor
            }
        }
    }
}

// MARK: - Snapshot for undo

struct LayerSnapshot {
    let uuid: UUID
    let kind: LayerKind
    let name: String
    let imagePNG: Data?
    let text: String
    let fontWeight: LayerFontWeight
    let fontDesign: LayerFontDesign
    let tintColor: StoredColor
    let storedFillPaint: Paint?
    let shapeSpec: ShapeSpec?
    let cornerRadius: Double
    let borderWidth: Double
    let borderColor: StoredColor
    let borderPosition: BorderPosition
    let fillEnabled: Bool
    let lineCap: LayerLineCap
    let offsetW: Double
    let offsetH: Double
    let scaleValue: Double
    let rotationRadians: Double
    let opacity: Double
    let shadowOpacity: Double
    let shadowRadius: Double
    let shadowOffsetX: Double
    let shadowOffsetY: Double
    let shadowColor: StoredColor
    let isLocked: Bool
    let isFlippedHorizontally: Bool
    let isFlippedVertically: Bool
}

extension Layer {
    func snapshot() -> LayerSnapshot {
        LayerSnapshot(
            uuid: uuid,
            kind: kind,
            name: name,
            imagePNG: imagePNG,
            text: text,
            fontWeight: fontWeight,
            fontDesign: fontDesign,
            tintColor: storedTintColor,
            storedFillPaint: storedFillPaint,
            shapeSpec: shapeSpec,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            borderColor: storedBorderColor,
            borderPosition: borderPosition,
            fillEnabled: fillEnabled,
            lineCap: lineCap,
            offsetW: offsetW,
            offsetH: offsetH,
            scaleValue: scaleValue,
            rotationRadians: rotationRadians,
            opacity: opacity,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffsetX: shadowOffsetX,
            shadowOffsetY: shadowOffsetY,
            shadowColor: storedShadowColor,
            isLocked: isLocked,
            isFlippedHorizontally: isFlippedHorizontally,
            isFlippedVertically: isFlippedVertically
        )
    }

    func apply(_ s: LayerSnapshot) {
        kind = s.kind
        name = s.name
        imagePNG = s.imagePNG
        text = s.text
        fontWeight = s.fontWeight
        fontDesign = s.fontDesign
        storedTintColor = s.tintColor
        storedFillPaint = s.storedFillPaint
        shapeSpec = s.shapeSpec
        cornerRadius = s.cornerRadius
        borderWidth = s.borderWidth
        storedBorderColor = s.borderColor
        borderPosition = s.borderPosition
        fillEnabled = s.fillEnabled
        lineCap = s.lineCap
        offsetW = s.offsetW
        offsetH = s.offsetH
        scaleValue = s.scaleValue
        rotationRadians = s.rotationRadians
        opacity = s.opacity
        shadowOpacity = s.shadowOpacity
        shadowRadius = s.shadowRadius
        shadowOffsetX = s.shadowOffsetX
        shadowOffsetY = s.shadowOffsetY
        storedShadowColor = s.shadowColor
        isLocked = s.isLocked
        isFlippedHorizontally = s.isFlippedHorizontally
        isFlippedVertically = s.isFlippedVertically
    }
}
