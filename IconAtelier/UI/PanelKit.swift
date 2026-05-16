import SwiftUI
import UIKit

// MARK: - Style tokens

enum PanelStyle {
    static let rowFill: Color = .primary.opacity(0.06)
    static let rowFillActive: Color = .primary.opacity(0.14)
    static let rowFillSelected: Color = .primary.opacity(0.28)
    static let cornerRadius: CGFloat = 12
    static let rowHeight: CGFloat = 52
    static let sliderHeight: CGFloat = 48
    static let rowInsetH: CGFloat = 16
}

extension Color {
    /// Page background sitting between `.systemBackground` (pure white) and
    /// `.secondarySystemBackground`, with an adaptive dark-mode counterpart.
    static let appPageBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.07, alpha: 1)
            : UIColor(white: 0.965, alpha: 1)
    })
}

// MARK: - Section divider

struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 4)
    }
}

// MARK: - Section container

struct PanelSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.smooth(duration: 0.28)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 6) {
                    content()
                }
                .padding(.top, 6)
                .transition(
                    .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                )
            }
        }
        .clipped()
    }
}

// MARK: - Compact icon-only action button

struct CompactActionButton: View {
    enum Role {
        case standard
        case destructive
    }

    let title: String
    let systemImage: String
    var role: Role = .standard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                        .fill(PanelStyle.rowFill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var iconColor: Color {
        role == .destructive ? .red : .primary
    }
}

// MARK: - Action row

struct ActionRow: View {
    enum Role {
        case standard
        case prominent
        case destructive
    }

    let title: String
    var enabled: Bool = true
    var role: Role = .standard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight)
                .padding(.horizontal, PanelStyle.rowInsetH)
                .background(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                        .fill(rowFill)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private var rowFill: Color {
        switch role {
        case .standard, .destructive:
            return PanelStyle.rowFill
        case .prominent:
            return .primary
        }
    }

    private var textColor: Color {
        switch role {
        case .destructive: return .red
        case .standard:    return .primary
        case .prominent:   return Color(uiColor: .systemBackground)
        }
    }
}

// MARK: - DialKit-style slider row with inline fill

struct DialSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: (Double) -> String
    var defaultValue: Double? = nil
    // When true, the slider position maps to value via a log curve over the
    // range, so equal screen distance covers equal multiplicative steps.
    // Required for exponent-like parameters (e.g. Gielis n1/n2/n3) whose
    // perceptually-interesting region spans several orders of magnitude.
    // Range must be strictly positive when enabled.
    var logarithmic: Bool = false
    let onBeginEditing: () -> Void

    private var safeValue: Double {
        value.isFinite ? value : (defaultValue ?? range.lowerBound)
    }

    private var useLog: Bool {
        logarithmic && range.lowerBound > 0 && range.upperBound > range.lowerBound
    }

    private var fraction: Double {
        if useLog {
            let logLow = Darwin.log(range.lowerBound)
            let logHigh = Darwin.log(range.upperBound)
            let logVal = Darwin.log(max(safeValue, range.lowerBound))
            return min(max((logVal - logLow) / (logHigh - logLow), 0), 1)
        }
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((safeValue - range.lowerBound) / span, 0), 1)
    }

    private var canReset: Bool {
        guard let d = defaultValue else { return false }
        let span = range.upperBound - range.lowerBound
        let epsilon = max(span * 0.001, 1e-6)
        return abs(safeValue - d) > epsilon
    }

    private func update(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let f = min(max(Double(x / width), 0), 1)
        if useLog {
            let logLow = Darwin.log(range.lowerBound)
            let logHigh = Darwin.log(range.upperBound)
            value = Darwin.exp(logLow + f * (logHigh - logLow))
            return
        }
        let span = range.upperBound - range.lowerBound
        value = range.lowerBound + f * span
    }

    private func performReset() {
        guard let d = defaultValue, canReset else { return }
        onBeginEditing()
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.smooth(duration: 0.2)) {
            value = d
        }
    }

    var body: some View {
        GeometryReader { geo in
            let shape = RoundedRectangle(
                cornerRadius: PanelStyle.cornerRadius,
                style: .continuous
            )

            ZStack(alignment: .leading) {
                shape
                    .fill(PanelStyle.rowFill)

                shape
                    .fill(PanelStyle.rowFillActive)
                    .frame(width: max(0, geo.size.width * fraction))

                HStack(spacing: 8) {
                    Text(label)
                        .foregroundStyle(.primary.opacity(0.72))
                    if defaultValue != nil {
                        Button(action: performReset) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(canReset ? 1 : 0.25)
                        .disabled(!canReset)
                        .accessibilityLabel("Reset \(label)")
                    }
                    Spacer()
                    Text(valueText(safeValue))
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.72))
                        .monospacedDigit()
                }
                .padding(.horizontal, PanelStyle.rowInsetH)
            }
            .contentShape(shape)
            .gesture(
                ScrollSafeHorizontalPan(
                    onBegan: { x in
                        onBeginEditing()
                        UISelectionFeedbackGenerator().selectionChanged()
                        update(at: x, width: geo.size.width)
                    },
                    onChanged: { x in
                        update(at: x, width: geo.size.width)
                    },
                    onEnded: {}
                )
            )
        }
        .frame(height: PanelStyle.sliderHeight)
    }
}

// MARK: - Scroll-friendly horizontal pan

struct ScrollSafeHorizontalPan: UIGestureRecognizerRepresentable {
    let onBegan: (CGFloat) -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onBegan: (CGFloat) -> Void = { _ in }
        var onChanged: (CGFloat) -> Void = { _ in }
        var onEnded: () -> Void = {}

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Ancestor pans (ScrollView, sheet drag-to-dismiss) are made to
            // require this recognizer to fail before they activate — so they
            // must not run simultaneously.
            false
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> AxisLockedPanRecognizer {
        let pan = AxisLockedPanRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: AxisLockedPanRecognizer, context: Context) {
        context.coordinator.onBegan = onBegan
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func handleUIGestureRecognizerAction(_ recognizer: AxisLockedPanRecognizer, context: Context) {
        guard let view = recognizer.view else { return }
        let x = recognizer.location(in: view).x
        switch recognizer.state {
        case .began: context.coordinator.onBegan(x)
        case .changed: context.coordinator.onChanged(x)
        case .ended, .cancelled, .failed: context.coordinator.onEnded()
        default: break
        }
    }
}

final class AxisLockedPanRecognizer: UIPanGestureRecognizer {
    private var didDecide = false
    private var didLinkAncestors = false

    override func reset() {
        super.reset()
        didDecide = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if !didLinkAncestors {
            didLinkAncestors = true
            linkAncestorPans()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard !didDecide, let v = view else { return }
        let t = translation(in: v)
        let dx = abs(t.x)
        let dy = abs(t.y)
        if max(dx, dy) > 4 {
            didDecide = true
            // Vertical motion → fail so the ScrollView's pan can scroll.
            if dy > dx { state = .failed }
        }
    }

    /// Make every pan recognizer up the view chain (ScrollView, sheet
    /// drag-to-dismiss, …) wait for this recognizer's verdict before they
    /// activate. Once we either succeed (horizontal) or fail (vertical),
    /// they react accordingly — they no longer steal vertical movement
    /// while we're tracking a horizontal slider drag.
    private func linkAncestorPans() {
        var ancestor: UIView? = view?.superview
        while let v = ancestor {
            for gr in v.gestureRecognizers ?? [] where gr is UIPanGestureRecognizer {
                gr.require(toFail: self)
            }
            ancestor = v.superview
        }
    }
}
