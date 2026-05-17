import SwiftUI
import UIKit

// MARK: - Style tokens

enum PanelStyle {
    static let rowFill: Color = .primary.opacity(0.08)
    static let rowFillActive: Color = .primary.opacity(0.14)
    static let cornerRadius: CGFloat = 12
    static let rowHeight: CGFloat = 52
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
            .fill(Color.primary.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 4)
    }
}

// MARK: - Section container

struct PanelSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary.opacity(0.8))
                .padding(.horizontal, 4)

            VStack(spacing: 7) {
                content()
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Compact icon-only action button

/// Square icon-only button sized to align with the PanelKit row height
/// (52pt) and using the same `rowFill` background as `ActionRow`,
/// `DialSliderRow`, and friends — so it sits naturally alongside other
/// rows when grouped in an `HStack`.
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
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: PanelStyle.rowHeight, height: PanelStyle.rowHeight)
                .background(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                        .fill(PanelStyle.rowFill)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
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

// MARK: - Toggle

/// Custom on/off switch matched to PanelKit tokens. Sits in a single row pill
/// so it visually belongs with `DialSliderRow` and `PanelSegmentedRow`.
struct PanelToggle: View {
    @Binding var isOn: Bool

    private let trackWidth: CGFloat = 46
    private let trackHeight: CGFloat = 28
    private let knobInset: CGFloat = 3

    var body: some View {
        let knobSize = trackHeight - knobInset * 2
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? PanelStyle.rowFillActive : PanelStyle.rowFill)
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.primary.opacity(isOn ? 0.9 : 0.4))
                    .frame(width: knobSize, height: knobSize)
                    .padding(.horizontal, knobInset)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
    }
}

/// Labeled row that hosts a `PanelToggle`. Mirrors the chrome of
/// `DialSliderRow` so toggle parameters slot into the same vertical rhythm.
struct PanelToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            PanelToggle(isOn: $isOn)
        }
        .padding(.horizontal, PanelStyle.rowInsetH)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Segmented control

/// Generic segmented control with an animated selection pill. Use when the
/// option set is small (2–5 items) and equally weighted. For longer lists,
/// prefer `PanelMenuRow`.
struct PanelSegmentedControl<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var onChange: (() -> Void)? = nil

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { value in
                segment(for: value)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }

    @ViewBuilder
    private func segment(for value: Value) -> some View {
        let isSelected = selection == value
        let innerRadius = PanelStyle.cornerRadius - 3

        Button {
            guard selection != value else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            onChange?()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selection = value
            }
        } label: {
            Text(label(value))
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(.primary.opacity(isSelected ? 1.0 : 0.72))
                .frame(maxWidth: .infinity)
                .frame(height: PanelStyle.rowHeight - 6)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                            .fill(PanelStyle.rowFillActive)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu (standalone, full-width)

/// Standalone pop-up menu shaped as a full-width row, without a separate
/// left-side label. Use when the current value is self-evident (a font
/// family showing "Serif" speaks for itself) and an extra label would
/// just take vertical space.
struct PanelMenu<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let optionLabel: (Value) -> String
    var onChange: (() -> Void)? = nil

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { value in
                Button {
                    guard selection != value else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    onChange?()
                    selection = value
                } label: {
                    if value == selection {
                        Label(optionLabel(value), systemImage: "checkmark")
                    } else {
                        Text(optionLabel(value))
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(optionLabel(selection))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, PanelStyle.rowInsetH)
            .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                    .fill(PanelStyle.rowFill)
            )
            .contentShape(
                RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
            )
        }
        .menuOrder(.fixed)
        .tint(.primary)
    }
}

// MARK: - Menu row

/// Labeled row hosting a native pop-up menu. Use when the choice list is too
/// long for a segmented control (5+ items) or when the values benefit from
/// being shown one-per-line.
struct PanelMenuRow<Value: Hashable>: View {
    let label: String
    let options: [Value]
    @Binding var selection: Value
    let optionLabel: (Value) -> String
    var onChange: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { value in
                    Button {
                        guard selection != value else { return }
                        UISelectionFeedbackGenerator().selectionChanged()
                        onChange?()
                        selection = value
                    } label: {
                        if value == selection {
                            Label(optionLabel(value), systemImage: "checkmark")
                        } else {
                            Text(optionLabel(value))
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(optionLabel(selection))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: PanelStyle.rowHeight - 16)
                .background(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius - 3, style: .continuous)
                        .fill(PanelStyle.rowFillActive)
                )
            }
            .menuOrder(.fixed)
            .tint(.primary)
        }
        .padding(.horizontal, PanelStyle.rowInsetH)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }
}

// MARK: - Color picker row

/// Labeled row wrapping a native `ColorPicker`. Mirrors the chrome of
/// the other panel rows so color editing slots into the same vertical rhythm.
struct ColorPickerRow: View {
    let title: String
    @Binding var color: Color
    var supportsOpacity: Bool = false
    var onChange: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            ColorPicker(
                "",
                selection: Binding(
                    get: { color },
                    set: { newColor in
                        onChange?()
                        color = newColor
                    }
                ),
                supportsOpacity: supportsOpacity
            )
            .labelsHidden()
        }
        .padding(.horizontal, PanelStyle.rowInsetH)
        .frame(maxWidth: .infinity, minHeight: PanelStyle.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
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
                        .foregroundStyle(.primary)
                    if defaultValue != nil, canReset {
                        Button(action: performReset) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Reset \(label)")
                        .transition(.opacity)
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
        .frame(height: PanelStyle.rowHeight)
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
