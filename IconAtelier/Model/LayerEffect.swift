import SwiftUI

struct DropShadow: Codable, Equatable, Sendable {
    var opacity: Double = 0
    var radius: Double = 0.04
    var offsetX: Double = 0
    var offsetY: Double = 0.02
    var color: StoredColor = .black
}

enum LayerEffect: Codable, Equatable, Sendable {
    case dropShadow(DropShadow)
}

extension View {
    func applying(effects: [LayerEffect], side: CGFloat, scale: CGFloat) -> some View {
        effects.reduce(AnyView(self)) { acc, effect in
            switch effect {
            case let .dropShadow(s):
                return AnyView(acc.shadow(
                    color: s.color.color.opacity(s.opacity),
                    radius: side * CGFloat(s.radius) * scale,
                    x: side * CGFloat(s.offsetX) * scale,
                    y: side * CGFloat(s.offsetY) * scale
                ))
            }
        }
    }
}
