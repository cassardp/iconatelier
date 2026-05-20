import SwiftUI

enum LayerGeometry {

    static func baseUnitFraction(for kind: LayerKind) -> CGFloat {
        switch kind {
        case .image: return 0.7
        case .text: return 0.6
        case .parametricShape: return 0.5
        }
    }

    static func frameSide(for layer: Layer, canvasSide: CGFloat) -> CGFloat {
        canvasSide * baseUnitFraction(for: layer.kind) * layer.scale
    }
}
