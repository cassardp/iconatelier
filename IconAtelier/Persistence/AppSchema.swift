import SwiftData

// Single-version schema. No migrations: the only installation is the
// developer's own device, and any schema change is paired with a fresh
// install.
enum AppSchema {
    static var models: [any PersistentModel.Type] {
        [IconProject.self, Background.self, Layer.self]
    }
}
