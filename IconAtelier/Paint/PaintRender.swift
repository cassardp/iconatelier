import SwiftUI

@ViewBuilder
func PaintFill<S: Shape>(_ shape: S, paint: Paint, side: CGFloat) -> some View {
    switch paint.kind {
    case .solid:
        shape.fill(paint.solidColor.color)
    case .linearGradient:
        shape.fill(
            LinearGradient(
                colors: paint.gradientColors.map { $0.color },
                startPoint: paint.linearStart.unitPoint,
                endPoint: paint.linearEnd.unitPoint
            )
        )
    case .radialGradient:
        shape.fill(
            RadialGradient(
                colors: paint.gradientColors.map { $0.color },
                center: paint.gradientCenter.unitPoint,
                startRadius: 0,
                endRadius: side * CGFloat(paint.radialSpread)
            )
        )
    case .meshGradient:
        let colors9 = paint.meshColors.map { $0.color }
        let colors25 = Paint.mesh25Colors(from: colors9)

        let angle = paint.meshRotationDegrees
        let rad = angle * .pi / 180
        let cover = abs(cos(rad)) + abs(sin(rad))
        MeshGradient(
            width: 5,
            height: 5,
            points: Paint.mesh25Points(corners: paint.meshCornerPoints),
            colors: colors25
        )
        .scaleEffect(cover)
        .rotationEffect(.degrees(angle))
        .frame(width: side, height: side)
        .mask { shape }
    }
}
