import SwiftUI
import SwiftData
import UIKit

// Legacy alias — `Background` and the rest of the codebase were written
// around `BackgroundKind` before the shared `Paint` model existed. The two
// enums are intentionally one-to-one (same raw values), so we just route
// every reference through `PaintKind`.
typealias BackgroundKind = PaintKind

@Model
final class Background {
    var kindRaw: String = BackgroundKind.solid.rawValue

    var storedSolidColor: StoredColor = StoredColor(r: 0.92, g: 0.92, b: 0.94, a: 1.0)
    var storedGradientColors: [StoredColor] = []
    var storedLinearStart: StoredPoint = StoredPoint(x: 0, y: 0)
    var storedLinearEnd: StoredPoint = StoredPoint(x: 1, y: 1)
    var storedGradientCenter: StoredPoint = StoredPoint(x: 0.5, y: 0.5)
    var radialSpread: Double = 0.75
    var storedMeshColors: [StoredColor] = []
    var meshRotationDegrees: Double = 0

    var isHidden: Bool = false

    var project: IconProject?

    init(
        kind: BackgroundKind = .solid,
        solidColor: Color = .iaDefaultBackground,
        gradientColors: [Color] = [.iaBlue, .iaPurple],
        linearStart: UnitPoint = .topLeading,
        linearEnd: UnitPoint = .bottomTrailing,
        gradientCenter: UnitPoint = .center,
        meshColors: [Color]? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.storedSolidColor = StoredColor(solidColor)
        self.storedGradientColors = gradientColors.map { StoredColor($0) }
        self.storedLinearStart = StoredPoint(linearStart)
        self.storedLinearEnd = StoredPoint(linearEnd)
        self.storedGradientCenter = StoredPoint(gradientCenter)
        self.storedMeshColors = (meshColors ?? Background.defaultMeshColors).map { StoredColor($0) }
        self.isHidden = false
    }

    // MARK: - Bridged properties (Color, UnitPoint, UIImage)

    var kind: BackgroundKind {
        get { BackgroundKind(rawValue: kindRaw)! }
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

    // MARK: - Paint bridge
    //
    // Snapshot the Background's flat columns into a `Paint` value so the
    // shared `PaintEditor` (also used by shape/text fill) can drive the
    // Background through a single `Binding<Paint>`. The setter splats the
    // value back into the same columns — round-trip is lossless.
    var paint: Paint {
        get {
            Paint(
                kind: kind,
                solidColor: storedSolidColor,
                gradientColors: storedGradientColors,
                linearStart: storedLinearStart,
                linearEnd: storedLinearEnd,
                gradientCenter: storedGradientCenter,
                radialSpread: radialSpread,
                meshColors: storedMeshColors,
                meshRotationDegrees: meshRotationDegrees
            )
        }
        set {
            kindRaw = newValue.kind.rawValue
            storedSolidColor = newValue.solidColor
            storedGradientColors = newValue.gradientColors
            storedLinearStart = newValue.linearStart
            storedLinearEnd = newValue.linearEnd
            storedGradientCenter = newValue.gradientCenter
            radialSpread = newValue.radialSpread
            storedMeshColors = newValue.meshColors
            meshRotationDegrees = newValue.meshRotationDegrees
        }
    }

    // MARK: - Defaults

    nonisolated static var defaultMeshColors: [Color] {
        Color.mesh3x3(
            topLeft: .iaPurple,
            topRight: .iaBlue,
            bottomLeft: .iaPink,
            bottomRight: .iaOrange
        )
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
    let radialSpread: Double
    let meshColors: [StoredColor]
    let meshRotationDegrees: Double
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
            radialSpread: radialSpread,
            meshColors: storedMeshColors,
            meshRotationDegrees: meshRotationDegrees,
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
        radialSpread = s.radialSpread
        storedMeshColors = s.meshColors
        meshRotationDegrees = s.meshRotationDegrees
        isHidden = s.isHidden
    }
}

// MARK: - Color tokens

extension Color {
    nonisolated static let iaDefaultBackground = Color(red: 222.0/255.0, green: 222.0/255.0, blue: 222.0/255.0)  // #DEDEDE
    nonisolated static let iaBlue = Color(red: 0.0, green: 0.478, blue: 1.0)        // #007AFF
    nonisolated static let iaPurple = Color(red: 0.345, green: 0.337, blue: 0.839)  // #5856D6
    nonisolated static let iaPink = Color(red: 1.0, green: 0.176, blue: 0.333)      // #FF2D55
    nonisolated static let iaOrange = Color(red: 1.0, green: 0.584, blue: 0.0)      // #FF9500
    nonisolated static let iaSelectionYellow = Color(red: 1.0, green: 0.78, blue: 0.0) // #FFC700

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

    /// Builds a 9-cell 3×3 mesh gradient by linearly interpolating the 5
    /// non-corner cells between the 4 corners. Row-major order.
    nonisolated static func mesh3x3(
        topLeft tl: Color,
        topRight tr: Color,
        bottomLeft bl: Color,
        bottomRight br: Color
    ) -> [Color] {
        let top = mix(tl, tr, 0.5)
        let left = mix(tl, bl, 0.5)
        let right = mix(tr, br, 0.5)
        let bottom = mix(bl, br, 0.5)
        let center = mix(top, bottom, 0.5)
        return [
            tl,   top,    tr,
            left, center, right,
            bl,   bottom, br
        ]
    }
}
