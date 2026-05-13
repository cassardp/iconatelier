import Foundation
import SwiftUI
import PhotosUI

enum CreationIntent: Hashable {
    case photo(PhotosPickerItem)
    case prompt
    case voice(String)
    case symbol
    case text
}

struct ProjectRoute: Hashable {
    let projectUUID: UUID
    let intent: CreationIntent?
}
