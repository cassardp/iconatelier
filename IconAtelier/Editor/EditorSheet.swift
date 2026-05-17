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
            EditTabContent(project: project, session: session)
        } else {
            EmptySelectionContent()
        }
    }
}

// MARK: - Action rows (right-aligned, scrollable with content)

/// Layer-context actions (hide/show, duplicate, delete) rendered as
/// square `CompactActionButton`s aligned to the trailing edge, designed
/// to sit at the top of the sheet's scrollable content.
struct LayerActionsRow: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    let layer: Layer

    var body: some View {
        HStack(spacing: 8) {
            CompactActionButton(
                title: layer.isHidden ? "Show" : "Hide",
                systemImage: layer.isHidden ? "eye" : "eye.slash"
            ) {
                project.toggleVisibility(layer)
            }
            CompactActionButton(
                title: "Duplicate",
                systemImage: "square.on.square"
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    let copy = project.duplicate(layer)
                    session.selectLayer(copy.uuid)
                }
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
    }
}

struct BackgroundActionsRow: View {
    @Bindable var project: IconProject

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
                title: "Duplicate",
                systemImage: "square.on.square",
                enabled: false
            ) {}
            Spacer(minLength: 0)
            CompactActionButton(
                title: "Delete",
                systemImage: "trash",
                enabled: false
            ) {}
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
