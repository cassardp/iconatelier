import SwiftUI

// Fills its bounding square with a continuous-curvature rounded rectangle at
// the exact iPhone app-icon corner ratio. Unlike Polygon(sides:4, rotation:-45)
// — which inscribes the square in a circle and only covers ~70% of the rect —
// SquircleShape always fills the rect, so scaling matches the canvas mask.
struct SquircleShape: Shape, Equatable {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let r = side * ShapeSpec.defaultSquircleCornerRadius
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let square = CGRect(origin: origin, size: CGSize(width: side, height: side))
        return Path(roundedRect: square, cornerRadius: r, style: .continuous)
    }
}
