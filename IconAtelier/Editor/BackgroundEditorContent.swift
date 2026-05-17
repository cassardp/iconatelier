import SwiftUI

struct BackgroundEditorContent: View {
    @Bindable var project: IconProject
    let session: ProjectSession

    var body: some View {
        @Bindable var background = project.safeBackground
        ScrollView {
            VStack(spacing: 18) {
                BackgroundActionsRow(project: project, session: session)
                SectionDivider()
                PaintEditor(
                    paint: Binding(
                        get: { background.paint },
                        set: { background.paint = $0 }
                    ),
                    onBeginEditing: { project.recordUndo() }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 14)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }
}
