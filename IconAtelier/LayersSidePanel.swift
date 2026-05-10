import SwiftUI
import UIKit

struct LayersSidePanel: View {
    @Bindable var project: IconProject

    @State private var draggingID: Layer.ID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragStartIndex: Int?
    @State private var targetIndex: Int?

    private static let rowHeight: CGFloat = 78
    private static let rowPaddingH: CGFloat = 16

    var body: some View {
        Group {
            if project.layers.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var uiLayers: [Layer] { Array(project.layers.reversed()) }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.3.stack.3d")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No layers")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }

    private var content: some View {
        GeometryReader { geo in
            let totalHeight = CGFloat(uiLayers.count) * Self.rowHeight
            let needsScroll = totalHeight > geo.size.height

            Group {
                if needsScroll {
                    ScrollView(showsIndicators: false) {
                        rowsStack
                    }
                    .scrollDisabled(draggingID != nil)
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        rowsStack
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var rowsStack: some View {
        VStack(spacing: 0) {
            ForEach(Array(uiLayers.enumerated()), id: \.element.id) { idx, layer in
                rowView(layer: layer, index: idx)
            }
        }
    }

    @ViewBuilder
    private func rowView(layer: Layer, index: Int) -> some View {
        let isDragging = draggingID == layer.id
        let shift = computeShift(for: index)

        LayerThumbnailRow(
            layer: layer,
            isSelected: layer.id == project.selectedLayerID
        )
        .padding(.horizontal, Self.rowPaddingH)
        .frame(height: Self.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            project.selectedLayerID = layer.id
        }
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .shadow(
            color: .black.opacity(isDragging ? 0.22 : 0),
            radius: isDragging ? 14 : 0,
            x: 0,
            y: isDragging ? 6 : 0
        )
        .offset(y: isDragging ? dragOffset : shift)
        .zIndex(isDragging ? 1 : 0)
        .animation(.smooth(duration: 0.2), value: shift)
        .animation(.smooth(duration: 0.2), value: isDragging)
        .gesture(longPressDragGesture(for: layer, at: index))
    }

    private func computeShift(for index: Int) -> CGFloat {
        guard let dragIdx = dragStartIndex,
              let target = targetIndex,
              dragIdx != index
        else { return 0 }

        if dragIdx < target {
            if index > dragIdx && index <= target { return -Self.rowHeight }
        } else if dragIdx > target {
            if index >= target && index < dragIdx { return Self.rowHeight }
        }
        return 0
    }

    private func longPressDragGesture(for layer: Layer, at index: Int) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first:
                    break
                case .second(true, let drag?):
                    if draggingID == nil {
                        draggingID = layer.id
                        dragStartIndex = index
                        targetIndex = index
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    dragOffset = drag.translation.height
                    let movedRows = Int((dragOffset / Self.rowHeight).rounded())
                    let proposed = max(0, min(uiLayers.count - 1, index + movedRows))
                    if proposed != targetIndex {
                        targetIndex = proposed
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                finalizeDrag()
            }
    }

    private func finalizeDrag() {
        defer {
            withAnimation(.smooth(duration: 0.22)) {
                draggingID = nil
                dragOffset = 0
                dragStartIndex = nil
                targetIndex = nil
            }
        }
        guard let from = dragStartIndex,
              let to = targetIndex,
              from != to
        else { return }

        let n = project.layers.count
        let nativeFrom = n - 1 - from
        let nativeTarget = n - 1 - to
        let toOffset = nativeFrom < nativeTarget ? nativeTarget + 1 : nativeTarget
        project.move(from: IndexSet(integer: nativeFrom), to: toOffset)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct LayerThumbnailRow: View {
    let layer: Layer
    let isSelected: Bool

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let radius = geo.size.width * 0.2237
                    ZStack {
                        if layer.fillsCanvas {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        } else {
                            TransparencyCheckerboard(tile: 6)
                        }
                        if let img = layer.image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .clipShape(.rect(cornerRadius: radius, style: .continuous))
                    .opacity(layer.isHidden ? 0.4 : 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    }
                }
            }
            .contentShape(Rectangle())
    }
}
