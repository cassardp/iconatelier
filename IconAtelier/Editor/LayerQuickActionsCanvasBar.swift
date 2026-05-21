import SwiftUI
import UIKit

struct LayerQuickActionsCanvasBar: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var canPaste: Bool = LayerClipboard.hasContent
    @State private var revealed: Bool = false

    private static let buttonSize: CGFloat = 44
    private static let iconSize: CGFloat = 17
    private static let cornerRadius: CGFloat = 12
    private static let spacing: CGFloat = 6
    private static let horizontalEdgePadding: CGFloat = 72

    private struct Item: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let enabled: Bool
        let destructive: Bool
        let action: () -> Void
    }

    var body: some View {
        let actions = LayerActions(project: project, session: session)
        let items = makeItems(actions: actions)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    iconButton(item: item, index: idx)
                        .transition(
                            .scale(scale: 0.5)
                                .combined(with: .opacity)
                        )
                }
            }
            .padding(.horizontal, Self.horizontalEdgePadding)
            .frame(maxWidth: .infinity, alignment: .center)
            .animation(.spring(duration: 0.35, bounce: 0.3), value: items.map(\.id))
        }
        .scrollClipDisabled()
        .frame(height: Self.buttonSize + 12)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.18),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .onAppear {
            canPaste = LayerClipboard.hasContent
            if reduceMotion {
                revealed = true
            } else {
                revealed = false
                DispatchQueue.main.async {
                    revealed = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            canPaste = LayerClipboard.hasContent
        }
    }

    @ViewBuilder
    private func iconButton(item: Item, index: Int) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            item.action()
        } label: {
            Image(systemName: item.systemImage)
                .font(.system(size: Self.iconSize, weight: .medium))
                .foregroundStyle(iconColor(for: item))
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background(
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .fill(backgroundFill(for: item))
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!item.enabled)
        .opacity((item.enabled ? 1.0 : 0.4) * (revealed ? 1.0 : 0.0))
        .scaleEffect(revealed ? 1.0 : 0.55)
        .blur(radius: revealed ? 0 : 4)
        .animation(animation(for: index), value: revealed)
        .accessibilityLabel(item.title)
    }

    private func animation(for index: Int) -> Animation {
        if reduceMotion {
            return .easeOut(duration: 0.2)
        }
        return .spring(duration: 0.55, bounce: 0.42)
            .delay(Double(index) * 0.035)
    }

    private func iconColor(for item: Item) -> Color {
        item.destructive ? .white : .primary
    }

    private func backgroundFill(for item: Item) -> AnyShapeStyle {
        item.destructive
            ? AnyShapeStyle(Color.red)
            : AnyShapeStyle(PanelStyle.rowFill)
    }

    private func makeItems(actions: LayerActions) -> [Item] {
        let hasActive = actions.hasActiveLayers
        let allLocked = hasActive && actions.allSelectedLocked
        let activeUUIDs = Set(actions.activeLayerUUIDs)
        let layerCount = project.layers.count
        let hasMultipleLayers = layerCount >= 2

        let showBringToFront: Bool = {
            guard hasActive, hasMultipleLayers else { return false }
            let tailIDs = Set(project.layers.suffix(activeUUIDs.count).map(\.uuid))
            return tailIDs != activeUUIDs
        }()
        let showSendToBack: Bool = {
            guard hasActive, hasMultipleLayers else { return false }
            let headIDs = Set(project.layers.prefix(activeUUIDs.count).map(\.uuid))
            return headIDs != activeUUIDs
        }()

        var items: [Item] = [
            Item(
                id: "lock",
                title: allLocked ? "Unlock" : "Lock",
                systemImage: allLocked ? "lock" : "lock.open",
                enabled: hasActive,
                destructive: false
            ) {
                actions.toggleLockSelection()
            },
            Item(
                id: "duplicate",
                title: "Duplicate",
                systemImage: "plus.square.on.square",
                enabled: hasActive,
                destructive: false
            ) {
                actions.duplicate()
            },
            Item(
                id: "copy",
                title: "Copy",
                systemImage: "doc.on.doc",
                enabled: hasActive,
                destructive: false
            ) {
                actions.copy()
            }
        ]

        if canPaste {
            items.append(
                Item(
                    id: "paste",
                    title: "Paste",
                    systemImage: "doc.on.clipboard",
                    enabled: true,
                    destructive: false
                ) {
                    actions.paste()
                }
            )
        }

        if showBringToFront {
            items.append(
                Item(
                    id: "bringToFront",
                    title: "Bring to Front",
                    systemImage: "square.3.layers.3d.top.filled",
                    enabled: hasActive,
                    destructive: false
                ) {
                    actions.bringToFront()
                }
            )
        }
        if showSendToBack {
            items.append(
                Item(
                    id: "sendToBack",
                    title: "Send to Back",
                    systemImage: "square.3.layers.3d.bottom.filled",
                    enabled: hasActive,
                    destructive: false
                ) {
                    actions.sendToBack()
                }
            )
        }

        items.append(contentsOf: [
            Item(
                id: "rotate",
                title: "Rotate 45°",
                systemImage: "rotate.right",
                enabled: hasActive,
                destructive: false
            ) {
                actions.rotate45()
            },
            Item(
                id: "flipH",
                title: "Flip Horizontal",
                systemImage: "arrow.left.and.right",
                enabled: hasActive,
                destructive: false
            ) {
                actions.flip(horizontal: true)
            },
            Item(
                id: "flipV",
                title: "Flip Vertical",
                systemImage: "arrow.up.and.down",
                enabled: hasActive,
                destructive: false
            ) {
                actions.flip(horizontal: false)
            },
            Item(
                id: "delete",
                title: "Delete",
                systemImage: "trash",
                enabled: hasActive,
                destructive: true
            ) {
                actions.delete()
            }
        ])

        return items
    }
}
