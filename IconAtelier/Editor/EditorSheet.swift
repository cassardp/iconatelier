import SwiftUI

struct EditSheet: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    var body: some View {
        Group {
            if session.isBackgroundSelected {
                BackgroundEditorContent(project: project, session: session)
            } else {
                EditTabContent(project: project, session: session)
            }
        }
        .sheetUserInterfaceStyle(.dark)
        .presentationBackground(Color(.systemBackground))
    }
}
