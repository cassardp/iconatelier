import SwiftUI
import Foundation

struct SquircleShape: InsettableShape, Equatable {

    static let exponent: Double = 5.2

    private static let sampleCount = 360

    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) - insetAmount * 2
        guard side > 0 else { return Path() }
        let r = side / 2
        let cx = rect.midX
        let cy = rect.midY
        let invN = 2.0 / Self.exponent

        var path = Path()
        for i in 0...Self.sampleCount {
            let t = (Double(i) / Double(Self.sampleCount)) * 2 * .pi
            let c = Darwin.cos(t)
            let s = Darwin.sin(t)
            let x = (c >= 0 ? 1.0 : -1.0) * pow(abs(c), invN)
            let y = (s >= 0 ? 1.0 : -1.0) * pow(abs(s), invN)
            let p = CGPoint(x: cx + CGFloat(x) * r, y: cy + CGFloat(y) * r)
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> SquircleShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

struct SuperellipseShape: InsettableShape, Equatable {

    var roundness: Double

    var arcStart: Double = -90

    var arcSweep: Double = 1.0

    private static let sampleCount = 360
    private static let minExponent: Double = 2.0
    private static let maxExponent: Double = 10.0

    var insetAmount: CGFloat = 0

    private var exponent: Double {
        let r = max(0, min(1, roundness))
        return Self.minExponent + (Self.maxExponent - Self.minExponent) * (1 - r)
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) - insetAmount * 2
        guard side > 0 else { return Path() }
        let r = side / 2
        let cx = rect.midX
        let cy = rect.midY
        let invN = 2.0 / exponent

        let sweepFrac = max(0, min(1, arcSweep))
        let isClosed = sweepFrac >= 1.0 - 1e-6
        let startRad = arcStart * .pi / 180
        let totalRad = (isClosed ? 2 : sweepFrac * 2) * .pi
        let segments = isClosed ? Self.sampleCount : max(2, Int((Double(Self.sampleCount) * sweepFrac).rounded()))

        var path = Path()
        for i in 0...segments {
            let t = startRad + (Double(i) / Double(segments)) * totalRad
            let c = Darwin.cos(t)
            let s = Darwin.sin(t)
            let x = (c >= 0 ? 1.0 : -1.0) * pow(abs(c), invN)
            let y = (s >= 0 ? 1.0 : -1.0) * pow(abs(s), invN)
            let p = CGPoint(x: cx + CGFloat(x) * r, y: cy + CGFloat(y) * r)
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        if isClosed {
            path.closeSubpath()
        }
        return path
    }

    func inset(by amount: CGFloat) -> SuperellipseShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
