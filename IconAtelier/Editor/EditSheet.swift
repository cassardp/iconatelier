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
