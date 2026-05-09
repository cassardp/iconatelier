import SwiftUI
import UIKit

struct LayersPanel: View {
    @Bindable var project: IconProject
    var onClose: () -> Void = {}
    var onAddLayer: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            addButton
        }
        .padding(.vertical, 16)
        .frame(width: 240)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
    }

    private var addButton: some View {
        Button(action: onAddLayer) {
            Label("Add a layer", systemImage: "plus")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Color.accentColor.opacity(0.18),
                    in: .rect(cornerRadius: 12, style: .continuous)
                )
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var header: some View {
        HStack {
            Text("Layers")
                .font(.headline)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(7)
                    .background(.thinMaterial, in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var content: some View {
        if project.layers.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "square.3.stack.3d")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("No layers")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Generate a background or overlay to start.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 16)
        } else {
            List {
                ForEach(project.layers.reversed()) { layer in
                    LayerRow(
                        layer: layer,
                        isSelected: layer.id == project.selectedLayerID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        project.selectedLayerID = layer.id
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            project.remove(layer)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct LayerRow: View {
    let layer: Layer
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(typeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            visibilityToggle
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isSelected ? Color.accentColor.opacity(0.18) : .clear,
            in: .rect(cornerRadius: 10, style: .continuous)
        )
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.tertiarySystemFill))
            if let img = layer.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 40, height: 40)
        .opacity(layer.isHidden ? 0.4 : 1)
    }

    private var typeLabel: String {
        switch layer.kind {
        case .aiBackground: "Background"
        case .aiOverlay: "Overlay"
        }
    }

    private var visibilityToggle: some View {
        Button {
            layer.isHidden.toggle()
        } label: {
            Image(systemName: layer.isHidden ? "eye.slash" : "eye")
                .font(.system(size: 14))
                .foregroundStyle(layer.isHidden ? .secondary : .primary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
