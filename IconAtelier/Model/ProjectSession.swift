import SwiftUI

enum SnapMode: CaseIterable {
    case guides
    case grid
    case free

    var next: SnapMode {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var systemImage: String {
        switch self {
        case .guides: "square.dashed"
        case .grid: "grid"
        case .free: "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    var label: String {
        switch self {
        case .guides: "Snap to guides"
        case .grid: "Snap to grid"
        case .free: "Free move"
        }
    }

    var isAssisted: Bool { self != .free }
}

@MainActor
@Observable
final class ProjectSession {
    var selectedLayerUUID: UUID?
    var isBackgroundSelected: Bool = false
    var lassoSelectedLayerUUIDs: Set<UUID> = []
    var snapMode: SnapMode = .guides

    var isMultiSelecting: Bool { lassoSelectedLayerUUIDs.count >= 2 }

    func cycleSnapMode() {
        snapMode = snapMode.next
    }

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
