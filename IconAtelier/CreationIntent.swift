import Foundation

enum CreationIntent: Hashable {
    case photo(Data)
    case prompt
    case symbol
    case text
}

struct ProjectRoute: Hashable {
    let projectUUID: UUID
    let intent: CreationIntent?
}
