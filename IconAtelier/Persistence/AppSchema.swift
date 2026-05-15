import SwiftData

// MARK: - Versioned schema baseline

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [IconProject.self, Background.self, Layer.self]
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [IconProject.self, Background.self, Layer.self]
    }
}

// V3 drops the AI-generation and SF-Symbol layer surface. Removed stored
// properties: Layer.symbolName, Layer.sourcePrompt, Background.aiImagePNG,
// Background.aiPrompt. LayerKind.aiOverlay and LayerKind.symbol cases removed
// (existing rows fall back to LayerKind.image via the rawValue init's nil
// fallback). BackgroundKind.ai case removed (rows fall back to .meshGradient).
// Lightweight migration is sufficient since SwiftData drops orphaned columns.
enum AppSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [IconProject.self, Background.self, Layer.self]
    }
}

// V4 adds shape-level styling on Layer: cornerRadius, borderWidth, and
// storedBorderColor. All three are new stored properties with defaults
// (0, 0, white) → lightweight migration applies.
enum AppSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [IconProject.self, Background.self, Layer.self]
    }
}

// V5 adds Layer.borderPositionRaw with a default of "center" → lightweight.
enum AppSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [IconProject.self, Background.self, Layer.self]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self, AppSchemaV3.self, AppSchemaV4.self, AppSchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self),
            .lightweight(fromVersion: AppSchemaV2.self, toVersion: AppSchemaV3.self),
            .lightweight(fromVersion: AppSchemaV3.self, toVersion: AppSchemaV4.self),
            .lightweight(fromVersion: AppSchemaV4.self, toVersion: AppSchemaV5.self)
        ]
    }
}
