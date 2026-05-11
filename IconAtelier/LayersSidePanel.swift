import SwiftUI
import UIKit

struct LayersBar: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    @Binding var isSheetOpen: Bool

    @State private var draggingUUID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragStartIndex: Int?
    @State private var targetIndex: Int?
    @State private var dragStartX: CGFloat = 0

    private static let thumbnailSize: CGFloat = 56
    private static let spacing: CGFloat = 8
    private static let verticalPadding: CGFloat = 8
    private static let itemStride: CGFloat = thumbnailSize + spacing
    static let borderWidth: CGFloat = 2
    static let idleBorderColor: Color = Color(.systemGray3)
    static let selectedBorderColor: Color = .primary.opacity(0.7)

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.spacing) {
                    addButton
                    ForEach(Array(uiLayers.enumerated()), id: \.element.uuid) { idx, layer in
                        rowView(layer: layer, index: idx)
                    }
                    BackgroundThumbnailRow(
                        background: project.safeBackground,
                        isSelected: session.isBackgroundSelected
                    )
                        .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                        .onTapGesture {
                            session.selectBackground()
                            isSheetOpen = true
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, Self.verticalPadding)
                .frame(minWidth: geo.size.width, alignment: .center)
            }
            .scrollDisabled(draggingUUID != nil)
        }
        .frame(height: Self.thumbnailSize + Self.verticalPadding * 2)
    }

    private var addButton: some View {
        Menu {
            Button {
                withSpring { session.selectLayer(project.addEmptyAIOverlay().uuid) }
            } label: {
                Label("AI image", systemImage: "sparkles")
            }
            Button {
                withSpring { session.selectLayer(project.addSymbolOverlay().uuid) }
            } label: {
                Label("Symbol", systemImage: "star")
            }
            Button {
                withSpring { session.selectLayer(project.addEmojiOverlay().uuid) }
            } label: {
                Label("Emoji", systemImage: "face.smiling")
            }
            Button {
                withSpring { session.selectLayer(project.addTextOverlay().uuid) }
            } label: {
                Label("Text", systemImage: "textformat")
            }
        } label: {
            RoundedRectangle(
                cornerRadius: Self.thumbnailSize * 0.2237,
                style: .continuous
            )
            .strokeBorder(
                LayersBar.idleBorderColor,
                style: StrokeStyle(lineWidth: LayersBar.borderWidth, dash: [4])
            )
            .overlay {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Add layer")
    }

    private func withSpring(_ action: () -> Void) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            action()
        }
    }

    private var uiLayers: [Layer] { Array(project.layers.reversed()) }

    @ViewBuilder
    private func rowView(layer: Layer, index: Int) -> some View {
        let isDragging = draggingUUID == layer.uuid
        let shift = computeShift(for: index)
        let isSelected = layer.uuid == session.selectedLayerUUID && !session.isBackgroundSelected

        LayerThumbnailRow(layer: layer, isSelected: isSelected)
            .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
            .transition(.scale.combined(with: .opacity))
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .shadow(
                color: .black.opacity(isDragging ? 0.22 : 0),
                radius: isDragging ? 14 : 0,
                x: 0,
                y: isDragging ? 6 : 0
            )
            .offset(x: isDragging ? dragOffset : shift)
            .zIndex(isDragging ? 1 : 0)
            .animation(.smooth(duration: 0.2), value: shift)
            .animation(.smooth(duration: 0.2), value: isDragging)
            .onTapGesture {
                session.selectLayer(layer.uuid)
                isSheetOpen = true
            }
            .gesture(
                LongPressDragRecognizer { recognizer, location in
                    handleReorder(state: recognizer.state, x: location.x, layer: layer, index: index)
                }
            )
    }

    private func computeShift(for index: Int) -> CGFloat {
        guard let dragIdx = dragStartIndex,
              let target = targetIndex,
              dragIdx != index
        else { return 0 }

        if dragIdx < target {
            if index > dragIdx && index <= target { return -Self.itemStride }
        } else if dragIdx > target {
            if index >= target && index < dragIdx { return Self.itemStride }
        }
        return 0
    }

    private func handleReorder(state: UIGestureRecognizer.State, x: CGFloat, layer: Layer, index: Int) {
        switch state {
        case .began:
            draggingUUID = layer.uuid
            dragStartIndex = index
            targetIndex = index
            dragStartX = x
            dragOffset = 0
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .changed:
            guard draggingUUID == layer.uuid else { return }
            dragOffset = x - dragStartX
            let movedItems = Int((dragOffset / Self.itemStride).rounded())
            let proposed = max(0, min(uiLayers.count - 1, index + movedItems))
            if proposed != targetIndex {
                targetIndex = proposed
                UISelectionFeedbackGenerator().selectionChanged()
            }
        case .ended, .cancelled, .failed:
            guard draggingUUID == layer.uuid else { return }
            finalizeDrag()
        default:
            break
        }
    }

    private func finalizeDrag() {
        let from = dragStartIndex
        let to = targetIndex
        let didMove = from != nil && to != nil && from != to

        withAnimation(.smooth(duration: 0.22)) {
            if let from, let to, from != to {
                let n = project.layers.count
                let nativeFrom = n - 1 - from
                let nativeTarget = n - 1 - to
                let toOffset = nativeFrom < nativeTarget ? nativeTarget + 1 : nativeTarget
                project.move(from: IndexSet(integer: nativeFrom), to: toOffset)
            }
            draggingUUID = nil
            dragOffset = 0
            dragStartIndex = nil
            targetIndex = nil
        }
        if didMove {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

struct BackgroundThumbnailRow: View {
    let background: Background
    let isSelected: Bool

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let outerRadius = geo.size.width * 0.2237
                    let inset: CGFloat = 4
                    let innerRadius = max(0, outerRadius - inset)
                    ZStack {
                        ZStack {
                            TransparencyCheckerboard(tile: 6)
                            if background.isHidden {
                                Image(systemName: "eye.slash")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            } else {
                                BackgroundView(background: background, side: geo.size.width - inset * 2)
                            }
                        }
                        .clipShape(.rect(cornerRadius: innerRadius, style: .continuous))
                        .padding(inset)

                        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                            .strokeBorder(
                                isSelected ? LayersBar.selectedBorderColor : LayersBar.idleBorderColor,
                                lineWidth: LayersBar.borderWidth
                            )
                    }
                    .animation(.smooth(duration: 0.18), value: isSelected)
                }
            }
            .contentShape(Rectangle())
            .accessibilityLabel("Background")
    }
}

struct LongPressDragRecognizer: UIGestureRecognizerRepresentable {
    var minimumDuration: TimeInterval = 0.3
    var allowableMovement: CGFloat = 4
    let onChange: (UILongPressGestureRecognizer, CGPoint) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = allowableMovement
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        onChange(recognizer, context.converter.localLocation)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
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
                    let outerRadius = geo.size.width * 0.2237
                    let inset: CGFloat = 4
                    let innerRadius = max(0, outerRadius - inset)
                    ZStack {
                        ZStack {
                            TransparencyCheckerboard(tile: 6)
                            if layer.isHidden {
                                Image(systemName: "eye.slash")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            } else {
                                OverlayLayerRender(layer: layer, side: geo.size.width - inset * 2)
                            }
                        }
                        .clipShape(.rect(cornerRadius: innerRadius, style: .continuous))
                        .padding(inset)

                        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                            .strokeBorder(
                                isSelected ? LayersBar.selectedBorderColor : LayersBar.idleBorderColor,
                                lineWidth: LayersBar.borderWidth
                            )
                    }
                    .animation(.smooth(duration: 0.18), value: isSelected)
                }
            }
            .contentShape(Rectangle())
    }
}
