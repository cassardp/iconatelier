import SwiftUI

@MainActor
@Observable
final class ProjectSession {
    var selectedLayerUUID: UUID?
    var isBackgroundSelected: Bool = false

    func selectLayer(_ uuid: UUID?) {
        selectedLayerUUID = uuid
        if uuid != nil { isBackgroundSelected = false }
    }

    func selectBackground() {
        isBackgroundSelected = true
    }
}
