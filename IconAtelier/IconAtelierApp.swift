import SwiftUI

@main
struct IconAtelierApp: App {
    @State private var store = ProjectStore()
    @State private var presetStore = PresetStore()

    var body: some Scene {
        WindowGroup {
            GalleryView()
                .fontDesign(.rounded)
                .preferredColorScheme(.light)
                .environment(store)
                .environment(presetStore)
        }
    }
}
