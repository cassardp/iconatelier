import SwiftUI
import UIKit

struct EditTabContent: View {
    @Bindable var project: IconProject
    @Binding var promptText: String
    let isGenerating: Bool
    var promptFocused: FocusState<Bool>.Binding
    let onGenerate: (GenerationTarget) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let layer = project.selectedLayer {
                    transformSection(for: layer)
                    SectionDivider()
                    actionsRow(for: layer)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 14)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private var trimmedPrompt: String {
        promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canGenerate: Bool {
        !trimmedPrompt.isEmpty && !isGenerating
    }

    // MARK: - Generate

    @ViewBuilder
    private var generateSection: some View {
        PanelSection(title: "Generate") {
            promptRow

            ActionRow(
                title: project.background == nil ? "Generate background" : "Replace background",
                systemImage: "photo",
                enabled: canGenerate,
                role: .prominent
            ) {
                onGenerate(.background)
            }

            ActionRow(
                title: "Generate overlay",
                systemImage: "square.stack.3d.up",
                enabled: canGenerate
            ) {
                onGenerate(.overlay)
            }
        }
    }

    private var promptRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            TextField(
                "Describe an image…",
                text: $promptText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1 ... 4)
            .focused(promptFocused)
            .disabled(isGenerating)

            if isGenerating {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }

    // MARK: - Quick actions

    @ViewBuilder
    private func actionsRow(for layer: Layer) -> some View {
        HStack(spacing: 8) {
            CompactActionButton(
                title: layer.isHidden ? "Show" : "Hide",
                systemImage: layer.isHidden ? "eye" : "eye.slash"
            ) {
                project.toggleVisibility(layer)
            }
            CompactActionButton(
                title: "Duplicate",
                systemImage: "square.on.square"
            ) {
                project.duplicate(layer)
            }
            CompactActionButton(
                title: "Delete",
                systemImage: "trash",
                role: .destructive
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    project.remove(layer)
                }
            }
        }
    }

    // MARK: - Transform

    @ViewBuilder
    private func transformSection(for layer: Layer) -> some View {
        let isOverlay = layer.kind == .aiOverlay

        PanelSection(title: "Transform") {
            DialSliderRow(
                label: "Opacity",
                value: Binding(
                    get: { layer.opacity },
                    set: { layer.opacity = $0 }
                ),
                range: 0 ... 1,
                valueText: { String(format: "%.0f%%", $0 * 100) },
                onBeginEditing: { project.recordUndo() }
            )

            if isOverlay {
                DialSliderRow(
                    label: "Scale",
                    value: Binding(
                        get: { Double(layer.scale) },
                        set: { layer.scale = CGFloat($0) }
                    ),
                    range: 0.1 ... 5.0,
                    valueText: { String(format: "%.2f", $0) },
                    onBeginEditing: { project.recordUndo() }
                )

                DialSliderRow(
                    label: "Rotation",
                    value: Binding(
                        get: { layer.rotation.degrees },
                        set: { layer.rotation = .degrees($0) }
                    ),
                    range: -180 ... 180,
                    valueText: { String(format: "%.0f°", $0) },
                    onBeginEditing: { project.recordUndo() }
                )
            }
        }

        if isOverlay {
            SectionDivider()
            PanelSection(title: "Offset") {
                DialSliderRow(
                    label: "Offset X",
                    value: Binding(
                        get: { Double(layer.offset.width) },
                        set: { layer.offset.width = CGFloat($0) }
                    ),
                    range: -1.0 ... 1.0,
                    valueText: { String(format: "%+.2f", $0) },
                    onBeginEditing: { project.recordUndo() }
                )

                DialSliderRow(
                    label: "Offset Y",
                    value: Binding(
                        get: { Double(layer.offset.height) },
                        set: { layer.offset.height = CGFloat($0) }
                    ),
                    range: -1.0 ... 1.0,
                    valueText: { String(format: "%+.2f", $0) },
                    onBeginEditing: { project.recordUndo() }
                )
            }

            SectionDivider()
            PanelSection(title: "Shadow") {
                DialSliderRow(
                    label: "Opacity",
                    value: Binding(
                        get: { layer.shadowOpacity },
                        set: { layer.shadowOpacity = $0 }
                    ),
                    range: 0 ... 1,
                    valueText: { String(format: "%.0f%%", $0 * 100) },
                    onBeginEditing: { project.recordUndo() }
                )

                DialSliderRow(
                    label: "Blur",
                    value: Binding(
                        get: { Double(layer.shadowRadius) },
                        set: { layer.shadowRadius = CGFloat($0) }
                    ),
                    range: 0 ... 0.2,
                    valueText: { String(format: "%.0f%%", $0 * 100) },
                    onBeginEditing: { project.recordUndo() }
                )

                DialSliderRow(
                    label: "Offset X",
                    value: Binding(
                        get: { Double(layer.shadowOffsetX) },
                        set: { layer.shadowOffsetX = CGFloat($0) }
                    ),
                    range: -0.2 ... 0.2,
                    valueText: { String(format: "%+.2f", $0) },
                    onBeginEditing: { project.recordUndo() }
                )

                DialSliderRow(
                    label: "Offset Y",
                    value: Binding(
                        get: { Double(layer.shadowOffsetY) },
                        set: { layer.shadowOffsetY = CGFloat($0) }
                    ),
                    range: -0.2 ... 0.2,
                    valueText: { String(format: "%+.2f", $0) },
                    onBeginEditing: { project.recordUndo() }
                )
            }
        }
    }

}

// MARK: - Section divider

private struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 4)
    }
}

// MARK: - Panel style tokens

private enum PanelStyle {
    static let rowFill: Color = .primary.opacity(0.06)
    static let rowFillActive: Color = .primary.opacity(0.14)
    static let cornerRadius: CGFloat = 12
    static let rowHeight: CGFloat = 52
    static let sliderHeight: CGFloat = 48
    static let rowInsetH: CGFloat = 16
}

// MARK: - Section container

private struct PanelSection<Content: View>: View {
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

// MARK: - Compact icon+label action button

private struct CompactActionButton: View {
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

private struct ActionRow: View {
    enum Role {
        case standard
        case prominent
        case destructive
    }

    let title: String
    let systemImage: String
    var enabled: Bool = true
    var role: Role = .standard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                Text(title)
                    .foregroundStyle(textColor)
                Spacer()
            }
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
            return Color.accentColor.opacity(0.25)
        }
    }

    private var textColor: Color {
        switch role {
        case .destructive: return .red
        case .standard, .prominent: return .primary
        }
    }

    private var iconColor: Color {
        switch role {
        case .destructive: return .red
        case .standard: return .secondary
        case .prominent: return .accentColor
        }
    }
}

// MARK: - DialKit-style slider row with inline fill

private struct DialSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: (Double) -> String
    let onBeginEditing: () -> Void

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    private func update(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let f = min(max(Double(x / width), 0), 1)
        let span = range.upperBound - range.lowerBound
        value = range.lowerBound + f * span
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

                HStack {
                    Text(label)
                        .foregroundStyle(.primary.opacity(0.72))
                    Spacer()
                    Text(valueText(value))
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

private struct ScrollSafeHorizontalPan: UIGestureRecognizerRepresentable {
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
