import SwiftUI
import CoreText
import UIKit

struct TextGlyphShape: Shape {
    let text: String
    let weight: LayerFontWeight
    let design: LayerFontDesign

    var insetFraction: CGFloat = 0.02

    func path(in rect: CGRect) -> Path {
        let trimmed = text
        guard !trimmed.isEmpty else { return Path() }

        let referenceSize: CGFloat = 100
        let font = uiFont(size: referenceSize, weight: weight, design: design)

        let combined = glyphPath(for: trimmed, font: font)
        let glyphBox = combined.boundingBoxOfPath
        guard glyphBox.width > 0, glyphBox.height > 0 else { return Path() }

        let referencePath = glyphPath(for: Self.referenceText, font: font)
        let referenceBox = referencePath.boundingBoxOfPath
        let refWidth = max(referenceBox.width, 1)
        let refHeight = max(referenceBox.height, 1)

        let inset = min(rect.width, rect.height) * insetFraction
        let target = rect.insetBy(dx: inset, dy: inset)
        let scale = min(target.width / refWidth, target.height / refHeight)
        let scaledW = glyphBox.width * scale
        let scaledH = glyphBox.height * scale
        let offsetX = target.midX - scaledW / 2
        let offsetY = target.midY + scaledH / 2

        var transform = CGAffineTransform(translationX: -glyphBox.minX, y: -glyphBox.minY)
            .concatenating(CGAffineTransform(scaleX: scale, y: -scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))

        guard let transformed = combined.copy(using: &transform) else { return Path() }
        return Path(transformed)
    }

    private static let referenceText = "Aa"

    private func glyphPath(for string: String, font: UIFont) -> CGMutablePath {
        let combined = CGMutablePath()
        let attr = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attr)
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        for run in runs {
            let runAttrs = CTRunGetAttributes(run) as NSDictionary
            guard let runFontRef = runAttrs[kCTFontAttributeName as String] else { continue }
            let runFont = runFontRef as! CTFont

            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }

            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, count), &positions)

            for i in 0 ..< count {
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else {
                    continue
                }
                let t = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                combined.addPath(glyphPath, transform: t)
            }
        }
        return combined
    }

    // MARK: - Font helpers

    private func uiFont(
        size: CGFloat,
        weight: LayerFontWeight,
        design: LayerFontDesign
    ) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        if let descriptor = base.fontDescriptor.withDesign(uiDesign(design)) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    private func uiWeight(_ w: LayerFontWeight) -> UIFont.Weight {
        switch w {
        case .regular:  return .regular
        case .medium:   return .medium
        case .semibold: return .semibold
        case .bold:     return .bold
        case .heavy:    return .heavy
        }
    }

    private func uiDesign(_ d: LayerFontDesign) -> UIFontDescriptor.SystemDesign {
        switch d {
        case .default:    return .default
        case .serif:      return .serif
        case .rounded:    return .rounded
        case .monospaced: return .monospaced
        }
    }
}
