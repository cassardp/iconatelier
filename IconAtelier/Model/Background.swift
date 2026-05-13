import SwiftUI
import SwiftData
import UIKit

enum BackgroundKind: String, CaseIterable, Identifiable {
    case ai
    case solid
    case meshGradient
    case linearGradient
    case radialGradient

    var id: String { rawValue }
}

@Model
final class Background {
    var kindRaw: String = BackgroundKind.solid.rawValue

    var storedSolidColor: StoredColor = StoredColor(r: 0.92, g: 0.92, b: 0.94, a: 1.0)
    var storedGradientColors: [StoredColor] = []
    var storedLinearStart: StoredPoint = StoredPoint(x: 0, y: 0)
    var storedLinearEnd: StoredPoint = StoredPoint(x: 1, y: 1)
    var storedGradientCenter: StoredPoint = StoredPoint(x: 0.5, y: 0.5)
    var storedMeshColors: [StoredColor] = []
    var meshRotationDegrees: Double = 0

    @Attribute(.externalStorage) var aiImagePNG: Data?
    var aiPrompt: String?

    var isHidden: Bool = false

    var project: IconProject?

    init(
        kind: BackgroundKind = .solid,
        solidColor: Color = .iaDefaultBackground,
        gradientColors: [Color] = [.iaBlue, .iaPurple],
        linearStart: UnitPoint = .topLeading,
        linearEnd: UnitPoint = .bottomTrailing,
        gradientCenter: UnitPoint = .center,
        meshColors: [Color]? = nil,
        aiImage: UIImage? = nil,
        aiPrompt: String? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.storedSolidColor = StoredColor(solidColor)
        self.storedGradientColors = gradientColors.map { StoredColor($0) }
        self.storedLinearStart = StoredPoint(linearStart)
        self.storedLinearEnd = StoredPoint(linearEnd)
        self.storedGradientCenter = StoredPoint(gradientCenter)
        self.storedMeshColors = (meshColors ?? Background.defaultMeshColors).map { StoredColor($0) }
        self.aiImagePNG = aiImage?.pngData()
        self.aiPrompt = aiPrompt
        self.isHidden = false
    }

    // MARK: - Bridged properties (Color, UnitPoint, UIImage)

    var kind: BackgroundKind {
        get { BackgroundKind(rawValue: kindRaw) ?? .meshGradient }
        set { kindRaw = newValue.rawValue }
    }

    var solidColor: Color {
        get { storedSolidColor.color }
        set { storedSolidColor = StoredColor(newValue) }
    }

    var gradientColors: [Color] {
        get { storedGradientColors.map { $0.color } }
        set { storedGradientColors = newValue.map { StoredColor($0) } }
    }

    var linearStart: UnitPoint {
        get { storedLinearStart.unitPoint }
        set { storedLinearStart = StoredPoint(newValue) }
    }

    var linearEnd: UnitPoint {
        get { storedLinearEnd.unitPoint }
        set { storedLinearEnd = StoredPoint(newValue) }
    }

    var gradientCenter: UnitPoint {
        get { storedGradientCenter.unitPoint }
        set { storedGradientCenter = StoredPoint(newValue) }
    }

    var meshColors: [Color] {
        get { storedMeshColors.map { $0.color } }
        set { storedMeshColors = newValue.map { StoredColor($0) } }
    }

    var aiImage: UIImage? {
        get { aiImagePNG.flatMap { UIImage(data: $0) } }
        set { aiImagePNG = newValue?.pngData() }
    }

    // MARK: - Defaults

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

// MARK: - Snapshot for undo

struct BackgroundSnapshot {
    let kind: BackgroundKind
    let solidColor: StoredColor
    let gradientColors: [StoredColor]
    let linearStart: StoredPoint
    let linearEnd: StoredPoint
    let gradientCenter: StoredPoint
    let meshColors: [StoredColor]
    let meshRotationDegrees: Double
    let aiImagePNG: Data?
    let aiPrompt: String?
    let isHidden: Bool
}

extension Background {
    func snapshot() -> BackgroundSnapshot {
        BackgroundSnapshot(
            kind: kind,
            solidColor: storedSolidColor,
            gradientColors: storedGradientColors,
            linearStart: storedLinearStart,
            linearEnd: storedLinearEnd,
            gradientCenter: storedGradientCenter,
            meshColors: storedMeshColors,
            meshRotationDegrees: meshRotationDegrees,
            aiImagePNG: aiImagePNG,
            aiPrompt: aiPrompt,
            isHidden: isHidden
        )
    }

    func apply(_ s: BackgroundSnapshot) {
        kindRaw = s.kind.rawValue
        storedSolidColor = s.solidColor
        storedGradientColors = s.gradientColors
        storedLinearStart = s.linearStart
        storedLinearEnd = s.linearEnd
        storedGradientCenter = s.gradientCenter
        storedMeshColors = s.meshColors
        meshRotationDegrees = s.meshRotationDegrees
        aiImagePNG = s.aiImagePNG
        aiPrompt = s.aiPrompt
        isHidden = s.isHidden
    }
}

// MARK: - Color tokens

extension Color {
    nonisolated static let iaDefaultBackground = Color(red: 0.0, green: 140.0/255.0, blue: 180.0/255.0)  // #008CB4
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
