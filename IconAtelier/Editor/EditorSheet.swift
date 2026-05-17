import SwiftUI
import UIKit

struct EditSheet: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    let onBooleanOp: (BooleanOpKind) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PeekActionHeader(
                project: project,
                session: session,
                onBooleanOp: onBooleanOp
            )
            content
        }
        .sheetUserInterfaceStyle(.dark)
        .presentationBackground(Color(.systemBackground))
    }

    @ViewBuilder
    private var content: some View {
        if session.isMultiSelecting {
            // Boolean ops live entirely in the peek header — keep the sheet
            // body intentionally empty so nothing competes for attention.
            Color.clear
        } else if session.isBackgroundSelected {
            BackgroundEditorContent(project: project, session: session)
        } else if project.layer(withID: session.selectedLayerUUID) != nil {
            EditTabContent(project: project, session: session)
        } else {
            EmptySelectionContent()
        }
    }
}

// MARK: - Peek action header

private struct PeekActionHeader: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    let onBooleanOp: (BooleanOpKind) -> Void

    var body: some View {
        HStack(spacing: 14) {
            if session.isMultiSelecting {
                booleanButtons
            } else if session.isBackgroundSelected {
                backgroundButtons
            } else if let layer = selectedLayer {
                layerButtons(for: layer)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .padding(.horizontal, 16)
    }

    private var selectedLayer: Layer? {
        project.layer(withID: session.selectedLayerUUID)
    }

    @ViewBuilder
    private func layerButtons(for layer: Layer) -> some View {
        PeekActionButton(
            symbol: layer.isHidden ? "eye" : "eye.slash",
            label: layer.isHidden ? "Show" : "Hide"
        ) {
            project.toggleVisibility(layer)
        }
        PeekActionButton(symbol: "square.on.square", label: "Duplicate") {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                let copy = project.duplicate(layer)
                session.selectLayer(copy.uuid)
            }
        }
        PeekActionButton(symbol: "trash", label: "Delete") {
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

    @ViewBuilder
    private var backgroundButtons: some View {
        let background = project.safeBackground
        PeekActionButton(
            symbol: background.isHidden ? "eye" : "eye.slash",
            label: background.isHidden ? "Show" : "Hide"
        ) {
            project.recordUndo()
            background.isHidden.toggle()
        }
    }

    @ViewBuilder
    private var booleanButtons: some View {
        PeekActionButton(symbol: "plus", label: "Union") {
            onBooleanOp(.union)
        }
        PeekActionButton(symbol: "circle.righthalf.filled", label: "Intersect") {
            onBooleanOp(.intersect)
        }
        PeekActionButton(symbol: "minus", label: "Subtract") {
            onBooleanOp(.subtract)
        }
    }
}

private struct PeekActionButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                .background(PanelStyle.rowFillActive, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
