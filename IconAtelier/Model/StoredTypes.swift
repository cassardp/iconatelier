import SwiftUI
import UIKit

nonisolated struct StoredColor: Codable, Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    static let white = StoredColor(r: 1, g: 1, b: 1, a: 1)
    static let black = StoredColor(r: 0, g: 0, b: 0, a: 1)

    init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(_ color: Color) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = Double(r); self.g = Double(g); self.b = Double(b); self.a = Double(a)
    }

    var color: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
}

nonisolated struct StoredPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x; self.y = y
    }

    init(_ point: UnitPoint) {
        self.x = Double(point.x); self.y = Double(point.y)
    }

    var unitPoint: UnitPoint {
        UnitPoint(x: CGFloat(x), y: CGFloat(y))
    }
}
