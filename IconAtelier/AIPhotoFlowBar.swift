import SwiftUI
import PhotosUI
import UIKit

// MARK: - Options

struct AIFlowOption: Identifiable, Hashable {
    let id: String
    let label: String
    let promptFragment: String
    let color: Color

    init(id: String, label: String, promptFragment: String? = nil, color: Color) {
        self.id = id
        self.label = label
        self.promptFragment = promptFragment ?? label
        self.color = color
    }
}

// MARK: - Seed

enum AIFlowSeed: Equatable {
    case photo(UIImage)
    case prompt(String)
}

// MARK: - Bar

struct AIPhotoFlowBar: View {
    let isGenerating: Bool
    @Binding var seed: AIFlowSeed?
    let onGenerate: (AIFlowSeed, AIFlowOption, AIFlowOption) -> Void
    let onAddSymbol: () -> Void
    let onAddText: () -> Void
    let onAddPrompt: () -> Void
    let onAddVoice: () -> Void

    @State private var selectedStyle: AIFlowOption?
    @State private var selectedAngle: AIFlowOption?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker: Bool = false

    static let styles: [AIFlowOption] = [
        .init(
            id: "flat-vector",
            label: "Flat Vector",
            promptFragment: "flat vector illustration, clean shapes, smooth gradients, sharp crisp edges",
            color: Color(red: 0.20, green: 0.50, blue: 0.95)
        ),
        .init(
            id: "flat-mono",
            label: "Flat Mono",
            promptFragment: "flat monochrome vector silhouette filled with pure solid white (#FFFFFF) only, no shading, no gradients, no outline, no border, fully transparent background, designed to be tintable",
            color: Color(red: 0.30, green: 0.30, blue: 0.35)
        ),
        .init(
            id: "sketch-to-logo",
            label: "Sketch to Logo",
            promptFragment: "transformed into a clean geometric vector logo, refined balanced shapes, professional brand mark",
            color: Color(red: 0.55, green: 0.40, blue: 0.80)
        ),
        .init(
            id: "line-art",
            label: "Line Art",
            promptFragment: "clean line art, thin even strokes, outline only, no fill, minimal elegant",
            color: Color(red: 0.15, green: 0.55, blue: 0.65)
        ),
        .init(
            id: "glyph",
            label: "Glyph",
            promptFragment: "solid silhouette glyph pictogram, single color, system icon style",
            color: Color(red: 0.40, green: 0.45, blue: 0.55)
        ),
        .init(
            id: "3d-render",
            label: "3D Render",
            promptFragment: "3D rendered icon, soft studio lighting, smooth glossy surfaces, modern app icon",
            color: Color(red: 1.00, green: 0.55, blue: 0.00)
        ),
        .init(
            id: "pixar",
            label: "Pixar",
            promptFragment: "expressive 3D cartoon character, soft warm cinematic lighting, Pixar-like animated film look",
            color: Color(red: 1.00, green: 0.75, blue: 0.20)
        ),
        .init(
            id: "clay",
            label: "Claymation",
            promptFragment: "claymation style, soft modeling clay, tactile sculpted texture",
            color: Color(red: 0.82, green: 0.42, blue: 0.30)
        ),
        .init(
            id: "isometric",
            label: "Isometric",
            promptFragment: "isometric illustration, 3D axonometric perspective, clean vector",
            color: Color(red: 0.30, green: 0.45, blue: 0.85)
        ),
        .init(
            id: "sticker",
            label: "Sticker",
            promptFragment: "sticker with thick white outline and soft drop shadow",
            color: Color(red: 1.00, green: 0.35, blue: 0.40)
        ),
        .init(
            id: "pixel-art",
            label: "Pixel Art",
            promptFragment: "16-bit pixel art, crisp pixels, retro game icon",
            color: Color(red: 0.20, green: 0.65, blue: 0.55)
        ),
        .init(
            id: "paper-cut",
            label: "Paper Cut",
            promptFragment: "layered paper cut illustration, stacked colored paper, soft shadows between layers",
            color: Color(red: 0.95, green: 0.65, blue: 0.40)
        ),
        .init(
            id: "gradient-mesh",
            label: "Gradient Mesh",
            promptFragment: "smooth gradient mesh, vibrant glossy colors, modern app icon",
            color: Color(red: 0.95, green: 0.30, blue: 0.65)
        )
    ]

    static let angles: [AIFlowOption] = [
        .init(id: "front",         label: "Front",     color: Color(red: 0.40, green: 0.45, blue: 0.55)),
        .init(id: "three-quarter", label: "3/4 view",  color: Color(red: 0.25, green: 0.60, blue: 0.70)),
        .init(id: "side",          label: "Side",      color: Color(red: 0.40, green: 0.65, blue: 0.35)),
        .init(id: "top-down",      label: "Top-down",  color: Color(red: 0.95, green: 0.55, blue: 0.20)),
        .init(id: "low-angle",     label: "Low angle", color: Color(red: 0.85, green: 0.30, blue: 0.35)),
        .init(id: "isometric",     label: "Isometric", color: Color(red: 0.30, green: 0.45, blue: 0.85))
    ]

    private enum Step: Hashable { case seed, style, angle, ready }

    private var step: Step {
        if seed == nil { return .seed }
        if selectedStyle == nil { return .style }
        if selectedAngle == nil { return .angle }
        return .ready
    }

    private var canSubmit: Bool { step == .ready && !isGenerating }

    private var createItems: [CreateActionItem] {
        [
            CreateActionItem(
                id: "photo",
                label: "Photo",
                systemImage: "camera.fill",
                color: .primary,
                action: { showPhotosPicker = true }
            ),
            CreateActionItem(
                id: "prompt",
                label: "Prompt",
                systemImage: "wand.and.stars",
                color: .primary,
                action: onAddPrompt
            ),
            CreateActionItem(
                id: "voice",
                label: "Voice",
                systemImage: "mic.fill",
                color: .primary,
                action: onAddVoice
            ),
            CreateActionItem(
                id: "symbol",
                label: "Symbol",
                systemImage: "star.fill",
                color: .primary,
                action: onAddSymbol
            ),
            CreateActionItem(
                id: "text",
                label: "Text",
                systemImage: "textformat",
                color: .primary,
                action: onAddText
            )
        ]
    }

    var body: some View {
        Group {
            if step == .seed {
                CreateRadialMenu(items: createItems)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else {
                fullBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: step)
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $pickerItems,
            maxSelectionCount: 1,
            matching: .images
        )
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhoto(items) }
        }
    }

    // MARK: - Full bar (summary + carousel/send)

    private var fullBar: some View {
        VStack(spacing: 10) {
            summary

            Group {
                switch step {
                case .seed:
                    EmptyView()
                case .style:
                    carousel(title: "Pick a style", options: Self.styles) { selectedStyle = $0 }
                case .angle:
                    carousel(title: "Pick an angle", options: Self.angles) { selectedAngle = $0 }
                case .ready:
                    sendButton
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Summary strip

    private var summary: some View {
        HStack(spacing: 8) {
            seedView

            if let style = selectedStyle {
                chip(label: style.label, color: style.color) {
                    selectedStyle = nil
                    selectedAngle = nil
                }
            }

            if let angle = selectedAngle {
                chip(label: angle.label, color: angle.color) {
                    selectedAngle = nil
                }
            }

            Spacer(minLength: 0)

            Button { reset() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)
            .opacity(isGenerating ? 0.4 : 1)
            .accessibilityLabel("Reset flow")
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var seedView: some View {
        switch seed {
        case .photo(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        case .prompt(let text):
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        case .none:
            EmptyView()
        }
    }

    private func chip(label: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(uiColor: .systemBackground)))
        .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Carousels

    private func carousel(
        title: String,
        options: [AIFlowOption],
        select: @escaping (AIFlowOption) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(options) { option in
                        Button { select(option) } label: {
                            optionCard(option)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .frame(height: 104)
        }
    }

    private func optionCard(_ option: AIFlowOption) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(option.color)
                .shadow(color: option.color.opacity(0.35), radius: 6, x: 0, y: 3)

            Text(option.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(8)
        }
        .frame(width: 96, height: 96)
    }

    // MARK: - Send button (loader morphs inside)

    private var sendButton: some View {
        Button(action: submit) {
            HStack(spacing: 10) {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color(uiColor: .systemBackground))
                    Text("Generating…")
                } else {
                    Image(systemName: "sparkles")
                        .font(.body.weight(.semibold))
                    Text("Generate")
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule(style: .continuous).fill(.primary))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
            .animation(.smooth(duration: 0.25), value: isGenerating)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .accessibilityLabel(isGenerating ? "Generating" : "Generate")
    }

    // MARK: - Actions

    private func submit() {
        guard let seed, let style = selectedStyle, let angle = selectedAngle else { return }
        onGenerate(seed, style, angle)
    }

    private func reset() {
        seed = nil
        selectedStyle = nil
        selectedAngle = nil
        pickerItems = []
    }

    private func loadPhoto(_ items: [PhotosPickerItem]) async {
        guard let first = items.first else { return }
        let data = try? await first.loadTransferable(type: Data.self)
        await MainActor.run {
            if let data, let image = UIImage(data: data) {
                seed = .photo(image)
            }
            pickerItems = []
        }
    }
}
