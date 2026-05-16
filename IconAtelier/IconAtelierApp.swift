import SwiftUI
import SwiftData

@main
struct IconAtelierApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: IconProject.self, Background.self, Layer.self
            )
        } catch {
            print("⛔️ SwiftData ModelContainer init failed: \(error)")
            dump(error)
            fatalError("Failed to set up SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            GalleryView()
                .fontDesign(.rounded)
        }
        .modelContainer(container)
    }
}
