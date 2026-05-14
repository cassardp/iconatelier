import Foundation
import SwiftUI
import PhotosUI

enum CreationIntent: Hashable {
    case photo(PhotosPickerItem)
    case prompt(String)
    case symbol
}

struct ProjectRoute: Hashable {
    let projectUUID: UUID
    let intent: CreationIntent?
}
