import SwiftUI

enum EditorTab: String, Hashable, CaseIterable, Identifiable {
    case layers
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .layers: "Layers"
        case .tools: "Tools"
        }
    }

    var symbol: String {
        switch self {
        case .layers: "square.3.stack.3d"
        case .tools: "slider.horizontal.3"
        }
    }
}

enum LayerTool: String, Hashable, CaseIterable, Identifiable {
    case move
    case scale
    case rotate
    case opacity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: "Move"
        case .scale: "Scale"
        case .rotate: "Rotate"
        case .opacity: "Opacity"
        }
    }

    var symbol: String {
        switch self {
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .scale: "arrow.up.left.and.arrow.down.right"
        case .rotate: "arrow.clockwise"
        case .opacity: "drop.fill"
        }
    }
}
