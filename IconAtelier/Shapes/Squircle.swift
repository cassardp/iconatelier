import SwiftUI

struct Squircle: Shape, Equatable {
    var cornerRadiusFraction: Double

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let clamped = max(0, min(0.5, cornerRadiusFraction))
        let radius = side * clamped
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}
