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
                title: (single?.isHidden ?? false) ? "Show" : "Hide",
                systemImage: (single?.isHidden ?? false) ? "eye" : "eye.slash",
                enabled: single != nil
            ) {
                if let single { actions.toggleVisibility(single) }
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
        let background = project.safeBackground

        HStack(spacing: 8) {
            CompactActionButton(
                title: background.isHidden ? "Show Background" : "Hide Background",
                systemImage: background.isHidden ? "eye" : "eye.slash"
            ) {
                project.recordUndo()
                background.isHidden.toggle()
            }
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
