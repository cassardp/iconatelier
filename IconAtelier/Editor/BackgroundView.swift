import SwiftUI

struct BackgroundView: View {
    let background: Background
    let side: CGFloat

    var body: some View {
        Group {
            switch background.kind {
            case .solid:
                background.solidColor
            case .linearGradient:
                LinearGradient(
                    colors: background.gradientColors,
                    startPoint: background.linearStart,
                    endPoint: background.linearEnd
                )
            case .radialGradient:
                RadialGradient(
                    colors: background.gradientColors,
                    center: background.gradientCenter,
                    startRadius: 0,
                    endRadius: side * CGFloat(background.radialSpread)
                )
            case .meshGradient:
                meshView
            }
        }
        .frame(width: side, height: side)
    }

    @ViewBuilder
    private var meshView: some View {
        if #available(iOS 18.0, *) {
            let angle = background.meshRotationDegrees
            let rad = angle * .pi / 180
            let scale = abs(cos(rad)) + abs(sin(rad))
            MeshGradient(
                width: 5,
                height: 5,
                points: Paint.mesh25Points(corners: background.storedMeshCornerPoints),
                colors: Paint.mesh25Colors(from: background.meshColors)
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(angle))
        } else {
            LinearGradient(
                colors: [background.meshColors.first ?? .iaPurple,
                         background.meshColors.last ?? .iaOrange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
