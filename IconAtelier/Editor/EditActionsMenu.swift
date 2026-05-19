import SwiftUI

struct EditActionsMenu: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    @Binding var showImportPicker: Bool
    let presentExport: () -> Void

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
            withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
                let layer = project.addShapeLayer(spec: .iosSquircle)
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

        Button {
            presentExport()
        } label: {
            Label("Export Icon", systemImage: "square.and.arrow.up")
        }
        .disabled(!project.hasContent)
    }
}
