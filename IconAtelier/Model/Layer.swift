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
    var kindRaw: String = LayerKind.image.rawValue
    var orderIndex: Int = 0

    /// In-memory PNG payload. Persisted by `ProjectStore` to a sibling
    /// `layer-{uuid}.png` file rather than serialized inline in the JSON
    /// (excluded from `CodingKeys`).
    var imagePNG: Data? {
        didSet { imagePNGDirty = true }
    }

    /// Set every time `imagePNG` is mutated; `ProjectStore.save` uses it to
    /// skip rewriting the layer's PNG sidecar when nothing about the blob
    /// has changed. Defaults to true so freshly-built layers always get a
    /// first write to disk; the store resets it to false right after a
    /// successful write (or after rehydration on load).
    @ObservationIgnored
    var imagePNGDirty: Bool = true

    var text: String = "Aa"
    var fontWeightRaw: String = LayerFontWeight.bold.rawValue
    var fontDesignRaw: String = LayerFontDesign.rounded.rawValue

    var storedTintColor: StoredColor = StoredColor.white

    /// JSON-encoded `Paint` used as the fill for shape and text layers.
    /// `nil` means "fall back to a solid Paint built from `tintColor`" —
    /// keeps freshly-added layers (and pre-Paint records) rendering as
    /// before without forcing a migration step.
    var fillPaintJSON: Data?

    var shapeSpecJSON: Data?

    // Shape-level styling (applies to .parametricShape layers).
    var cornerRadius: Double = 0
    var borderWidth: Double = 0
    var storedBorderColor: StoredColor = StoredColor.black
    var borderPositionRaw: String = BorderPosition.center.rawValue
    var fillEnabled: Bool = true
    var lineCapRaw: String = LayerLineCap.round.rawValue

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

    var isHidden: Bool = false
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
        self.kindRaw = kind.rawValue
        self.imagePNG = image?.pngData()
        self.text = text
        self.fontWeightRaw = fontWeight.rawValue
        self.fontDesignRaw = fontDesign.rawValue
        self.storedTintColor = StoredColor(tintColor)
        self.shapeSpecJSON = shapeSpec.flatMap { try? JSONEncoder().encode($0) }
    }

    // MARK: - Codable
    //
    // `imagePNG` is intentionally excluded from JSON. `ProjectStore` writes
    // it out to a `layer-{uuid}.png` sibling file on save and rehydrates it
    // on load. Keeping blobs out of the JSON keeps `project.json` small
    // enough to inspect by hand.

    private enum CodingKeys: String, CodingKey {
        case uuid, name, kindRaw, orderIndex
        case text, fontWeightRaw, fontDesignRaw
        case storedTintColor, fillPaintJSON, shapeSpecJSON
        case cornerRadius, borderWidth, storedBorderColor, borderPositionRaw
        case fillEnabled, lineCapRaw
        case offsetW, offsetH, scaleValue, rotationRadians, opacity
        case shadowOpacity, shadowRadius, shadowOffsetX, shadowOffsetY, storedShadowColor
        case isHidden, isLocked, isFlippedHorizontally, isFlippedVertically
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        kindRaw = try c.decodeIfPresent(String.self, forKey: .kindRaw) ?? LayerKind.image.rawValue
        orderIndex = try c.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? "Aa"
        fontWeightRaw = try c.decodeIfPresent(String.self, forKey: .fontWeightRaw) ?? LayerFontWeight.bold.rawValue
        fontDesignRaw = try c.decodeIfPresent(String.self, forKey: .fontDesignRaw) ?? LayerFontDesign.rounded.rawValue
        storedTintColor = try c.decodeIfPresent(StoredColor.self, forKey: .storedTintColor) ?? StoredColor.white
        fillPaintJSON = try c.decodeIfPresent(Data.self, forKey: .fillPaintJSON)
        shapeSpecJSON = try c.decodeIfPresent(Data.self, forKey: .shapeSpecJSON)
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0
        borderWidth = try c.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 0
        storedBorderColor = try c.decodeIfPresent(StoredColor.self, forKey: .storedBorderColor) ?? StoredColor.black
        borderPositionRaw = try c.decodeIfPresent(String.self, forKey: .borderPositionRaw) ?? BorderPosition.center.rawValue
        fillEnabled = try c.decodeIfPresent(Bool.self, forKey: .fillEnabled) ?? true
        lineCapRaw = try c.decodeIfPresent(String.self, forKey: .lineCapRaw) ?? LayerLineCap.round.rawValue
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
        isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isFlippedHorizontally = try c.decodeIfPresent(Bool.self, forKey: .isFlippedHorizontally) ?? false
        isFlippedVertically = try c.decodeIfPresent(Bool.self, forKey: .isFlippedVertically) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uuid, forKey: .uuid)
        try c.encode(name, forKey: .name)
        try c.encode(kindRaw, forKey: .kindRaw)
        try c.encode(orderIndex, forKey: .orderIndex)
        try c.encode(text, forKey: .text)
        try c.encode(fontWeightRaw, forKey: .fontWeightRaw)
        try c.encode(fontDesignRaw, forKey: .fontDesignRaw)
        try c.encode(storedTintColor, forKey: .storedTintColor)
        try c.encodeIfPresent(fillPaintJSON, forKey: .fillPaintJSON)
        try c.encodeIfPresent(shapeSpecJSON, forKey: .shapeSpecJSON)
        try c.encode(cornerRadius, forKey: .cornerRadius)
        try c.encode(borderWidth, forKey: .borderWidth)
        try c.encode(storedBorderColor, forKey: .storedBorderColor)
        try c.encode(borderPositionRaw, forKey: .borderPositionRaw)
        try c.encode(fillEnabled, forKey: .fillEnabled)
        try c.encode(lineCapRaw, forKey: .lineCapRaw)
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
        try c.encode(isHidden, forKey: .isHidden)
        try c.encode(isLocked, forKey: .isLocked)
        try c.encode(isFlippedHorizontally, forKey: .isFlippedHorizontally)
        try c.encode(isFlippedVertically, forKey: .isFlippedVertically)
    }

    // MARK: - Bridged properties

    var kind: LayerKind {
        // Fallback to .image if the stored raw value no longer maps to a
        // known case (e.g. legacy "emoji" layers from before the kind was
        // dropped). Keeps the app from crashing on stale projects.
        get { LayerKind(rawValue: kindRaw) ?? .image }
        set { kindRaw = newValue.rawValue }
    }

    var fontWeight: LayerFontWeight {
        get { LayerFontWeight(rawValue: fontWeightRaw)! }
        set { fontWeightRaw = newValue.rawValue }
    }

    var fontDesign: LayerFontDesign {
        get { LayerFontDesign(rawValue: fontDesignRaw)! }
        set { fontDesignRaw = newValue.rawValue }
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

    var shadowColor: Color {
        get { storedShadowColor.color }
        set { storedShadowColor = StoredColor(newValue) }
    }

    var borderColor: Color {
        get { storedBorderColor.color }
        set { storedBorderColor = StoredColor(newValue) }
    }

    var borderPosition: BorderPosition {
        get { BorderPosition(rawValue: borderPositionRaw)! }
        set { borderPositionRaw = newValue.rawValue }
    }

    var lineCap: LayerLineCap {
        get { LayerLineCap(rawValue: lineCapRaw) ?? .round }
        set { lineCapRaw = newValue.rawValue }
    }

    var shapeSpec: ShapeSpec? {
        get {
            guard let data = shapeSpecJSON else { return nil }
            return try? JSONDecoder().decode(ShapeSpec.self, from: data)
        }
        set {
            shapeSpecJSON = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    /// Shape/text fill description. When no Paint has been stored yet,
    /// falls back to a solid Paint built from `tintColor` so the layer
    /// renders identically to its pre-Paint state. The setter clears the
    /// JSON when assigned the "tintColor-equivalent" solid so we don't
    /// drift from the simple-color UI for image layers.
    var fillPaint: Paint {
        get {
            if let data = fillPaintJSON,
               let p = try? JSONDecoder().decode(Paint.self, from: data) {
                return p
            }
            return .solid(tintColor)
        }
        set {
            fillPaintJSON = try? JSONEncoder().encode(newValue)
            // Keep tintColor in sync with the solid case so any code path
            // still reading `tintColor` (image colorMultiply, snapshot
            // hashing, …) reflects the active fill.
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
    let fillPaintJSON: Data?
    let shapeSpecJSON: Data?
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
    let isHidden: Bool
    let isLocked: Bool
    let isFlippedHorizontally: Bool
    let isFlippedVertically: Bool
    let orderIndex: Int
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
            fillPaintJSON: fillPaintJSON,
            shapeSpecJSON: shapeSpecJSON,
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
            isHidden: isHidden,
            isLocked: isLocked,
            isFlippedHorizontally: isFlippedHorizontally,
            isFlippedVertically: isFlippedVertically,
            orderIndex: orderIndex
        )
    }

    func apply(_ s: LayerSnapshot) {
        kindRaw = s.kind.rawValue
        name = s.name
        imagePNG = s.imagePNG
        text = s.text
        fontWeightRaw = s.fontWeight.rawValue
        fontDesignRaw = s.fontDesign.rawValue
        storedTintColor = s.tintColor
        fillPaintJSON = s.fillPaintJSON
        shapeSpecJSON = s.shapeSpecJSON
        cornerRadius = s.cornerRadius
        borderWidth = s.borderWidth
        storedBorderColor = s.borderColor
        borderPositionRaw = s.borderPosition.rawValue
        fillEnabled = s.fillEnabled
        lineCapRaw = s.lineCap.rawValue
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
        isHidden = s.isHidden
        isLocked = s.isLocked
        isFlippedHorizontally = s.isFlippedHorizontally
        isFlippedVertically = s.isFlippedVertically
        orderIndex = s.orderIndex
    }
}
