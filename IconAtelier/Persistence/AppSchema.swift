import SwiftData

// MARK: - Versioned schema baseline
//
// V1 captures the current shipping schema (post `Layer.storedShadowColor`).
// The `@Model` classes themselves stay top-level in `Layer.swift`,
// `Background.swift`, and `IconProject.swift` so the store keeps the same
// entity signature it was created with — only the version marker changes.
//
// When the next schema modification lands, add an `AppSchemaV2` describing
// the new shape and a `MigrationStage` (lightweight when only adding
// optional/defaulted properties; custom otherwise). Never add or remove a
// stored property on a `@Model` class without bumping this version first —
// SwiftData wipes silently otherwise.

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [IconProject.self, Background.self, Layer.self]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
