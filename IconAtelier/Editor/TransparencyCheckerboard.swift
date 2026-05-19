import SwiftUI

struct TransparencyCheckerboard: View {
    let tile: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var lightTile: Color {
        colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.92)
    }

    private var darkTile: Color {
        colorScheme == .dark ? Color(white: 0.32) : Color(white: 0.78)
    }

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(lightTile))
            let cols = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            var path = Path()
            for row in 0..<rows {
                for col in 0..<cols where (row + col).isMultiple(of: 2) {
                    path.addRect(CGRect(
                        x: CGFloat(col) * tile,
                        y: CGFloat(row) * tile,
                        width: tile,
                        height: tile
                    ))
                }
            }
            context.fill(path, with: .color(darkTile))
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}
