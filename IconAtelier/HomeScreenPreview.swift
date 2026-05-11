import SwiftUI

/// Fake iOS home screen used in focus mode so the icon is seen in context.
/// Renders a neutral wallpaper with a 4-column grid of gray placeholder shapes
/// (no fake icons — just the squircle outlines) and inserts the real icon at
/// one position. The system's own status bar and home indicator render on top
/// of the wallpaper, so we don't draw mock versions.
struct HomeScreenPreview: View {
    let project: IconProject

    private let columns = 4
    private let rows = 6
    private let totalApps = 18 // includes the real icon
    private let iconRow = 1
    private let iconCol = 1

    private var iconLinearIndex: Int { iconRow * columns + iconCol }

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let horizontalInset = side * 0.055
            let gridWidth = side - horizontalInset * 2
            let iconSize = floor(gridWidth * 0.215)
            let columnSpacing = (gridWidth - CGFloat(columns) * iconSize) / CGFloat(columns - 1)
            let rowSpacing = columnSpacing

            ZStack {
                Wallpaper()
                    .ignoresSafeArea()

                VStack(spacing: rowSpacing) {
                    ForEach(0 ..< rows, id: \.self) { row in
                        HStack(spacing: columnSpacing) {
                            ForEach(0 ..< columns, id: \.self) { col in
                                cell(row: row, col: col, iconSize: iconSize)
                            }
                        }
                    }
                }
                .frame(width: gridWidth)
                .padding(.top, iconSize * 0.35)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func cell(row: Int, col: Int, iconSize: CGFloat) -> some View {
        let index = row * columns + col
        if index == iconLinearIndex {
            RenderedAppIcon(project: project, side: iconSize)
        } else if index < totalApps {
            AppPlaceholder(side: iconSize)
        } else {
            Color.clear
                .frame(width: iconSize, height: iconSize)
        }
    }
}

// MARK: - Rendered app icon (squircle mask, iOS continuous corner ratio)

private struct RenderedAppIcon: View {
    let project: IconProject
    let side: CGFloat

    var body: some View {
        ZStack {
            if let bg = project.background, !bg.isHidden {
                BackgroundView(background: bg, side: side)
            } else {
                Color.black.opacity(0.001)
            }
            ForEach(project.layers) { layer in
                if !layer.isHidden {
                    LayerContentView(layer: layer, side: side)
                        .shadow(
                            color: .black.opacity(layer.shadowOpacity),
                            radius: side * layer.shadowRadius,
                            x: side * layer.shadowOffsetX,
                            y: side * layer.shadowOffsetY
                        )
                        .scaleEffect(layer.scale)
                        .rotationEffect(layer.rotation)
                        .opacity(layer.opacity)
                        .offset(
                            x: layer.offset.width * side,
                            y: layer.offset.height * side
                        )
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(.rect(cornerRadius: side * 0.2237, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.28), radius: side * 0.08, y: side * 0.04)
    }
}

// MARK: - Empty app placeholder

private struct AppPlaceholder: View {
    let side: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .frame(width: side, height: side)
    }
}

// MARK: - Wallpaper

private struct Wallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.20, blue: 0.26),
                Color(red: 0.08, green: 0.09, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
