import SwiftUI

struct FloatingIconButton: View {
    let systemName: String
    var size: CGFloat = 48
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .frame(width: size, height: size)
                .background {
                    if prominent {
                        Circle().fill(Color.accentColor)
                    } else {
                        Circle().fill(.regularMaterial)
                    }
                }
                .shadow(
                    color: .black.opacity(prominent ? 0.18 : 0.12),
                    radius: prominent ? 12 : 8,
                    x: 0,
                    y: prominent ? 6 : 4
                )
        }
        .buttonStyle(.plain)
    }
}
