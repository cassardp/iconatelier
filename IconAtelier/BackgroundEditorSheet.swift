import SwiftUI
import UIKit

struct BackgroundEditorContent: View {
    @Bindable var project: IconProject
    @Binding var aiPromptText: String
    let isGenerating: Bool
    var promptFocused: FocusState<Bool>.Binding
    let onGenerate: () -> Void

    var body: some View {
        @Bindable var background = project.safeBackground
        ScrollView {
            VStack(spacing: 18) {
                kindPicker(for: background)
                SectionDivider()
                kindControls(for: background)
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 14)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    // MARK: - Kind picker

    @ViewBuilder
    private func kindPicker(for background: Background) -> some View {
        PanelSection(title: "Background type") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BackgroundKind.allCases) { kind in
                        KindButton(
                            kind: kind,
                            isSelected: background.kind == kind,
                            action: {
                                project.recordUndo()
                                background.kind = kind
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Per-kind controls

    @ViewBuilder
    private func kindControls(for background: Background) -> some View {
        switch background.kind {
        case .solid:
            PanelSection(title: "Color") {
                BackgroundColorRow(
                    title: "Fill",
                    color: Binding(
                        get: { background.solidColor },
                        set: {
                            project.recordUndo()
                            background.solidColor = $0
                        }
                    ),
                    project: project
                )
            }
        case .linearGradient:
            linearPresetsSection(for: background)
            SectionDivider()
            gradientStopsSection(for: background)
            SectionDivider()
            linearDirectionSection(for: background)
        case .radialGradient:
            radialPresetsSection(for: background)
            SectionDivider()
            gradientStopsSection(for: background)
        case .meshGradient:
            meshPresetsSection(for: background)
            SectionDivider()
            meshCornersSection(for: background)
        case .ai:
            aiSection(for: background)
        }
    }

    // MARK: - Presets sections

    private func linearPresetsSection(for background: Background) -> some View {
        PanelSection(title: "Presets") {
            BackgroundPresetsRow(
                presets: BackgroundPresets.linear,
                thumbnail: { preset in
                    LinearGradient(colors: preset.colors, startPoint: preset.start, endPoint: preset.end)
                },
                onSelect: { preset in
                    project.recordUndo()
                    background.gradientColors = preset.colors
                    background.linearStart = preset.start
                    background.linearEnd = preset.end
                }
            )
        }
    }

    private func radialPresetsSection(for background: Background) -> some View {
        PanelSection(title: "Presets") {
            BackgroundPresetsRow(
                presets: BackgroundPresets.radial,
                thumbnail: { preset in
                    RadialGradient(colors: preset.colors,
                                   center: .center,
                                   startRadius: 0,
                                   endRadius: 38)
                },
                onSelect: { preset in
                    project.recordUndo()
                    background.gradientColors = preset.colors
                }
            )
        }
    }

    private func meshPresetsSection(for background: Background) -> some View {
        PanelSection(title: "Presets") {
            BackgroundPresetsRow(
                presets: BackgroundPresets.mesh,
                thumbnail: { preset in
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: [
                            .init(0, 0),   .init(0.5, 0),   .init(1, 0),
                            .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                            .init(0, 1),   .init(0.5, 1),   .init(1, 1),
                        ],
                        colors: preset.meshColors
                    )
                },
                onSelect: { preset in
                    project.recordUndo()
                    background.meshColors = preset.meshColors
                }
            )
        }
    }

    private func gradientStopsSection(for background: Background) -> some View {
        PanelSection(title: "Colors") {
            ForEach(background.gradientColors.indices, id: \.self) { idx in
                BackgroundColorRow(
                    title: "Stop \(idx + 1)",
                    color: Binding(
                        get: { background.gradientColors[idx] },
                        set: {
                            project.recordUndo()
                            background.gradientColors[idx] = $0
                        }
                    ),
                    project: project
                )
            }
        }
    }

    @ViewBuilder
    private func linearDirectionSection(for background: Background) -> some View {
        PanelSection(title: "Direction") {
            HStack(spacing: 8) {
                ForEach(LinearDirection.allCases) { direction in
                    DirectionButton(
                        direction: direction,
                        isSelected: direction.matches(start: background.linearStart, end: background.linearEnd),
                        action: {
                            project.recordUndo()
                            background.linearStart = direction.start
                            background.linearEnd = direction.end
                        }
                    )
                }
            }
        }
    }

    private func meshCornersSection(for background: Background) -> some View {
        PanelSection(title: "Corners") {
            BackgroundColorRow(
                title: "Top-left",
                color: meshBinding(for: background, index: 0),
                project: project
            )
            BackgroundColorRow(
                title: "Top-right",
                color: meshBinding(for: background, index: 2),
                project: project
            )
            BackgroundColorRow(
                title: "Bottom-left",
                color: meshBinding(for: background, index: 6),
                project: project
            )
            BackgroundColorRow(
                title: "Bottom-right",
                color: meshBinding(for: background, index: 8),
                project: project
            )
        }
    }

    private func meshBinding(for background: Background, index: Int) -> Binding<Color> {
        Binding(
            get: { background.meshColors[index] },
            set: { newColor in
                project.recordUndo()
                background.meshColors[index] = newColor
                // Re-interpolate the 5 non-corner cells from the 4 corners.
                let tl = background.meshColors[0]
                let tr = background.meshColors[2]
                let bl = background.meshColors[6]
                let br = background.meshColors[8]
                background.meshColors[1] = Color.mix(tl, tr, 0.5)
                background.meshColors[3] = Color.mix(tl, bl, 0.5)
                background.meshColors[5] = Color.mix(tr, br, 0.5)
                background.meshColors[7] = Color.mix(bl, br, 0.5)
                background.meshColors[4] = Color.mix(
                    Color.mix(tl, tr, 0.5),
                    Color.mix(bl, br, 0.5),
                    0.5
                )
            }
        )
    }

    @ViewBuilder
    private func aiSection(for background: Background) -> some View {
        PanelSection(title: "Prompt ideas") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BackgroundPresets.aiPrompts) { preset in
                        Button {
                            aiPromptText = preset.prompt
                        } label: {
                            Text(preset.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary.opacity(0.72))
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                                        .fill(PanelStyle.rowFill)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isGenerating)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }

        SectionDivider()

        PanelSection(title: "AI image") {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                TextField(
                    "Describe a background…",
                    text: $aiPromptText,
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

            ActionRow(
                title: background.aiImage == nil ? "Generate" : "Replace",
                enabled: !aiPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !isGenerating,
                role: .prominent
            ) {
                onGenerate()
            }
        }
    }
}

// MARK: - Kind button (icon-only chip)

private struct KindButton: View {
    let kind: BackgroundKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(kind.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary.opacity(isSelected ? 1.0 : 0.72))
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                        .fill(isSelected ? PanelStyle.rowFillSelected : PanelStyle.rowFill)
                )
        }
        .buttonStyle(.plain)
    }
}

private extension BackgroundKind {
    var label: String {
        switch self {
        case .solid:          return "Solid"
        case .linearGradient: return "Linear"
        case .radialGradient: return "Radial"
        case .meshGradient:   return "Mesh"
        case .ai:             return "AI Generated"
        }
    }
}

// MARK: - Linear direction

private enum LinearDirection: String, CaseIterable, Identifiable {
    case topToBottom, leftToRight, topLeftToBottomRight, topRightToBottomLeft

    var id: String { rawValue }

    var start: UnitPoint {
        switch self {
        case .topToBottom:           return .top
        case .leftToRight:           return .leading
        case .topLeftToBottomRight:  return .topLeading
        case .topRightToBottomLeft:  return .topTrailing
        }
    }

    var end: UnitPoint {
        switch self {
        case .topToBottom:           return .bottom
        case .leftToRight:           return .trailing
        case .topLeftToBottomRight:  return .bottomTrailing
        case .topRightToBottomLeft:  return .bottomLeading
        }
    }

    var systemImage: String {
        switch self {
        case .topToBottom:          return "arrow.down"
        case .leftToRight:          return "arrow.right"
        case .topLeftToBottomRight: return "arrow.down.right"
        case .topRightToBottomLeft: return "arrow.down.left"
        }
    }

    func matches(start: UnitPoint, end: UnitPoint) -> Bool {
        approximatelyEqual(start, self.start) && approximatelyEqual(end, self.end)
    }

    private func approximatelyEqual(_ a: UnitPoint, _ b: UnitPoint) -> Bool {
        abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01
    }
}

private struct DirectionButton: View {
    let direction: LinearDirection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.systemImage)
                .font(.title3)
                .foregroundStyle(.primary.opacity(isSelected ? 1.0 : 0.72))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                        .fill(isSelected ? PanelStyle.rowFillSelected : PanelStyle.rowFill)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color row (background-flavored copy with bigger swatch)

private struct BackgroundColorRow: View {
    let title: String
    @Binding var color: Color
    let project: IconProject

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "paintpalette")
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(.primary.opacity(0.72))
            Spacer()
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                .fill(PanelStyle.rowFill)
        )
    }
}
