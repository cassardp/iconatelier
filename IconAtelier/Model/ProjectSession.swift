import SwiftUI

@MainActor
@Observable
final class ProjectSession {
    var selectedLayerUUID: UUID?
    var isBackgroundSelected: Bool = false
    var lassoSelectedLayerUUIDs: Set<UUID> = []

    /// True when at least two layers are simultaneously selected via lasso.
    var isMultiSelecting: Bool { lassoSelectedLayerUUIDs.count >= 2 }

    func selectLayer(_ uuid: UUID?) {
        selectedLayerUUID = uuid
        if uuid != nil { isBackgroundSelected = false }
        lassoSelectedLayerUUIDs = []
    }

    func selectBackground() {
        isBackgroundSelected = true
        lassoSelectedLayerUUIDs = []
    }

    func setLassoSelection(_ uuids: Set<UUID>) {
        lassoSelectedLayerUUIDs = uuids
        if !uuids.isEmpty {
            selectedLayerUUID = nil
            isBackgroundSelected = false
        }
    }

    func clearLassoSelection() {
        lassoSelectedLayerUUIDs = []
    }

    func isLayerSelected(_ uuid: UUID) -> Bool {
        if lassoSelectedLayerUUIDs.contains(uuid) { return true }
        return uuid == selectedLayerUUID && !isBackgroundSelected
    }
}
