import SwiftUI

@main
struct IconAtelierApp: App {
    @State private var store = ProjectStore()

    var body: some Scene {
        WindowGroup {
            GalleryView()
                .fontDesign(.rounded)
                .environment(store)
        }
    }
}
