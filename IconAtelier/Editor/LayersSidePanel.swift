import SwiftUI
import UIKit

struct LayersBar: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    let onItemSelected: () -> Void
    let coordinateSpaceName: String
    let onRowFrame: (UUID, CGRect) -> Void
    let onDragMove: (UUID, CGPoint) -> Bool
    let onDragEnd: (UUID) -> Bool

    @State private var draggingUUID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0
    @State private var dragStartIndex: Int?
    @State private var targetIndex: Int?
    @State private var dragStartX: CGFloat = 0
    @State private var dragStartY: CGFloat = 0
    @State private var isOverTrash: Bool = false

    private static let thumbnailSize: CGFloat = 64
    private static let spacing: CGFloat = 8
    private static let verticalPadding: CGFloat = 8
    private static let itemStride: CGFloat = thumbnailSize + spacing
    static let borderWidth: CGFloat = 2
    static let idleBorderColor: Color = Color(.systemGray3)
    static let selectedBorderColor: Color = .iaSelectionYellow

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Self.spacing) {
                        ForEach(Array(uiLayers.enumerated()), id: \.element.uuid) { idx, layer in
                            rowView(layer: layer, index: idx)
                                .id(layer.uuid)
                        }
                        backgroundButton
                            .id(Self.backgroundScrollID)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, Self.verticalPadding)
                    .frame(minWidth: geo.size.width, alignment: .center)
                }
                .scrollClipDisabled()
                .scrollDisabled(draggingUUID != nil)
                .onChange(of: session.selectedLayerUUID) { _, newUUID in
                    guard draggingUUID == nil, let uuid = newUUID else { return }
                    withAnimation(.smooth(duration: 0.25)) {
                        proxy.scrollTo(uuid, anchor: .center)
                    }
                }
                .onChange(of: session.isBackgroundSelected) { _, isSelected in
                    guard draggingUUID == nil, isSelected else { return }
                    withAnimation(.smooth(duration: 0.25)) {
                        proxy.scrollTo(Self.backgroundScrollID, anchor: .center)
                    }
                }
            }
        }
        .frame(height: Self.thumbnailSize + Self.verticalPadding * 2)
    }

    private static let backgroundScrollID = "iconatelier.layersbar.background"

    private var backgroundButton: some View {
        BackgroundThumbnailRow(
            background: project.safeBackground,
            isSelected: session.isBackgroundSelected
        )
        .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
        .onTapGesture {
            if !session.isBackgroundSelected {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            session.selectBackground()
            onItemSelected()
        }
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
        let isSelected = session.isLayerSelected(layer.uuid)

        let draggedScale: CGFloat = {
            guard isDragging else { return 1.0 }
            return isOverTrash ? 0.7 : 1.05
        }()

        LayerThumbnailRow(layer: layer, isSelected: isSelected)
            .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(coordinateSpaceName))
            } action: { newFrame in
                onRowFrame(layer.uuid, newFrame)
            }
            .transition(.scale.combined(with: .opacity))
            .scaleEffect(draggedScale)
            .opacity(isDragging && isOverTrash ? 0.6 : 1.0)
            .shadow(
                color: .black.opacity(isDragging ? 0.22 : 0),
                radius: isDragging ? 14 : 0,
                x: 0,
                y: isDragging ? 6 : 0
            )
            .offset(
                x: isDragging ? dragOffset : shift,
                y: isDragging ? dragOffsetY : 0
            )
            .zIndex(isDragging ? 1 : 0)
            .animation(.smooth(duration: 0.2), value: shift)
            .animation(.smooth(duration: 0.2), value: isDragging)
            .animation(.spring(duration: 0.25, bounce: 0.35), value: isOverTrash)
            .onTapGesture {
                if !isSelected {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                session.selectLayer(layer.uuid)
                onItemSelected()
            }
            .gesture(
                LongPressDragRecognizer(coordinateSpace: .named(coordinateSpaceName)) { recognizer, location in
                    handleReorder(state: recognizer.state, location: location, layer: layer, index: index)
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

    private func handleReorder(state: UIGestureRecognizer.State, location: CGPoint, layer: Layer, index: Int) {
        switch state {
        case .began:
            draggingUUID = layer.uuid
            dragStartIndex = index
            targetIndex = index
            dragStartX = location.x
            dragStartY = location.y
            dragOffset = 0
            dragOffsetY = 0
            isOverTrash = false
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .changed:
            guard draggingUUID == layer.uuid else { return }
            dragOffset = location.x - dragStartX
            dragOffsetY = location.y - dragStartY
            let overTrash = onDragMove(layer.uuid, location)
            if overTrash != isOverTrash {
                isOverTrash = overTrash
            }
            if overTrash {
                if targetIndex != dragStartIndex {
                    targetIndex = dragStartIndex
                }
            } else {
                let movedItems = Int((dragOffset / Self.itemStride).rounded())
                let proposed = max(0, min(uiLayers.count - 1, index + movedItems))
                if proposed != targetIndex {
                    targetIndex = proposed
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        case .ended, .cancelled, .failed:
            guard draggingUUID == layer.uuid else { return }
            finalizeDrag(layer: layer, state: state)
        default:
            break
        }
    }

    private func finalizeDrag(layer: Layer, state: UIGestureRecognizer.State) {
        let consumedAsDelete = state == .ended ? onDragEnd(layer.uuid) : false

        let from = dragStartIndex
        let to = targetIndex
        let didMove = !consumedAsDelete && from != nil && to != nil && from != to

        withAnimation(.smooth(duration: 0.22)) {
            if !consumedAsDelete, let from, let to, from != to {
                let n = project.layers.count
                let nativeFrom = n - 1 - from
                let nativeTarget = n - 1 - to
                let toOffset = nativeFrom < nativeTarget ? nativeTarget + 1 : nativeTarget
                project.move(from: IndexSet(integer: nativeFrom), to: toOffset)
            }
            draggingUUID = nil
            dragOffset = 0
            dragOffsetY = 0
            dragStartIndex = nil
            targetIndex = nil
            isOverTrash = false
        }
        if didMove {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

struct BackgroundThumbnailRow: View {
    let background: Background
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let inset: CGFloat = 4
                    ZStack {
                        BackgroundView(background: background, side: geo.size.width - inset * 2)
                            .clipShape(SquircleShape())
                            .padding(inset)

                        if isSelected {
                            SquircleShape()
                                .strokeBorder(
                                    LayersBar.selectedBorderColor,
                                    lineWidth: LayersBar.borderWidth
                                )
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .scale(scale: 1.08).combined(with: .opacity)
                                )
                        }
                    }
                    .animation(.snappy(duration: 0.25, extraBounce: 0.15), value: isSelected)
                }
            }
            .contentShape(Rectangle())
            .accessibilityLabel("Background")
    }
}

struct LongPressDragRecognizer: UIGestureRecognizerRepresentable {
    var minimumDuration: TimeInterval = 0.3
    var allowableMovement: CGFloat = 4
    var coordinateSpace: NamedCoordinateSpace
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
        let location = context.converter.location(in: coordinateSpace)
        onChange(recognizer, location)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let inset: CGFloat = 4
                    let contentSide = max(0, geo.size.width - inset * 2)
                    ZStack {
                        ZStack {
                            TransparencyCheckerboard(tile: 8)
                            LayerContentView(
                                layer: layer,
                                side: contentSide,
                                scale: normalizedThumbnailScale(for: layer.kind)
                            )
                            .opacity(layer.opacity)
                            if layer.isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(.black.opacity(0.55), in: Circle())
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(4)
                            }
                        }
                        .frame(width: contentSide, height: contentSide)
                        .clipShape(SquircleShape())
                        .padding(inset)

                        if isSelected {
                            SquircleShape()
                                .strokeBorder(
                                    LayersBar.selectedBorderColor,
                                    lineWidth: LayersBar.borderWidth
                                )
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .scale(scale: 1.08).combined(with: .opacity)
                                )
                        }
                    }
                    .animation(.snappy(duration: 0.25, extraBounce: 0.15), value: isSelected)
                }
            }
            .contentShape(Rectangle())
    }
}

private func normalizedThumbnailScale(for kind: LayerKind) -> CGFloat {
    switch kind {
    case .image: return 1.0 / 0.7
    case .text: return 0.85 / 0.6
    case .parametricShape: return 0.85 / 0.5
    }
}
