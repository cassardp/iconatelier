import SwiftUI
import UIKit

enum EditorTab: String, Hashable, CaseIterable, Identifiable {
    case layers
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .layers: "Layers"
        case .tools: "Tools"
        }
    }

    var symbol: String {
        switch self {
        case .layers: "square.3.stack.3d"
        case .tools: "slider.horizontal.3"
        }
    }
}

enum LayerTool: String, Hashable, CaseIterable, Identifiable {
    case move
    case scale
    case rotate
    case opacity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: "Move"
        case .scale: "Scale"
        case .rotate: "Rotate"
        case .opacity: "Opacity"
        }
    }

    var symbol: String {
        switch self {
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .scale: "arrow.up.left.and.arrow.down.right"
        case .rotate: "arrow.clockwise"
        case .opacity: "drop.fill"
        }
    }
}

struct EditorSheet: View {
    @Bindable var project: IconProject
    let tab: EditorTab
    @Binding var activeTool: LayerTool

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(tab.title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .layers:
            LayersTab(project: project)
        case .tools:
            ToolsTab(
                project: project,
                activeTool: $activeTool
            )
        }
    }
}

// MARK: - Tools tab

struct ToolsTab: View {
    @Bindable var project: IconProject
    @Binding var activeTool: LayerTool

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let layer = editableLayer {
                    toolPicker
                    contextualSlider(for: layer)
                    actionRow(for: layer)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var editableLayer: Layer? {
        if let selected = project.selectedLayer { return selected }
        return project.layers.last
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No layer to edit",
            systemImage: "wand.and.stars",
            description: Text("Use the Add button to generate a background or overlay.")
        )
        .padding(.vertical, 32)
    }

    private var toolPicker: some View {
        Picker("Tool", selection: $activeTool) {
            ForEach(LayerTool.allCases) { tool in
                Label(tool.title, systemImage: tool.symbol)
                    .tag(tool)
            }
        }
        .pickerStyle(.palette)
        .labelStyle(.iconOnly)
    }

    @ViewBuilder
    private func contextualSlider(for layer: Layer) -> some View {
        switch activeTool {
        case .move:
            Text("Drag the layer on the canvas")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
        case .scale:
            labeledSlider(
                value: Binding(
                    get: { Double(layer.scale) },
                    set: { layer.scale = CGFloat(max(0.1, min($0, 4.0))) }
                ),
                range: 0.1...4.0,
                text: String(format: "%.2f×", layer.scale),
                disabled: layer.fillsCanvas
            )
        case .rotate:
            labeledSlider(
                value: Binding(
                    get: { layer.rotation.degrees },
                    set: { layer.rotation = .degrees(min(max($0, -180), 180)) }
                ),
                range: -180...180,
                text: "\(Int(layer.rotation.degrees))°",
                disabled: layer.fillsCanvas
            )
        case .opacity:
            labeledSlider(
                value: Binding(
                    get: { layer.opacity },
                    set: { layer.opacity = $0 }
                ),
                range: 0...1,
                text: "\(Int(layer.opacity * 100)) %",
                disabled: false
            )
        }
    }

    private func labeledSlider(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        text: String,
        disabled: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Slider(value: value, in: range, onEditingChanged: { editing in
                if editing { project.recordUndo() }
            })
            .disabled(disabled)
            Text(text)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 56, alignment: .trailing)
        }
    }

    private func actionRow(for layer: Layer) -> some View {
        HStack(spacing: 8) {
            Button {
                project.duplicate(layer)
            } label: {
                Label("Duplicate", systemImage: "square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button {
                project.toggleVisibility(layer)
            } label: {
                Label(
                    layer.isHidden ? "Show" : "Hide",
                    systemImage: layer.isHidden ? "eye.slash" : "eye"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button(role: .destructive) {
                project.remove(layer)
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.red)
        }
        .labelStyle(.titleAndIcon)
    }
}

// MARK: - Layers tab

struct LayersTab: View {
    @Bindable var project: IconProject

    var body: some View {
        if project.layers.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No layers yet",
            systemImage: "square.3.stack.3d",
            description: Text("Use the Add tab to generate a background or overlay.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(project.layers.reversed()) { layer in
                LayerRow(
                    project: project,
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
                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            }
            .onMove { source, destination in
                let n = project.layers.count
                let nativeSource = IndexSet(source.map { n - 1 - $0 })
                let nativeDestination = n - destination
                project.move(from: nativeSource, to: nativeDestination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct LayerRow: View {
    @Bindable var project: IconProject
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
            Button {
                project.toggleVisibility(layer)
            } label: {
                Image(systemName: layer.isHidden ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(layer.isHidden ? .secondary : .primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
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
}
