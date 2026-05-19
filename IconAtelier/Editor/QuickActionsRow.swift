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
            Spacer(minLength: 0)
            CompactActionButton(
                title: "Delete",
                systemImage: "trash",
                role: .destructive,
                enabled: hasActive
            ) {
                actions.delete()
            }
        }
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
