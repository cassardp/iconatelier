import SwiftUI

struct LayerTransform: Codable, Equatable, Sendable {
    var offsetW: Double = 0
    var offsetH: Double = 0
    var scaleValue: Double = 1.0
    var rotationRadians: Double = 0
    var isFlippedHorizontally: Bool = false
    var isFlippedVertically: Bool = false
}

struct LayerAppearance: Codable, Equatable, Sendable {
    var opacity: Double = 1.0
    var isLocked: Bool = false
    var effects: [LayerEffect] = []
}

struct LayerFill: Codable, Equatable {
    var enabled: Bool = true
    var paint: Paint
    var opacity: Double = 1.0

    init(enabled: Bool = true, paint: Paint = .solid(.white), opacity: Double = 1.0) {
        self.enabled = enabled
        self.paint = paint
        self.opacity = opacity
    }

    private enum CodingKeys: String, CodingKey { case enabled, paint, opacity }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        paint = try c.decode(Paint.self, forKey: .paint)
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
    }
}

struct LayerBorder: Codable, Equatable, Sendable {
    var width: Double = 0
    var color: StoredColor = .black
    var position: BorderPosition = .center
    var lineCap: LayerLineCap = .round
    var opacity: Double = 1.0

    private enum CodingKeys: String, CodingKey { case width, color, position, lineCap, opacity }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 0
        color = try c.decodeIfPresent(StoredColor.self, forKey: .color) ?? .black
        position = try c.decodeIfPresent(BorderPosition.self, forKey: .position) ?? .center
        lineCap = try c.decodeIfPresent(LayerLineCap.self, forKey: .lineCap) ?? .round
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
    }
}

struct ImageContent: Codable, Equatable {
    var imagePNG: Data?
    var tint: StoredColor = .white
    var opacity: Double = 1.0

    private enum CodingKeys: String, CodingKey { case imagePNG, tint, opacity }

    init(imagePNG: Data? = nil, tint: StoredColor = .white, opacity: Double = 1.0) {
        self.imagePNG = imagePNG
        self.tint = tint
        self.opacity = opacity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imagePNG = try c.decodeIfPresent(Data.self, forKey: .imagePNG)
        tint = try c.decodeIfPresent(StoredColor.self, forKey: .tint) ?? .white
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
    }
}

struct TextContent: Codable, Equatable {
    var text: String = "Aa"
    var fontWeight: LayerFontWeight = .bold
    var fontDesign: LayerFontDesign = .rounded
    var fill: LayerFill
    var border: LayerBorder = LayerBorder()
    var radialRepeat: RadialRepeatParams?

    init(
        text: String = "Aa",
        fontWeight: LayerFontWeight = .bold,
        fontDesign: LayerFontDesign = .rounded,
        fill: LayerFill = LayerFill(paint: .solid(.black)),
        border: LayerBorder = LayerBorder(),
        radialRepeat: RadialRepeatParams? = nil
    ) {
        self.text = text
        self.fontWeight = fontWeight
        self.fontDesign = fontDesign
        self.fill = fill
        self.border = border
        self.radialRepeat = radialRepeat
    }
}

struct ShapeContent: Codable, Equatable {
    var spec: ShapeSpec
    var fill: LayerFill
    var border: LayerBorder

    init(
        spec: ShapeSpec,
        fill: LayerFill = LayerFill(paint: .solid(.white)),
        border: LayerBorder = LayerBorder()
    ) {
        self.spec = spec
        self.fill = fill
        self.border = border
    }
}

enum LayerContent: Codable, Equatable {
    case image(ImageContent)
    case text(TextContent)
    case shape(ShapeContent)
}
