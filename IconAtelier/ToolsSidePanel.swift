import SwiftUI
import UIKit

struct ToolsSidePanel: View {
    @Bindable var project: IconProject

    private static let buttonSize: CGFloat = 44

    var body: some View {
        Group {
            if let layer = editableLayer {
                actionsColumn(for: layer)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 16)
    }

    private var editableLayer: Layer? {
        if let selected = project.selectedLayer { return selected }
        return project.layers.last
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No layer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }

    private func actionsColumn(for layer: Layer) -> some View {
        VStack(spacing: 12) {
            actionButton(
                title: "Duplicate",
                symbol: "square.on.square",
                tint: .primary
            ) {
                project.duplicate(layer)
            }

            actionButton(
                title: layer.isHidden ? "Show" : "Hide",
                symbol: layer.isHidden ? "eye.slash" : "eye",
                tint: .primary
            ) {
                project.toggleVisibility(layer)
            }

            actionButton(
                title: "Delete",
                symbol: "trash",
                tint: .red
            ) {
                project.remove(layer)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func actionButton(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
