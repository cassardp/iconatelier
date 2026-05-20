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

    init(enabled: Bool = true, paint: Paint = .solid(.white)) {
        self.enabled = enabled
        self.paint = paint
    }
}

struct LayerBorder: Codable, Equatable, Sendable {
    var width: Double = 0
    var color: StoredColor = .black
    var position: BorderPosition = .center
    var lineCap: LayerLineCap = .round
}

struct ImageContent: Codable, Equatable {
    var imagePNG: Data?
    var tint: StoredColor = .white
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
