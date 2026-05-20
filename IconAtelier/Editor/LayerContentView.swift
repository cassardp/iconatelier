import SwiftUI
import UIKit

struct LayerView: View {
    let layer: Layer
    let side: CGFloat
    var transientOffset: CGSize = .zero
    var transientScale: CGFloat = 1.0
    var transientAngle: Angle = .zero
    var includeEffects: Bool = true

    var body: some View {
        let effectiveScale = layer.scale * transientScale
        let effects = includeEffects ? layer.appearance.effects : []
        LayerContentView(layer: layer, side: side, scale: effectiveScale)
            .applying(effects: effects, side: side, scale: effectiveScale)
            .rotationEffect(layer.rotation + transientAngle)
            .opacity(layer.opacity)
            .offset(
                x: layer.offset.width * side + transientOffset.width,
                y: layer.offset.height * side + transientOffset.height
            )
    }
}

struct LayerContentView: View {
    let layer: Layer
    let side: CGFloat
    var scale: CGFloat = 1.0

    var body: some View {
        content
            .scaleEffect(
                x: layer.isFlippedHorizontally ? -1 : 1,
                y: layer.isFlippedVertically ? -1 : 1
            )
    }

    @ViewBuilder
    private var content: some View {
        switch layer.kind {
        case .image:
            let imageSide = side * LayerGeometry.baseUnitFraction(for: .image) * scale
            if let image = layer.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: imageSide, height: imageSide)
                    .colorMultiply(layer.tintColor)
                    .contentShape(Rectangle())
            } else {
                Color.clear
                    .frame(width: imageSide, height: imageSide)
                    .contentShape(Rectangle())
            }
        case .text:
            let textSide = side * LayerGeometry.baseUnitFraction(for: .text) * scale
            let glyphShape = TextGlyphShape(
                text: layer.text,
                weight: layer.fontWeight,
                design: layer.fontDesign
            )
            let renderShape: AnyShape = {
                if let params = layer.shapeSpec?.radialRepeatParams {
                    return AnyShape(RadialRepeat(
                        base: glyphShape,
                        count: params.count,
                        centerHole: params.centerHole,
                        orientation: params.orientation
                    ))
                }
                return AnyShape(glyphShape)
            }()
            let strokeWidth = textSide * CGFloat(layer.borderWidth)
            ZStack {
                if layer.fillEnabled {
                    PaintFill(renderShape, paint: layer.fillPaint, side: textSide)
                }
                if strokeWidth > 0 {
                    borderView(
                        shape: renderShape,
                        width: strokeWidth,
                        color: layer.borderColor,
                        position: layer.borderPosition,
                        lineCap: layer.lineCap.cgLineCap,
                        lineJoin: layer.lineCap.cgLineJoin
                    )
                }
            }
            .frame(width: textSide, height: textSide)
            .contentShape(renderShape)
        case .parametricShape:
            let shapeSide = side * LayerGeometry.baseUnitFraction(for: .parametricShape) * scale
            if let spec = layer.shapeSpec {
                let shape = ShapeRenderer.anyShape(for: spec)
                let strokeWidth = shapeSide * CGFloat(layer.borderWidth)
                ZStack {
                    if layer.fillEnabled {
                        PaintFill(shape, paint: layer.fillPaint, side: shapeSide)
                    }
                    if strokeWidth > 0 {
                        borderView(
                            shape: shape,
                            width: strokeWidth,
                            color: layer.borderColor,
                            position: spec.isOpenPath ? .center : layer.borderPosition,
                            lineCap: layer.lineCap.cgLineCap,
                            lineJoin: layer.lineCap.cgLineJoin
                        )
                    }
                }
                .frame(width: shapeSide, height: shapeSide)
                .contentShape(spec.isOpenPath ? AnyShape(Rectangle()) : shape)
            } else {
                Color.clear
                    .frame(width: shapeSide, height: shapeSide)
                    .contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder
    private func borderView(shape: AnyShape, width: CGFloat, color: Color, position: BorderPosition, lineCap: CGLineCap, lineJoin: CGLineJoin) -> some View {
        switch position {
        case .center:
            shape.stroke(color, style: StrokeStyle(lineWidth: width, lineCap: lineCap, lineJoin: lineJoin))
        case .inner:
            shape.stroke(color, style: StrokeStyle(lineWidth: width * 2, lineCap: lineCap, lineJoin: lineJoin))
                .clipShape(shape)
        case .outer:
            shape.stroke(color, style: StrokeStyle(lineWidth: width * 2, lineCap: lineCap, lineJoin: lineJoin))
                .overlay(shape.fill(.black).blendMode(.destinationOut))
                .compositingGroup()
        }
    }
}
