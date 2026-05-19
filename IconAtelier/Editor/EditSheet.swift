import SwiftUI
import UIKit

struct EditSheet: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    var body: some View {
        content
            .sheetUserInterfaceStyle(.dark)
            .presentationBackground(Color(.systemBackground))
    }

    @ViewBuilder
    private var content: some View {
        if session.isBackgroundSelected {
            BackgroundEditorContent(project: project, session: session)
        } else if project.layer(withID: session.selectedLayerUUID) != nil {
            LayerEditorContent(project: project, session: session)
        } else {
            EmptySelectionContent()
        }
    }
}

// MARK: - Action rows (right-aligned, scrollable with content)

struct LayerActionsRow: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    let layer: Layer

    @State private var canPaste: Bool = LayerClipboard.hasContent

    var body: some View {
        HStack(spacing: 8) {
            CompactActionButton(
                title: layer.isHidden ? "Show" : "Hide",
                systemImage: layer.isHidden ? "eye" : "eye.slash"
            ) {
                project.toggleVisibility(layer)
            }
            CompactMenuButton(title: "More actions", systemImage: "ellipsis") {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        let copy = project.duplicate(layer)
                        session.selectLayer(copy.uuid)
                    }
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Button {
                    LayerClipboard.copy([layer])
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button {
                    LayerClipboard.copy([layer])
                    let wasSelected = session.selectedLayerUUID == layer.uuid
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        project.remove(layer)
                        if wasSelected {
                            if let top = project.layers.last {
                                session.selectLayer(top.uuid)
                            } else {
                                session.selectBackground()
                            }
                        }
                    }
                } label: {
                    Label("Cut", systemImage: "scissors")
                }
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .disabled(!canPaste)
            }
            Spacer(minLength: 0)
            CompactActionButton(
                title: "Delete",
                systemImage: "trash"
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    let wasSelected = session.selectedLayerUUID == layer.uuid
                    project.remove(layer)
                    if wasSelected {
                        if let top = project.layers.last {
                            session.selectLayer(top.uuid)
                        } else {
                            session.selectBackground()
                        }
                    }
                }
            }
        }
        .onAppear { canPaste = LayerClipboard.hasContent }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            canPaste = LayerClipboard.hasContent
        }
    }

    private func pasteFromClipboard() {
        guard let pasted = LayerClipboard.paste(), !pasted.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            let inserted = project.addPastedLayers(pasted)
            if let top = inserted.last {
                session.selectLayer(top.uuid)
            }
        }
    }
}

struct BackgroundActionsRow: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    @State private var canPaste: Bool = LayerClipboard.hasContent

    var body: some View {
        let background = project.safeBackground
        HStack(spacing: 8) {
            CompactActionButton(
                title: background.isHidden ? "Show" : "Hide",
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
            CompactMenuButton(title: "More actions", systemImage: "ellipsis") {
                Button { } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .disabled(true)
                Button { } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(true)
                Button { } label: {
                    Label("Cut", systemImage: "scissors")
                }
                .disabled(true)
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .disabled(!canPaste)
            }
            Spacer(minLength: 0)
        }
        .onAppear { canPaste = LayerClipboard.hasContent }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            canPaste = LayerClipboard.hasContent
        }
    }

    private func pasteFromClipboard() {
        guard let pasted = LayerClipboard.paste(), !pasted.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            let inserted = project.addPastedLayers(pasted)
            if let top = inserted.last {
                session.selectLayer(top.uuid)
            }
        }
    }
}

// MARK: - Placeholder content states

private struct EmptySelectionContent: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.dashed")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary.opacity(0.7))
            VStack(spacing: 4) {
                Text("Nothing selected")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Tap a layer on the canvas, or add a shape, text, or image.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
    }
}
