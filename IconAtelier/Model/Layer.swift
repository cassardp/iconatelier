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

enum BorderPosition: String, CaseIterable, Codable, Sendable {
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

enum LayerLineCap: String, CaseIterable, Codable, Sendable {
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

    var cgLineJoin: CGLineJoin {
        switch self {
        case .butt:   return .miter
        case .round:  return .round
        case .square: return .miter
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

struct Layer: Codable, Identifiable {
    var uuid: UUID = UUID()
    var name: String = ""
    var transform: LayerTransform = LayerTransform()
    var appearance: LayerAppearance = LayerAppearance()
    var content: LayerContent

    var imagePNGDirty: Bool = true

    var id: UUID { uuid }

    private enum CodingKeys: String, CodingKey {
        case uuid, name, transform, appearance, content
    }

    init(
        uuid: UUID = UUID(),
        name: String,
        transform: LayerTransform = LayerTransform(),
        appearance: LayerAppearance = LayerAppearance(),
        content: LayerContent
    ) {
        self.uuid = uuid
        self.name = name
        self.transform = transform
        self.appearance = appearance
        self.content = content
    }

    static func image(
        uuid: UUID = UUID(),
        name: String,
        image: UIImage? = nil,
        tintColor: Color = .white
    ) -> Layer {
        Layer(
            uuid: uuid,
            name: name,
            content: .image(ImageContent(
                imagePNG: image?.pngData(),
                tint: StoredColor(tintColor)
            ))
        )
    }

    static func text(
        uuid: UUID = UUID(),
        name: String,
        text: String = "Aa",
        fontWeight: LayerFontWeight = .bold,
        fontDesign: LayerFontDesign = .rounded,
        tintColor: Color = .black
    ) -> Layer {
        Layer(
            uuid: uuid,
            name: name,
            content: .text(TextContent(
                text: text,
                fontWeight: fontWeight,
                fontDesign: fontDesign,
                fill: LayerFill(paint: .solid(tintColor))
            ))
        )
    }

    static func shape(
        uuid: UUID = UUID(),
        name: String,
        spec: ShapeSpec,
        tintColor: Color = .white
    ) -> Layer {
        Layer(
            uuid: uuid,
            name: name,
            content: .shape(ShapeContent(
                spec: spec,
                fill: LayerFill(paint: .solid(tintColor))
            ))
        )
    }

    // MARK: - Derived

    var kind: LayerKind {
        switch content {
        case .image: return .image
        case .text:  return .text
        case .shape: return .parametricShape
        }
    }

    // MARK: - Transform bridges

    var offset: CGSize {
        get { CGSize(width: transform.offsetW, height: transform.offsetH) }
        set {
            transform.offsetW = Double(newValue.width)
            transform.offsetH = Double(newValue.height)
        }
    }

    var scale: CGFloat {
        get { CGFloat(transform.scaleValue) }
        set { transform.scaleValue = Double(newValue) }
    }

    var scaleValue: Double {
        get { transform.scaleValue }
        set { transform.scaleValue = newValue }
    }

    var rotation: Angle {
        get { .radians(transform.rotationRadians) }
        set { transform.rotationRadians = newValue.radians }
    }

    var rotationRadians: Double {
        get { transform.rotationRadians }
        set { transform.rotationRadians = newValue }
    }

    var isFlippedHorizontally: Bool {
        get { transform.isFlippedHorizontally }
        set { transform.isFlippedHorizontally = newValue }
    }

    var isFlippedVertically: Bool {
        get { transform.isFlippedVertically }
        set { transform.isFlippedVertically = newValue }
    }

    // MARK: - Appearance bridges

    var opacity: Double {
        get { appearance.opacity }
        set { appearance.opacity = newValue }
    }

    var isLocked: Bool {
        get { appearance.isLocked }
        set { appearance.isLocked = newValue }
    }

    // MARK: - Drop shadow bridges (first .dropShadow effect)

    private var firstDropShadow: DropShadow {
        for effect in appearance.effects {
            if case let .dropShadow(s) = effect { return s }
        }
        return DropShadow()
    }

    private mutating func updateFirstDropShadow(_ block: (inout DropShadow) -> Void) {
        for index in appearance.effects.indices {
            if case var .dropShadow(s) = appearance.effects[index] {
                block(&s)
                appearance.effects[index] = .dropShadow(s)
                return
            }
        }
        var s = DropShadow()
        block(&s)
        appearance.effects.append(.dropShadow(s))
    }

    var shadowOpacity: Double {
        get { firstDropShadow.opacity }
        set { updateFirstDropShadow { $0.opacity = newValue } }
    }

    var shadowRadius: Double {
        get { firstDropShadow.radius }
        set { updateFirstDropShadow { $0.radius = newValue } }
    }

    var shadowOffsetX: Double {
        get { firstDropShadow.offsetX }
        set { updateFirstDropShadow { $0.offsetX = newValue } }
    }

    var shadowOffsetY: Double {
        get { firstDropShadow.offsetY }
        set { updateFirstDropShadow { $0.offsetY = newValue } }
    }

    var shadowColor: Color {
        get { firstDropShadow.color.color }
        set { updateFirstDropShadow { $0.color = StoredColor(newValue) } }
    }

    // MARK: - Content accessors (read)

    var imagePNG: Data? {
        get {
            if case let .image(c) = content { return c.imagePNG }
            return nil
        }
        set { setImagePNG(newValue) }
    }

    var image: UIImage? {
        imagePNG.flatMap { UIImage(data: $0) }
    }

    var tintColor: Color {
        get {
            switch content {
            case let .image(c): return c.tint.color
            case let .text(c):  return c.fill.paint.solidColor.color
            case let .shape(c): return c.fill.paint.solidColor.color
            }
        }
        set {
            switch content {
            case var .image(c):
                c.tint = StoredColor(newValue)
                content = .image(c)
            case var .text(c):
                c.fill.paint = .solid(newValue)
                content = .text(c)
            case var .shape(c):
                c.fill.paint = .solid(newValue)
                content = .shape(c)
            }
        }
    }

    var text: String {
        get { if case let .text(c) = content { return c.text } else { return "" } }
        set {
            guard case var .text(c) = content else { return }
            c.text = newValue
            content = .text(c)
        }
    }

    var fontWeight: LayerFontWeight {
        get { if case let .text(c) = content { return c.fontWeight } else { return .bold } }
        set {
            guard case var .text(c) = content else { return }
            c.fontWeight = newValue
            content = .text(c)
        }
    }

    var fontDesign: LayerFontDesign {
        get { if case let .text(c) = content { return c.fontDesign } else { return .rounded } }
        set {
            guard case var .text(c) = content else { return }
            c.fontDesign = newValue
            content = .text(c)
        }
    }

    var shapeSpec: ShapeSpec? {
        get {
            if case let .shape(c) = content { return c.spec }
            return nil
        }
        set {
            guard case var .shape(c) = content, let spec = newValue else { return }
            c.spec = spec
            content = .shape(c)
        }
    }

    var radialRepeatParams: RadialRepeatParams? {
        get {
            switch content {
            case let .text(c):  return c.radialRepeat
            case let .shape(c): return c.spec.radialRepeatParams
            case .image:        return nil
            }
        }
        set {
            switch content {
            case var .text(c):
                c.radialRepeat = newValue
                content = .text(c)
            case var .shape(c):
                if let params = newValue {
                    c.spec = c.spec.wrappingInRadialRepeat(params)
                } else {
                    c.spec = c.spec.unwrapped
                }
                content = .shape(c)
            case .image: break
            }
        }
    }

    // Fill/border accessors — apply only to text + shape; no-op for image.
    var fillEnabled: Bool {
        get {
            switch content {
            case let .text(c):  return c.fill.enabled
            case let .shape(c): return c.fill.enabled
            case .image:        return false
            }
        }
        set {
            switch content {
            case var .text(c):
                c.fill.enabled = newValue
                content = .text(c)
            case var .shape(c):
                c.fill.enabled = newValue
                content = .shape(c)
            case .image: break
            }
        }
    }

    var fillPaint: Paint {
        get {
            switch content {
            case let .text(c):  return c.fill.paint
            case let .shape(c): return c.fill.paint
            case let .image(c): return .solid(c.tint.color)
            }
        }
        set {
            switch content {
            case var .text(c):
                c.fill.paint = newValue
                content = .text(c)
            case var .shape(c):
                c.fill.paint = newValue
                content = .shape(c)
            case var .image(c):
                if newValue.kind == .solid {
                    c.tint = newValue.solidColor
                    content = .image(c)
                }
            }
        }
    }

    var storedFillPaint: Paint? {
        get {
            switch content {
            case let .text(c):  return c.fill.paint
            case let .shape(c): return c.fill.paint
            case .image:        return nil
            }
        }
        set {
            guard let paint = newValue else { return }
            fillPaint = paint
        }
    }

    var borderWidth: Double {
        get {
            switch content {
            case let .text(c):  return c.border.width
            case let .shape(c): return c.border.width
            case .image:        return 0
            }
        }
        set {
            switch content {
            case var .text(c):
                c.border.width = newValue
                content = .text(c)
            case var .shape(c):
                c.border.width = newValue
                content = .shape(c)
            case .image: break
            }
        }
    }

    var borderColor: Color {
        get {
            switch content {
            case let .text(c):  return c.border.color.color
            case let .shape(c): return c.border.color.color
            case .image:        return .black
            }
        }
        set {
            let stored = StoredColor(newValue)
            switch content {
            case var .text(c):
                c.border.color = stored
                content = .text(c)
            case var .shape(c):
                c.border.color = stored
                content = .shape(c)
            case .image: break
            }
        }
    }

    var borderPosition: BorderPosition {
        get {
            switch content {
            case let .text(c):  return c.border.position
            case let .shape(c): return c.border.position
            case .image:        return .center
            }
        }
        set {
            switch content {
            case var .text(c):
                c.border.position = newValue
                content = .text(c)
            case var .shape(c):
                c.border.position = newValue
                content = .shape(c)
            case .image: break
            }
        }
    }

    var lineCap: LayerLineCap {
        get {
            switch content {
            case let .text(c):  return c.border.lineCap
            case let .shape(c): return c.border.lineCap
            case .image:        return .round
            }
        }
        set {
            switch content {
            case var .text(c):
                c.border.lineCap = newValue
                content = .text(c)
            case var .shape(c):
                c.border.lineCap = newValue
                content = .shape(c)
            case .image: break
            }
        }
    }

    // MARK: - Content mutations

    mutating func setImagePNG(_ data: Data?) {
        guard case var .image(c) = content else { return }
        c.imagePNG = data
        content = .image(c)
        imagePNGDirty = true
    }

    mutating func setShapeSpec(_ spec: ShapeSpec?) {
        guard case var .shape(c) = content else { return }
        if let spec {
            c.spec = spec
            content = .shape(c)
        }
    }
}
