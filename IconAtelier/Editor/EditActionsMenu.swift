import SwiftUI

struct EditActionsMenu: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    @Binding var showImportPicker: Bool
    let presentExport: () -> Void
    let deleteProject: () -> Void

    var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder
    private var menuContent: some View {
        Button {
            presentExport()
        } label: {
            Label("Export Icon", systemImage: "square.and.arrow.up")
        }
        .disabled(!project.hasContent)

        Divider()

        Button {
            withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
                let layer = project.addSilhouetteLayer()
                session.selectLayer(layer.uuid)
            }
        } label: {
            Label("Add App Silhouette", systemImage: "app.fill")
        }

        Button {
            showImportPicker = true
        } label: {
            Label("Import Image", systemImage: "square.and.arrow.down")
        }

        Divider()

        Button(role: .destructive) {
            deleteProject()
        } label: {
            Label("Delete Icon", systemImage: "trash")
        }
    }
}
