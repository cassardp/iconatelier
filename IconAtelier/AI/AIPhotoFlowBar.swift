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
    case drawing(UIImage)
}

// MARK: - Bar

struct AIPhotoFlowBar: View {
    let isGenerating: Bool
    @Binding var seed: AIFlowSeed?
    let onGenerate: (AIFlowSeed, AIFlowOption, AIFlowOption?) -> Void
    let onAddSymbol: () -> Void
    let onAddPrompt: () -> Void
    let onAddDrawing: () -> Void

    @State private var selectedStyle: AIFlowOption?
    @State private var selectedMaterial: AIFlowOption?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker: Bool = false
    @State private var isCreateMenuOpen: Bool = false

    static let styles: [AIFlowOption] = [
        .init(
            id: "illustration",
            label: "Illustration",
            promptFragment: "soft matte gradient illustration, simplified rounded forms, vivid saturated palette, smooth color-to-color transitions modeling gentle volume, diffused ambient lighting, no outlines, no grain, no specular highlights; matte finish with subtle tonal shifts for soft three-dimensionality; harmonious palette of three to five hues maximum; plump rounded silhouettes, organic curves favored over hard edges; moderate detail with a few selective accents; no text or lettering. Single centered subject, isolated on a neutral background, generous negative space around it, no duplicates, no extra elements, no frame, no background shape behind the subject, no cast shadows under the subject.",
            color: Color(red: 0.20, green: 0.50, blue: 0.95)
        ),
        .init(
            id: "3d",
            label: "3D",
            promptFragment: "3D isometric collectible icon, front-facing three-quarter view, refined contours and rounded edges, matte-to-satin surfaces with subtle micro-reflections, deep ambient occlusion in crevices, soft diffused studio lighting, ultra-soft feathered contact shadow on a clean neutral surface; semi-realistic stylized proportions, balanced and appealing; natural realistic palette, restrained and harmonious; mix of straight and curved surfaces, generous fillets, no sharp corners; moderate detail with subtle surface texture; no text or lettering. Single centered subject, isolated on a neutral background, no duplicates, no extra elements, no frame, no background props.",
            color: Color(red: 1.00, green: 0.55, blue: 0.00)
        ),
        .init(
            id: "pixar",
            label: "Pixar",
            promptFragment: "stylized 3D Pixar-style character render, soft rounded subdivision surfaces, slightly exaggerated cute proportions with oversized expressive eyes, three-quarter front-facing framing; warm cinematic key light with gentle rim light and rich global illumination, subtle ambient occlusion in crevices; subtle subsurface scattering on organic surfaces, smooth matte-to-satin materials with delicate controlled specular highlights, polished animation-film finish; vibrant warm storybook palette, appealing and inviting; high but readable detail, no busy texture noise; no text or lettering. Single centered subject, isolated on a soft neutral background, soft contact shadow under the subject acceptable, no duplicates, no extra elements, no frame, no other characters or props.",
            color: Color(red: 0.15, green: 0.65, blue: 0.85)
        ),
        .init(
            id: "logo",
            label: "Logo",
            promptFragment: "flat vector logo mark in the spirit of Paul Rand, bold simplified geometric forms, confident silhouette, no outlines, no textures, no shading, completely flat; pure monochrome black on white; balanced mix of straight and curved geometry; extreme reduction, almost abstract, one strong idea; counter-shapes and negative space inside the mark allowed when the form calls for it; no text or lettering. Single centered subject, isolated on a plain white background, no duplicates, no extra elements, no frame, no cast shadows, no glows.",
            color: Color(red: 0.20, green: 0.20, blue: 0.25)
        ),
        .init(
            id: "typography",
            label: "Typography",
            promptFragment: "a single typographic glyph, modern geometric sans-serif, semi-bold weight, balanced optical proportions, subtle flat two-tone shading suggesting volume without any 3D rendering, crisp clean edges; two-tone palette, one base color and one slightly darker accent; smooth balanced letterform, gentle curves and even strokes; minimal rendering, no textures; counters and apertures of the letter preserved exactly as the glyph's shape requires; no extra characters, just the single glyph. Single centered glyph, isolated on a neutral background, no duplicates, no extra elements, no frame, no cast shadows, no glows.",
            color: Color(red: 0.55, green: 0.40, blue: 0.80)
        ),
        .init(
            id: "notion",
            label: "Notion",
            promptFragment: "minimalist black-and-white flat vector illustration in the expressive Notion avatar style, thick uniform monoline black outlines, organic confident hand-drawn quality, quirky charming proportions, selective solid black fills used as shape language for dark surfaces — not as shading or gradients, lighter areas remain pure flat white; strictly two values only, pure black and pure white, no gray, no gradients, no color; smooth organic confident lines, natural flowing shapes; extreme simplicity, very few strokes, almost abstract; no text or lettering. Single centered subject, isolated on a pure white background, no duplicates, no extra elements, no frame, no drop shadows. Outlines must be thick and uniform weight throughout, never thin or variable.",
            color: Color(red: 0.30, green: 0.30, blue: 0.35)
        ),
        .init(
            id: "sticker",
            label: "Sticker",
            promptFragment: "flat die-cut sticker, solid opaque color fills, cartoon style, thick uniform off-white border (#FAF9F7, a warm near-white, never pure #FFFFFF) tracing the entire outer silhouette of the sticker uniformly; purely flat, no shading, no gradients, no 3D; limited palette of two to three bold flat colors; bold rounded simplified shapes; minimal interior detail, no textures; no text or lettering. Single centered subject, isolated on a transparent or neutral background, no duplicates, no extra elements, no frame, no drop shadow under the sticker. All shapes solid and fully filled, no holes inside the sticker. Every part of the sticker interior must be fully opaque; only the area outside the die-cut border is transparent.",
            color: Color(red: 1.00, green: 0.35, blue: 0.40)
        )
    ]

    static let materials: [AIFlowOption] = [
        .init(id: "matte",       label: "Matte",       promptFragment: "matte finish material, no gloss, no reflections, soft diffused surface", color: Color(red: 0.50, green: 0.50, blue: 0.52)),
        .init(id: "glossy",      label: "Glossy",      promptFragment: "glossy shiny material, polished reflective surface, specular highlights", color: Color(red: 0.20, green: 0.75, blue: 0.95)),
        .init(id: "glass",       label: "Glass",       promptFragment: "transparent glass material, refractive, subtle reflections, see-through", color: Color(red: 0.70, green: 0.88, blue: 0.95)),
        .init(id: "metal",       label: "Metal",       promptFragment: "metallic material, brushed metal finish, subtle reflections, industrial feel", color: Color(red: 0.55, green: 0.58, blue: 0.62)),
        .init(id: "gold",        label: "Gold",        promptFragment: "polished gold material, luxurious warm metallic golden surface, rich reflections", color: Color(red: 1.00, green: 0.78, blue: 0.30)),
        .init(id: "silver",      label: "Silver",      promptFragment: "polished silver material, cool metallic surface, chrome-like reflections", color: Color(red: 0.78, green: 0.80, blue: 0.85)),
        .init(id: "copper",      label: "Copper",      promptFragment: "copper material, warm reddish metallic surface, oxidized patina accents", color: Color(red: 0.80, green: 0.45, blue: 0.28)),
        .init(id: "bronze",      label: "Bronze",      promptFragment: "bronze material, warm dark metallic surface, antique patina feel", color: Color(red: 0.55, green: 0.40, blue: 0.25)),
        .init(id: "wood",        label: "Wood",        promptFragment: "natural wood material, visible wood grain texture, warm organic feel", color: Color(red: 0.55, green: 0.38, blue: 0.22)),
        .init(id: "clay",        label: "Clay",        promptFragment: "soft matte clay material, handmade feel, smooth sculpted surface", color: Color(red: 0.82, green: 0.55, blue: 0.42)),
        .init(id: "plastic",     label: "Plastic",     promptFragment: "smooth plastic material, slightly glossy, clean manufactured feel", color: Color(red: 0.45, green: 0.65, blue: 0.85)),
        .init(id: "rubber",      label: "Rubber",      promptFragment: "soft rubber material, matte elastic surface, slightly textured grip feel", color: Color(red: 0.28, green: 0.28, blue: 0.30)),
        .init(id: "marble",      label: "Marble",      promptFragment: "polished marble material, subtle veins and patterns, elegant stone surface", color: Color(red: 0.88, green: 0.86, blue: 0.82)),
        .init(id: "concrete",    label: "Concrete",    promptFragment: "raw concrete material, rough mineral surface, brutalist industrial texture", color: Color(red: 0.60, green: 0.60, blue: 0.58)),
        .init(id: "stone",       label: "Stone",       promptFragment: "natural carved stone material, rough hewn mineral surface, sculptural feel", color: Color(red: 0.55, green: 0.52, blue: 0.48)),
        .init(id: "ceramic",     label: "Ceramic",     promptFragment: "glazed ceramic material, smooth porcelain-like surface, delicate crafted feel", color: Color(red: 0.92, green: 0.86, blue: 0.78)),
        .init(id: "fabric",      label: "Fabric",      promptFragment: "soft fabric textile material, woven texture, cloth-like surface", color: Color(red: 0.65, green: 0.55, blue: 0.50)),
        .init(id: "leather",     label: "Leather",     promptFragment: "rich leather material, fine grain texture, visible saddle stitch seams (point sellier), premium handcrafted luxury leather goods feel", color: Color(red: 0.42, green: 0.26, blue: 0.18)),
        .init(id: "felt",        label: "Felt",        promptFragment: "soft felt material, fuzzy textile surface, handcrafted warm feel", color: Color(red: 0.85, green: 0.70, blue: 0.55)),
        .init(id: "wool",        label: "Wool",        promptFragment: "knitted wool material, chunky yarn texture, cozy handmade feel", color: Color(red: 0.92, green: 0.86, blue: 0.72)),
        .init(id: "embroidery",  label: "Embroidery",  promptFragment: "embroidered textile material, visible thread stitches, cross-stitch or satin stitch texture, handcrafted needlework on fabric", color: Color(red: 0.85, green: 0.55, blue: 0.60)),
        .init(id: "mercury",     label: "Mercury",     promptFragment: "liquid mercury material, highly reflective chrome-like liquid surface, fluid metallic blob, T-1000 style molten metal", color: Color(red: 0.72, green: 0.74, blue: 0.78)),
        .init(id: "ice",         label: "Ice",         promptFragment: "frozen ice material, translucent crystalline surface, cold blue refractions, frost details", color: Color(red: 0.70, green: 0.86, blue: 0.96)),
        .init(id: "wax",         label: "Wax",         promptFragment: "warm wax material, slightly translucent, soft melting edges, candle-like surface", color: Color(red: 0.95, green: 0.90, blue: 0.70)),
        .init(id: "candy",       label: "Candy",       promptFragment: "hard candy material, glossy sugary surface, translucent colorful sweet, lollipop-like shine", color: Color(red: 1.00, green: 0.45, blue: 0.65)),
        .init(id: "chocolate",   label: "Chocolate",   promptFragment: "smooth chocolate material, rich brown glossy surface, molded confectionery feel", color: Color(red: 0.40, green: 0.25, blue: 0.15)),
        .init(id: "leaf",        label: "Leaf",        promptFragment: "natural leaf material, organic green leaf texture with visible veins, shaped from a real tree leaf, botanical natural feel", color: Color(red: 0.40, green: 0.65, blue: 0.30)),
        .init(id: "coral",       label: "Coral",       promptFragment: "organic coral material, porous natural marine texture, underwater reef aesthetic", color: Color(red: 1.00, green: 0.50, blue: 0.45)),
        .init(id: "popcorn",     label: "Popcorn",     promptFragment: "popcorn material, the entire shape is made of clustered popcorn kernels, puffy irregular white and yellow pieces, movie snack texture", color: Color(red: 0.95, green: 0.88, blue: 0.65)),
        .init(id: "balloon",     label: "Balloon",     promptFragment: "inflated latex balloon material, smooth stretched rubber surface, shiny highlights, balloon sculpture twist aesthetic", color: Color(red: 0.95, green: 0.30, blue: 0.40)),
        .init(id: "crystal",     label: "Crystal",     promptFragment: "transparent crystal gemstone material, faceted cuts, prismatic light refractions, precious stone clarity", color: Color(red: 0.75, green: 0.70, blue: 0.95)),
        .init(id: "rust",        label: "Rust",        promptFragment: "oxidized rusted metal material, orange-brown corroded iron surface, rough flaking patina, aged industrial decay", color: Color(red: 0.75, green: 0.40, blue: 0.20)),
        .init(id: "velvet",      label: "Velvet",      promptFragment: "soft velvet material, rich plush textile with light-catching nap, luxurious deep fabric texture", color: Color(red: 0.45, green: 0.20, blue: 0.55)),
        .init(id: "denim",       label: "Denim",       promptFragment: "denim fabric material, visible twill weave pattern, indigo blue cotton textile, jeans texture", color: Color(red: 0.25, green: 0.35, blue: 0.55)),
        .init(id: "fur",         label: "Fur",         promptFragment: "soft animal fur material, dense fluffy hair covering the surface, plush furry texture", color: Color(red: 0.55, green: 0.40, blue: 0.30)),
        .init(id: "feather",     label: "Feather",     promptFragment: "feather material, the shape is covered in layered bird feathers, soft downy texture with fine barbs", color: Color(red: 0.78, green: 0.82, blue: 0.85)),
        .init(id: "bubblegum",   label: "Bubblegum",   promptFragment: "stretched bubblegum material, soft pink glossy elastic surface, slightly translucent, chewy candy feel", color: Color(red: 1.00, green: 0.55, blue: 0.75)),
        .init(id: "cookie",      label: "Cookie",      promptFragment: "baked cookie material, golden brown crumbly dough texture, shortbread or sugar cookie feel with subtle cracks", color: Color(red: 0.80, green: 0.60, blue: 0.40)),
        .init(id: "cheese",      label: "Cheese",      promptFragment: "cheese material, smooth yellow-orange surface with characteristic round holes, Swiss cheese aesthetic", color: Color(red: 0.95, green: 0.80, blue: 0.30)),
        .init(id: "cotton",      label: "Cotton",      promptFragment: "fluffy cotton material, soft white cloud-like cotton balls or cotton candy texture, airy and light", color: Color(red: 0.95, green: 0.95, blue: 0.95)),
        .init(id: "holographic", label: "Holographic", promptFragment: "holographic iridescent material, rainbow shifting reflections, prismatic surface, futuristic feel", color: Color(red: 0.70, green: 0.50, blue: 0.95)),
        .init(id: "cardboard",   label: "Cardboard",   promptFragment: "corrugated cardboard material, raw brown recycled texture, handmade craft feel", color: Color(red: 0.70, green: 0.55, blue: 0.40)),
        .init(id: "terracotta",  label: "Terracotta",  promptFragment: "terracotta clay material, warm reddish-orange unglazed ceramic, Mediterranean pottery feel", color: Color(red: 0.78, green: 0.42, blue: 0.30)),
        .init(id: "obsidian",    label: "Obsidian",    promptFragment: "volcanic obsidian glass material, deep black mirror-like surface, sharp beveled edges, subtle iridescent reflections, premium gemstone feel", color: Color(red: 0.10, green: 0.10, blue: 0.13)),
        .init(id: "cloud",       label: "Cloud",       promptFragment: "soft puffy cloud material, billowy rounded cumulus shapes, white airy volumetric surface, dreamy sky-like softness", color: Color(red: 0.88, green: 0.92, blue: 0.97))
    ]

    private enum Step: Hashable { case seed, style, ready }

    private var step: Step {
        if seed == nil { return .seed }
        if selectedStyle == nil { return .style }
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
                systemImage: "textformat",
                color: .primary,
                action: onAddPrompt
            ),
            CreateActionItem(
                id: "drawing",
                label: "Drawing",
                systemImage: "paintbrush.pointed.fill",
                color: .primary,
                action: onAddDrawing
            ),
            CreateActionItem(
                id: "symbol",
                label: "Symbol",
                systemImage: "star.fill",
                color: .primary,
                action: onAddSymbol
            )
        ]
    }

    var body: some View {
        Group {
            if step == .seed {
                CreateRadialMenu(items: createItems, isOpen: $isCreateMenuOpen)
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
                case .ready:
                    VStack(spacing: 10) {
                        carousel(
                            title: selectedMaterial == nil ? "Pick a material (optional)" : "Material",
                            options: Self.materials
                        ) { selectedMaterial = $0 }
                        sendButton
                    }
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
                    selectedMaterial = nil
                }
            }

            if let material = selectedMaterial {
                chip(label: material.label, color: material.color) {
                    selectedMaterial = nil
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
        case .photo(let image), .drawing(let image):
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
        guard let seed, let style = selectedStyle else { return }
        onGenerate(seed, style, selectedMaterial)
    }

    private func reset() {
        seed = nil
        selectedStyle = nil
        selectedMaterial = nil
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
