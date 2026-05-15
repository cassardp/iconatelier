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
    @Binding var selectedStyle: AIFlowOption?
    @Binding var selectedMaterial: AIFlowOption?
    let onGenerate: () -> Void
    let onAddSymbol: (String) -> Void
    let onAddPrompt: () -> Void
    let onAddDrawing: () -> Void
    let onAddText: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker: Bool = false
    @State private var activePicker: ActivePicker? = nil
    @State private var countdown: Int = 90
    @State private var showSymbolPopover: Bool = false

    private static let shapePresets: [String] = [
        "circle.fill", "square.fill", "triangle.fill", "diamond.fill",
        "rhombus.fill", "pentagon.fill", "hexagon.fill", "octagon.fill",
        "seal.fill", "star.fill", "heart.fill", "shield.fill",
        "rectangle.fill", "capsule.fill", "drop.fill", "oval.fill",
        "bolt.fill", "icloud.fill", "cone.fill", "minus",
    ]

    private enum ActivePicker: Hashable { case style, material }
    private enum ChainSquareKind: Hashable { case seed, style, material }

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
            promptFragment: "Pixar style. Stylized 3D Pixar-style character render in the unmistakable look of a Pixar animated feature film, soft rounded subdivision surfaces, slightly exaggerated cute proportions with oversized expressive eyes, three-quarter front-facing framing; warm cinematic key light with gentle rim light and rich global illumination, subtle ambient occlusion in crevices; subtle subsurface scattering on organic surfaces, smooth matte-to-satin materials with delicate controlled specular highlights, polished Pixar animation-film finish; vibrant warm storybook palette, appealing and inviting; high but readable detail, no busy texture noise; no text or lettering. Single centered subject, isolated on a soft neutral background, soft contact shadow under the subject acceptable, no duplicates, no extra elements, no frame, no other characters or props.",
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
        ),
        .init(
            id: "doodle",
            label: "Doodle",
            promptFragment: "cute cartoon doodle illustration, thick uniform dark outlines of consistent weight throughout the entire shape — the outline color is a deep tone (dark brown, deep maroon, or near-black) slightly tinted to harmonize with the fill, never pure jet black; outlines are confident, slightly imperfect hand-drawn but smooth, never sketchy, never variable in weight; flat solid opaque color fills inside the outlines — strictly aplats, absolutely no gradients, no shading, no highlights, no 3D, no texture; saturated mid-tone palette, warm and earthy (mid brown, terracotta, dusty mint, teal, mustard, brick), never washed-out pastel, never neon; chunky exaggerated chubby silhouette — oversized rounded body shaped like a fat bean or potato, tiny stubby arms and legs hanging off the body, very short proportions, big round head fused with body or sitting directly on it; minimalist face: two small dot eyes spaced close together, a tiny simple smile, no nose, no other features; one or two small playful accents on top allowed (tiny sprouting leaves, a tuft of hair, a single sparkle) drawn with the same line weight; minimal interior detail, no inner linework beyond the silhouette outline and the face dots; no text or lettering. Single centered subject, isolated on a plain neutral or soft uniform background, no duplicates, no extra characters, no frame, no drop shadow under the subject, no environment props. Outlines must be thick, smooth and uniform — never thin, never scratchy, never sketchbook-style hatching.",
            color: Color(red: 0.55, green: 0.32, blue: 0.22)
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

    private var canGenerate: Bool {
        seed != nil && selectedStyle != nil && !isGenerating
    }

    private var seedActions: [SeedAction] {
        [
            SeedAction(id: "prompt", label: "Prompt", systemImage: "sparkles.2", action: onAddPrompt),
            SeedAction(id: "photo", label: "Photo", systemImage: "camera.fill") {
                showPhotosPicker = true
            },
            SeedAction(id: "drawing", label: "Drawing", systemImage: "scribble.variable", action: onAddDrawing),
            SeedAction(id: "symbol", label: "Symbol", systemImage: "star.fill") {
                showSymbolPopover = true
            },
            SeedAction(id: "text", label: "Text", systemImage: "textformat", weight: .medium, action: onAddText)
        ]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            if seed == nil {
                initialActionsRow
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                if let picker = activePicker {
                    pickerRow(for: picker)
                        .frame(height: 92)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                chainRow
                    .frame(height: 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                sendRow
                    .frame(height: 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .animation(.smooth(duration: 0.3), value: seed == nil)
        .animation(.smooth(duration: 0.25), value: activePicker)
        .animation(.smooth(duration: 0.2), value: canGenerate)
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
        .onChange(of: seed) { _, newValue in
            if newValue == nil {
                selectedStyle = nil
                selectedMaterial = nil
                activePicker = nil
            } else if selectedStyle == nil {
                activePicker = .style
            }
        }
        .onChange(of: selectedStyle) { _, newValue in
            if newValue == nil {
                selectedMaterial = nil
            } else if activePicker == .style {
                activePicker = nil
            }
        }
        .onChange(of: selectedMaterial) { _, _ in
            if activePicker == .material {
                activePicker = nil
            }
        }
    }

    // MARK: - Initial actions row (seed == nil)

    private var initialActionsRow: some View {
        HStack(spacing: 0) {
            ForEach(seedActions) { item in
                seedActionButton(item)
                    .frame(maxWidth: .infinity)
                    .popover(
                        isPresented: Binding(
                            get: { item.id == "symbol" && showSymbolPopover },
                            set: { if !$0 { showSymbolPopover = false } }
                        ),
                        attachmentAnchor: .point(.top),
                        arrowEdge: .bottom
                    ) {
                        SymbolPresetsPopover(symbols: Self.shapePresets) { name in
                            showSymbolPopover = false
                            onAddSymbol(name)
                        }
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .disabled(isGenerating)
    }

    private func seedActionButton(_ item: SeedAction) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            item.action()
        } label: {
            Image(systemName: item.systemImage)
                .font(.system(size: 22, weight: item.weight))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .offset(y: -1)
                .frame(width: 54, height: 54)
                .background(Color.primary, in: .circle)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 1)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
    }

    // MARK: - Chain row (3 squares linked)

    private var chainRow: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            chainSquare(.seed)
            chainLink
            chainSquare(.style)
            chainLink
            chainSquare(.material)
            Spacer(minLength: 0)
        }
    }

    private var chainLink: some View {
        Rectangle()
            .frame(width: 6, height: 1)
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func chainSquare(_ kind: ChainSquareKind) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            switch kind {
            case .seed:
                // Tap on seed pill = reset everything, back to initial 5-button row.
                seed = nil
            case .style:
                togglePicker(.style)
            case .material:
                togglePicker(.material)
            }
        } label: {
            squareContent(for: kind)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating || (kind == .material && selectedStyle == nil))
        .accessibilityLabel(squareAccessibilityLabel(kind))
        .accessibilityHint(kind == .seed ? "Removes the seed and returns to the initial actions" : "")
    }

    @ViewBuilder
    private func squareContent(for kind: ChainSquareKind) -> some View {
        let size: CGFloat = 52
        let isActive: Bool = {
            switch kind {
            case .seed: return false
            case .style: return activePicker == .style
            case .material: return activePicker == .material
            }
        }()
        ZStack {
            switch kind {
            case .seed:
                seedSquareInner
            case .style:
                if let style = selectedStyle {
                    optionSquareInner(option: style)
                } else {
                    placeholderInner(symbol: "plus")
                }
            case .material:
                if let material = selectedMaterial {
                    optionSquareInner(option: material)
                } else {
                    placeholderInner(symbol: "plus")
                }
            }

            if isActive {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: 2)
            }
        }
        .frame(width: size, height: size)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.smooth(duration: 0.18), value: isActive)
    }

    @ViewBuilder
    private var seedSquareInner: some View {
        switch seed {
        case .photo(let image), .drawing(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .prompt:
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
                Image(systemName: "text.alignleft")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        case .none:
            placeholderInner(symbol: "plus")
        }
    }

    @ViewBuilder
    private func optionSquareInner(option: AIFlowOption) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
            Circle()
                .fill(option.color)
                .frame(width: 14, height: 14)
        }
    }

    @ViewBuilder
    private func placeholderInner(symbol: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Color.secondary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Send row

    private var sendRow: some View {
        HStack {
            Spacer(minLength: 0)
            sendButton
            Spacer(minLength: 0)
        }
    }

    private var sendButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onGenerate()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary)
                Group {
                    if isGenerating {
                        if countdown > 0 {
                            Text("\(countdown)")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color(uiColor: .systemBackground))
                                .contentTransition(.numericText(countsDown: true))
                        } else {
                            ProgressView()
                                .tint(Color(uiColor: .systemBackground))
                        }
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .systemBackground))
                    }
                }
                .animation(.smooth(duration: 0.25), value: countdown)
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .disabled(!canGenerate)
        .task(id: isGenerating) {
            guard isGenerating else {
                countdown = 90
                return
            }
            countdown = 90
            while countdown > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                countdown -= 1
            }
        }
        .accessibilityLabel(isGenerating ? "Generating" : "Generate")
    }

    // MARK: - Picker row

    @ViewBuilder
    private func pickerRow(for picker: ActivePicker) -> some View {
        Group {
            switch picker {
            case .style:
                optionsPickerRow(
                    options: Self.styles,
                    selection: selectedStyle,
                    allowNone: false
                ) { option in
                    selectedStyle = option
                }
            case .material:
                optionsPickerRow(
                    options: Self.materials,
                    selection: selectedMaterial,
                    allowNone: true
                ) { option in
                    selectedMaterial = option
                }
            }
        }
        .id(picker)
        .transition(.opacity)
    }

    private func optionsPickerRow(
        options: [AIFlowOption],
        selection: AIFlowOption?,
        allowNone: Bool,
        select: @escaping (AIFlowOption?) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                if allowNone {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        select(nil)
                        activePicker = nil
                    } label: {
                        noneTile(isSelected: selection == nil)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(options) { option in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        select(option)
                    } label: {
                        optionTile(option, isSelected: option == selection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .disabled(isGenerating)
    }

    private func optionTile(_ option: AIFlowOption, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .tertiarySystemBackground))
            VStack(spacing: 4) {
                Circle()
                    .fill(option.color)
                    .frame(width: 14, height: 14)
                Text(option.label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 4)
            if isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: 2)
            }
        }
        .frame(width: 64, height: 64)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.smooth(duration: 0.18), value: isSelected)
        .accessibilityLabel(option.label)
    }

    private func noneTile(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .tertiarySystemBackground))
            Text("None")
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
            if isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: 2)
            }
        }
        .frame(width: 64, height: 64)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("None")
    }

    // MARK: - Actions

    private func togglePicker(_ picker: ActivePicker) {
        activePicker = (activePicker == picker) ? nil : picker
    }

    private func squareAccessibilityLabel(_ kind: ChainSquareKind) -> String {
        switch kind {
        case .seed:
            switch seed {
            case .photo: return "Seed: Photo"
            case .drawing: return "Seed: Drawing"
            case .prompt: return "Seed: Prompt"
            case .none: return "Seed, not set"
            }
        case .style:
            return selectedStyle.map { "Style: \($0.label)" } ?? "Style, not set"
        case .material:
            return selectedMaterial.map { "Material: \($0.label)" } ?? "Material, not set, optional"
        }
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

// MARK: - Seed action descriptor

private struct SeedAction: Identifiable {
    let id: String
    let label: String
    let systemImage: String
    let weight: Font.Weight
    let action: () -> Void

    init(
        id: String,
        label: String,
        systemImage: String,
        weight: Font.Weight = .regular,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
        self.weight = weight
        self.action = action
    }
}

// MARK: - Symbol presets popover

private struct SymbolPresetsPopover: View {
    let symbols: [String]
    let onSelect: (String) -> Void

    @State private var appeared: Bool = false

    private let columns = Array(repeating: GridItem(.fixed(52), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(symbols, id: \.self) { name in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(name)
                } label: {
                    Image(systemName: name)
                        .font(.title2)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(width: 52, height: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.smooth(duration: 0.22)) {
                appeared = true
            }
        }
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Color.primary)
    }
}

