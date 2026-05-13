import SwiftUI
import UIKit

private struct SheetUserInterfaceStyleSetter: UIViewControllerRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIViewController(context: Context) -> StyleHostViewController {
        StyleHostViewController(style: style)
    }

    func updateUIViewController(_ vc: StyleHostViewController, context: Context) {
        vc.style = style
        vc.apply()
    }

    final class StyleHostViewController: UIViewController {
        var style: UIUserInterfaceStyle
        private var didApply = false

        init(style: UIUserInterfaceStyle) {
            self.style = style
            super.init(nibName: nil, bundle: nil)
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("not implemented") }

        override func willMove(toParent parent: UIViewController?) {
            super.willMove(toParent: parent)
            apply()
        }

        override func viewIsAppearing(_ animated: Bool) {
            super.viewIsAppearing(animated)
            apply()
        }

        func apply() {
            var top: UIViewController = self
            while let parent = top.parent {
                top = parent
            }
            guard top.presentingViewController != nil else { return }
            if top.overrideUserInterfaceStyle != style {
                top.overrideUserInterfaceStyle = style
            }
            didApply = true
        }
    }
}

extension View {
    /// Forces a specific `UIUserInterfaceStyle` on the sheet hosting this view,
    /// without propagating to the presenting window (no flash on the parent view).
    func sheetUserInterfaceStyle(_ style: UIUserInterfaceStyle) -> some View {
        background {
            SheetUserInterfaceStyleSetter(style: style)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}
