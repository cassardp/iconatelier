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

    private enum CodingKeys: String, CodingKey {
        case type, params
    }

    private enum EffectType: String, Codable {
        case dropShadow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EffectType.self, forKey: .type)
        switch type {
        case .dropShadow:
            let params = try container.decode(DropShadow.self, forKey: .params)
            self = .dropShadow(params)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .dropShadow(s):
            try container.encode(EffectType.dropShadow, forKey: .type)
            try container.encode(s, forKey: .params)
        }
    }
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
