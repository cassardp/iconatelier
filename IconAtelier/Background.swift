import SwiftUI
import UIKit

enum BackgroundKind: String, CaseIterable, Identifiable {
    case solid
    case linearGradient
    case radialGradient
    case meshGradient
    case ai

    var id: String { rawValue }
}

@MainActor
@Observable
final class Background {
    var kind: BackgroundKind

    // Solid
    var solidColor: Color

    // Linear / radial / conic share the color stops.
    var gradientColors: [Color]

    // Linear
    var linearStart: UnitPoint
    var linearEnd: UnitPoint

    // Radial / conic
    var gradientCenter: UnitPoint

    // Mesh — 3x3 fixed grid. Index = row * 3 + col, row 0 = top.
    var meshColors: [Color]

    // AI
    var aiImage: UIImage?
    var aiPrompt: String?

    var isHidden: Bool = false

    init(
        kind: BackgroundKind = .meshGradient,
        solidColor: Color = .iaBlue,
        gradientColors: [Color] = [.iaBlue, .iaPurple],
        linearStart: UnitPoint = .topLeading,
        linearEnd: UnitPoint = .bottomTrailing,
        gradientCenter: UnitPoint = .center,
        meshColors: [Color] = Background.defaultMeshColors,
        aiImage: UIImage? = nil,
        aiPrompt: String? = nil
    ) {
        self.kind = kind
        self.solidColor = solidColor
        self.gradientColors = gradientColors
        self.linearStart = linearStart
        self.linearEnd = linearEnd
        self.gradientCenter = gradientCenter
        self.meshColors = meshColors
        self.aiImage = aiImage
        self.aiPrompt = aiPrompt
    }

    nonisolated static var defaultMeshColors: [Color] {
        let tl: Color = .iaPurple
        let tr: Color = .iaBlue
        let bl: Color = .iaPink
        let br: Color = .iaOrange
        return [
            tl,                            Color.mix(tl, tr, 0.5), tr,
            Color.mix(tl, bl, 0.5), Color.mix(Color.mix(tl, tr, 0.5),
                                              Color.mix(bl, br, 0.5), 0.5),
                                                                    Color.mix(tr, br, 0.5),
            bl,                            Color.mix(bl, br, 0.5), br
        ]
    }
}

// MARK: - Snapshot for undo / persistence

struct BackgroundSnapshot {
    let kind: BackgroundKind
    let solidColor: Color
    let gradientColors: [Color]
    let linearStart: UnitPoint
    let linearEnd: UnitPoint
    let gradientCenter: UnitPoint
    let meshColors: [Color]
    let aiImage: UIImage?
    let aiPrompt: String?
    let isHidden: Bool
}

extension Background {
    func snapshot() -> BackgroundSnapshot {
        BackgroundSnapshot(
            kind: kind,
            solidColor: solidColor,
            gradientColors: gradientColors,
            linearStart: linearStart,
            linearEnd: linearEnd,
            gradientCenter: gradientCenter,
            meshColors: meshColors,
            aiImage: aiImage,
            aiPrompt: aiPrompt,
            isHidden: isHidden
        )
    }

    convenience init(snapshot s: BackgroundSnapshot) {
        self.init(
            kind: s.kind,
            solidColor: s.solidColor,
            gradientColors: s.gradientColors,
            linearStart: s.linearStart,
            linearEnd: s.linearEnd,
            gradientCenter: s.gradientCenter,
            meshColors: s.meshColors,
            aiImage: s.aiImage,
            aiPrompt: s.aiPrompt
        )
        self.isHidden = s.isHidden
    }
}

// MARK: - Color tokens

extension Color {
    nonisolated static let iaBlue = Color(red: 0.0, green: 0.478, blue: 1.0)        // #007AFF
    nonisolated static let iaPurple = Color(red: 0.345, green: 0.337, blue: 0.839)  // #5856D6
    nonisolated static let iaPink = Color(red: 1.0, green: 0.176, blue: 0.333)      // #FF2D55
    nonisolated static let iaOrange = Color(red: 1.0, green: 0.584, blue: 0.0)      // #FF9500

    nonisolated static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ua = UIColor(a)
        let ub = UIColor(b)
        var ra: CGFloat = 0, ga: CGFloat = 0, ba: CGFloat = 0, aa: CGFloat = 0
        var rb: CGFloat = 0, gb: CGFloat = 0, bb: CGFloat = 0, ab: CGFloat = 0
        ua.getRed(&ra, green: &ga, blue: &ba, alpha: &aa)
        ub.getRed(&rb, green: &gb, blue: &bb, alpha: &ab)
        let tt = CGFloat(t)
        return Color(
            red: Double(ra + (rb - ra) * tt),
            green: Double(ga + (gb - ga) * tt),
            blue: Double(ba + (bb - ba) * tt),
            opacity: Double(aa + (ab - aa) * tt)
        )
    }
}
