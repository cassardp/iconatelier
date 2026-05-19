import SwiftUI
import UIKit

struct LayerQuickActionsRow: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @State private var canPaste: Bool = LayerClipboard.hasContent

    var body: some View {
        let actions = LayerActions(project: project, session: session)
        let single = actions.singleActiveLayer
        let hasActive = actions.hasActiveLayers

        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CompactActionButton(
                        title: (single?.isLocked ?? false) ? "Unlock" : "Lock",
                        systemImage: (single?.isLocked ?? false) ? "lock" : "lock.open",
                        enabled: single != nil
                    ) {
                        if let single { actions.toggleLock(single) }
                    }
                    CompactActionButton(
                        title: "Duplicate",
                        systemImage: "plus.square.on.square",
                        enabled: hasActive
                    ) {
                        actions.duplicate()
                    }
                    CompactActionButton(
                        title: "Copy",
                        systemImage: "doc.on.doc",
                        enabled: hasActive
                    ) {
                        actions.copy()
                    }
                    CompactActionButton(
                        title: "Paste",
                        systemImage: "doc.on.clipboard",
                        enabled: canPaste
                    ) {
                        actions.paste()
                    }
                    CompactActionButton(
                        title: "Bring to Front",
                        systemImage: "square.3.layers.3d.top.filled",
                        enabled: hasActive
                    ) {
                        actions.bringToFront()
                    }
                    CompactActionButton(
                        title: "Send to Back",
                        systemImage: "square.3.layers.3d.bottom.filled",
                        enabled: hasActive
                    ) {
                        actions.sendToBack()
                    }
                    CompactActionButton(
                        title: "Flip Horizontal",
                        systemImage: "arrow.left.and.right",
                        enabled: hasActive
                    ) {
                        actions.flip(horizontal: true)
                    }
                    CompactActionButton(
                        title: "Flip Vertical",
                        systemImage: "arrow.up.and.down",
                        enabled: hasActive
                    ) {
                        actions.flip(horizontal: false)
                    }
                }
                .padding(.trailing, PanelStyle.rowHeight + 56)
            }

            HStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: Color(.systemBackground).opacity(0), location: 0),
                        .init(color: Color(.systemBackground).opacity(0.85), location: 0.55),
                        .init(color: Color(.systemBackground), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 56)
                .allowsHitTesting(false)

                CompactActionButton(
                    title: "Delete",
                    systemImage: "trash",
                    role: .destructive,
                    enabled: hasActive
                ) {
                    actions.delete()
                }
                .background(Color(.systemBackground))
            }
        }
        .frame(height: PanelStyle.rowHeight)
        .onAppear { canPaste = LayerClipboard.hasContent }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            canPaste = LayerClipboard.hasContent
        }
    }
}

struct BackgroundQuickActionsRow: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @State private var canPaste: Bool = LayerClipboard.hasContent

    var body: some View {
        let actions = LayerActions(project: project, session: session)

        HStack(spacing: 8) {
            CompactActionButton(
                title: "App Silhouette",
                systemImage: "app.fill"
            ) {
                withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
                    let layer = project.addShapeLayer(spec: .iosSquircle)
                    session.selectLayer(layer.uuid)
                }
            }
            CompactActionButton(
                title: "Paste",
                systemImage: "doc.on.clipboard",
                enabled: canPaste
            ) {
                actions.paste()
            }
            Spacer(minLength: 0)
        }
        .onAppear { canPaste = LayerClipboard.hasContent }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            canPaste = LayerClipboard.hasContent
        }
    }
}
