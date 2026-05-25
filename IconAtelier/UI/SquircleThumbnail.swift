import SwiftUI

struct SquircleThumbnail<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .aspectRatio(1, contentMode: .fit)
            .clipShape(SquircleShape())
            .overlay {
                SquircleShape()
                    .stroke(SeparatorShapeStyle().opacity(0.4), lineWidth: 1)
            }
    }
}

struct ThumbnailPlaceholder<Glyph: View>: View {
    @ViewBuilder var glyph: Glyph

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.gray.opacity(0.2), .gray.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            glyph
        }
    }
}
