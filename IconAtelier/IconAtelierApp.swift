import SwiftUI
import SwiftData

@main
struct IconAtelierApp: App {
    var body: some Scene {
        WindowGroup {
            GalleryView()
                .fontDesign(.rounded)
        }
        .modelContainer(for: [
            IconProject.self,
            Background.self,
            Layer.self
        ])
    }
}
