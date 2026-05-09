import SwiftUI
import UIKit

@Observable
final class IconProject {
    var background: UIImage?
    var overlay: UIImage?

    var overlayOffset: CGSize = .zero
    var overlayScale: CGFloat = 1.0
    var overlayOpacity: Double = 1.0

    var backgroundPrompt: String = ""
    var overlayPrompt: String = ""

    var isGeneratingBackground = false
    var isGeneratingOverlay = false
    var lastError: String?
}
