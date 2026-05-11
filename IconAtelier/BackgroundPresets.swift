import SwiftUI

// MARK: - Preset models

struct LinearPreset: Identifiable {
    let id = UUID()
    let name: String
    let colors: [Color]
    let start: UnitPoint
    let end: UnitPoint
}

struct RadialPreset: Identifiable {
    let id = UUID()
    let name: String
    let colors: [Color]
}

struct MeshPreset: Identifiable {
    let id = UUID()
    let name: String
    let topLeft: Color
    let topRight: Color
    let bottomLeft: Color
    let bottomRight: Color
}

struct AIPromptPreset: Identifiable {
    let id = UUID()
    let name: String
    let prompt: String
}

// MARK: - Hex helper

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Curated presets
// Inspired by uiGradients classics, tuned for app-icon legibility.

enum BackgroundPresets {
    static let linear: [LinearPreset] = [
        .init(name: "Sweet Morning",
              colors: [Color(hex: 0xFF5F6D), Color(hex: 0xFFC371)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Scooter",
              colors: [Color(hex: 0x36D1DC), Color(hex: 0x5B86E5)],
              start: .top, end: .bottom),
        .init(name: "Purple Love",
              colors: [Color(hex: 0xCC2B5E), Color(hex: 0x753A88)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Endless River",
              colors: [Color(hex: 0x43CEA2), Color(hex: 0x185A9D)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Bloody Mary",
              colors: [Color(hex: 0xFF512F), Color(hex: 0xDD2476)],
              start: .leading, end: .trailing),
        .init(name: "Ed's Sunset",
              colors: [Color(hex: 0xFF7E5F), Color(hex: 0xFEB47B)],
              start: .top, end: .bottom),
        .init(name: "Frost",
              colors: [Color(hex: 0x000428), Color(hex: 0x004E92)],
              start: .top, end: .bottom),
        .init(name: "Royal",
              colors: [Color(hex: 0x141E30), Color(hex: 0x243B55)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Mojito",
              colors: [Color(hex: 0x1D976C), Color(hex: 0x93F9B9)],
              start: .top, end: .bottom),
        .init(name: "Cotton Candy",
              colors: [Color(hex: 0xFBC2EB), Color(hex: 0xA6C1EE)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Vice City",
              colors: [Color(hex: 0x3494E6), Color(hex: 0xEC6EAD)],
              start: .leading, end: .trailing),
        .init(name: "Mango",
              colors: [Color(hex: 0xF09819), Color(hex: 0xEDDE5D)],
              start: .top, end: .bottom),
        .init(name: "Cosmic Fusion",
              colors: [Color(hex: 0xFF00CC), Color(hex: 0x333399)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Sunrise",
              colors: [Color(hex: 0xFF8008), Color(hex: 0xFFC837)],
              start: .top, end: .bottom),
        .init(name: "Deep Sea",
              colors: [Color(hex: 0x2C3E50), Color(hex: 0x4CA1AF)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Plum",
              colors: [Color(hex: 0x654EA3), Color(hex: 0xEAAFC8)],
              start: .top, end: .bottom),
    ]

    static let radial: [RadialPreset] = [
        .init(name: "Glow",
              colors: [Color(hex: 0xFFD60A), Color(hex: 0xFF9500)]),
        .init(name: "Cherry",
              colors: [Color(hex: 0xF45C43), Color(hex: 0xEB3349)]),
        .init(name: "Tide",
              colors: [Color(hex: 0x64D2FF), Color(hex: 0x5856D6)]),
        .init(name: "Lush",
              colors: [Color(hex: 0xA8E063), Color(hex: 0x56AB2F)]),
        .init(name: "Bubblegum",
              colors: [Color(hex: 0xFF66B3), Color(hex: 0xAF52DE)]),
        .init(name: "Aubergine",
              colors: [Color(hex: 0xAA076B), Color(hex: 0x61045F)]),
        .init(name: "Dusk",
              colors: [Color(hex: 0xFFD89B), Color(hex: 0x19547B)]),
        .init(name: "Lavender",
              colors: [Color(hex: 0xD4C5F9), Color(hex: 0x5E5CE6)]),
        .init(name: "Mint",
              colors: [Color(hex: 0xB4EC51), Color(hex: 0x429321)]),
        .init(name: "Coral",
              colors: [Color(hex: 0xFFB199), Color(hex: 0xFF0844)]),
        .init(name: "Gold",
              colors: [Color(hex: 0xFFE259), Color(hex: 0xFFA751)]),
        .init(name: "Volcano",
              colors: [Color(hex: 0xF12711), Color(hex: 0x1A1A2E)]),
        .init(name: "Magenta",
              colors: [Color(hex: 0xEE0979), Color(hex: 0xFF6A00)]),
        .init(name: "Forest",
              colors: [Color(hex: 0x71B280), Color(hex: 0x134E5E)]),
        .init(name: "Cream",
              colors: [Color(hex: 0xFCE38A), Color(hex: 0xF38181)]),
        .init(name: "Pale Sky",
              colors: [Color(hex: 0xE0EAFC), Color(hex: 0x7B9ACC)]),
    ]

    static let mesh: [MeshPreset] = [
        .init(name: "Aurora",
              topLeft: Color(hex: 0x5856D6),
              topRight: Color(hex: 0x007AFF),
              bottomLeft: Color(hex: 0xFF2D55),
              bottomRight: Color(hex: 0xFF9500)),
        .init(name: "Sunset",
              topLeft: Color(hex: 0xFF512F),
              topRight: Color(hex: 0xFF9500),
              bottomLeft: Color(hex: 0xDD2476),
              bottomRight: Color(hex: 0xFFC371)),
        .init(name: "Ocean",
              topLeft: Color(hex: 0x64D2FF),
              topRight: Color(hex: 0x0A84FF),
              bottomLeft: Color(hex: 0x30B0C7),
              bottomRight: Color(hex: 0x5856D6)),
        .init(name: "Iris",
              topLeft: Color(hex: 0x4568DC),
              topRight: Color(hex: 0xFF66B3),
              bottomLeft: Color(hex: 0xB06AB3),
              bottomRight: Color(hex: 0xFF2D55)),
        .init(name: "Citrus",
              topLeft: Color(hex: 0xFFE066),
              topRight: Color(hex: 0x56AB2F),
              bottomLeft: Color(hex: 0xFF9500),
              bottomRight: Color(hex: 0xA8E063)),
        .init(name: "Candy",
              topLeft: Color(hex: 0xFF66B3),
              topRight: Color(hex: 0x64D2FF),
              bottomLeft: Color(hex: 0xAF52DE),
              bottomRight: Color(hex: 0x43CEA2)),
        .init(name: "Twilight",
              topLeft: Color(hex: 0x3A1C71),
              topRight: Color(hex: 0xD76D77),
              bottomLeft: Color(hex: 0x141E30),
              bottomRight: Color(hex: 0xFFAF7B)),
        .init(name: "Berry",
              topLeft: Color(hex: 0xC33764),
              topRight: Color(hex: 0x1D2671),
              bottomLeft: Color(hex: 0xFF512F),
              bottomRight: Color(hex: 0x753A88)),
        .init(name: "Tropical",
              topLeft: Color(hex: 0x00C9FF),
              topRight: Color(hex: 0xFFD200),
              bottomLeft: Color(hex: 0xFF512F),
              bottomRight: Color(hex: 0xA8FF78)),
        .init(name: "Pastel Dream",
              topLeft: Color(hex: 0xFFCAA7),
              topRight: Color(hex: 0xC7B5FB),
              bottomLeft: Color(hex: 0xB5F8E0),
              bottomRight: Color(hex: 0xFFC0CB)),
        .init(name: "Neon",
              topLeft: Color(hex: 0xB91D73),
              topRight: Color(hex: 0x00C9FF),
              bottomLeft: Color(hex: 0xF953C6),
              bottomRight: Color(hex: 0xA8FF78)),
        .init(name: "Galactic",
              topLeft: Color(hex: 0x3A1C71),
              topRight: Color(hex: 0xC9356F),
              bottomLeft: Color(hex: 0x1A1A2E),
              bottomRight: Color(hex: 0x6A11CB)),
        .init(name: "Coral Reef",
              topLeft: Color(hex: 0x00CDAC),
              topRight: Color(hex: 0xFF6E7F),
              bottomLeft: Color(hex: 0x02AAB0),
              bottomRight: Color(hex: 0xFFCC95)),
        .init(name: "Spring",
              topLeft: Color(hex: 0xA8E063),
              topRight: Color(hex: 0xFFE066),
              bottomLeft: Color(hex: 0xB3E0FF),
              bottomRight: Color(hex: 0xFFD89B)),
        .init(name: "Lagoon",
              topLeft: Color(hex: 0x00B4DB),
              topRight: Color(hex: 0x0083B0),
              bottomLeft: Color(hex: 0x11998E),
              bottomRight: Color(hex: 0x38EF7D)),
        .init(name: "Volcano",
              topLeft: Color(hex: 0x5C0000),
              topRight: Color(hex: 0xFF6A00),
              bottomLeft: Color(hex: 0x1A1A2E),
              bottomRight: Color(hex: 0xE50000)),
    ]

    static let aiPrompts: [AIPromptPreset] = [
        .init(name: "Aurora",
              prompt: "Smooth multi-color mesh gradient in the style of a modern iOS app icon background, soft aurora ribbons of teal, indigo and magenta blending seamlessly across the square"),
        .init(name: "Holographic",
              prompt: "Iridescent holographic foil surface in the style of a premium iOS app icon background, smooth chromatic shimmer of pink, cyan and violet, glossy finish"),
        .init(name: "Glass Orb",
              prompt: "Glassmorphism style iOS app icon background, soft translucent glass surface with gentle highlights, blurred pastel light behind frosted glass, depth and subtle reflections"),
        .init(name: "Chrome",
              prompt: "3D liquid chrome iOS app icon background, glossy metallic surface with smooth flowing highlights and soft color tints, premium luxurious finish"),
        .init(name: "Sunset Sky",
              prompt: "Illustrated dusk sky in the style of an iOS weather app icon background, smooth gradient from coral pink to warm orange to deep indigo, soft stylized cloud bands"),
        .init(name: "Nebula",
              prompt: "Stylized cosmic nebula iOS app icon background, deep indigo space with swirling blue and magenta gas clouds, scattered tiny stars, premium illustrated finish"),
        .init(name: "Tropical",
              prompt: "Illustrated tropical foliage iOS app icon background, lush stylized emerald palm leaves over turquoise gradient, soft directional light, vector-style polish"),
        .init(name: "Marble",
              prompt: "Realistic white marble iOS app icon background, polished stone surface with delicate gold veins, soft studio lighting, luxurious material texture"),
        .init(name: "Synthwave",
              prompt: "Synthwave neon iOS app icon background, glowing magenta-to-cyan gradient sky over a thin neon horizon grid, retro 80s premium illustration"),
        .init(name: "Watercolor",
              prompt: "Painterly watercolor iOS app icon background, soft blended washes of pastel pink and lavender on textured paper, organic pigment edges, hand-painted feel"),
        .init(name: "Crystal",
              prompt: "Faceted crystal iOS app icon background, low-poly translucent gemstone facets in pale pink and violet refracting soft light, geometric 3D render"),
        .init(name: "Wave",
              prompt: "Stylized ocean wave iOS app icon background, smooth turquoise water curves with soft white foam highlights, simplified illustration, polished finish"),
        .init(name: "Forest",
              prompt: "Atmospheric forest iOS app icon background, layered stylized pine silhouettes fading into soft teal mist, dreamy painterly depth"),
        .init(name: "Blobs",
              prompt: "Flat design iOS app icon background, soft overlapping pastel blobs in coral, mint and lavender on a cream backdrop, modern minimalist composition"),
        .init(name: "Kraft Paper",
              prompt: "Realistic kraft paper iOS app icon background, warm beige fibrous paper texture with subtle grain and soft directional light, tactile material finish"),
        .init(name: "Galaxy",
              prompt: "Stylized spiral galaxy iOS app icon background, soft pink and indigo gas spiral with dense star dust, painterly cosmic illustration, premium finish"),
        .init(name: "Risograph",
              prompt: "Risograph print iOS app icon background, overlapping warm pink and cool blue ink layers with visible grain and slight misregistration, retro screen print style"),
        .init(name: "Velvet",
              prompt: "Premium velvet iOS app icon background, rich deep fabric with soft sweeping folds catching warm light, burgundy blending into emerald, luxurious material"),
    ]

    static let overlayPrompts: [AIPromptPreset] = [
        .init(name: "Coffee",
              prompt: "Steaming cup of latte art coffee seen from above, simplified iOS app icon glyph style, warm cream and brown tones"),
        .init(name: "Camera",
              prompt: "Vintage rangefinder camera front view, simplified iOS app icon glyph style, deep navy body with brushed silver lens ring"),
        .init(name: "Calendar",
              prompt: "Single calendar page with a bold number, simplified iOS app icon glyph style, crisp white card with red top band"),
        .init(name: "Compass",
              prompt: "Classic navigation compass top view, simplified iOS app icon glyph style, brass rim with red and white needle"),
        .init(name: "Bolt",
              prompt: "Lightning bolt symbol, simplified iOS app icon glyph style, vivid yellow with soft inner highlight"),
        .init(name: "Heart",
              prompt: "Plump glossy heart shape, simplified iOS app icon glyph style, vivid coral red with soft top highlight"),
        .init(name: "Music",
              prompt: "Single beamed eighth music note, simplified iOS app icon glyph style, glossy black with soft highlight"),
        .init(name: "Lock",
              prompt: "Padlock front view, simplified iOS app icon glyph style, polished gold body with brushed shackle"),
        .init(name: "Rocket",
              prompt: "Cartoon rocket pointing up, simplified iOS app icon glyph style, white body with red fins and round porthole"),
        .init(name: "Book",
              prompt: "Closed hardcover book seen at a slight angle, simplified iOS app icon glyph style, rich emerald cover with gold trim"),
        .init(name: "Cloud",
              prompt: "Plump rounded cloud shape, simplified iOS app icon glyph style, soft white with subtle pastel blue shading"),
        .init(name: "Pencil",
              prompt: "Sharpened classic pencil at a slight diagonal, simplified iOS app icon glyph style, warm yellow body with black tip and pink eraser"),
        .init(name: "Crown",
              prompt: "Five-point royal crown, simplified iOS app icon glyph style, polished gold with small jewel accents"),
        .init(name: "Diamond",
              prompt: "Brilliant-cut diamond facing the viewer, simplified iOS app icon glyph style, pale cyan facets with sharp prismatic highlights"),
        .init(name: "Flame",
              prompt: "Stylized flame shape, simplified iOS app icon glyph style, gradient from deep red base to bright yellow tip"),
        .init(name: "Globe",
              prompt: "Stylized earth globe seen from the front, simplified iOS app icon glyph style, vivid blue oceans with green continents"),
        .init(name: "Headphones",
              prompt: "Over-ear studio headphones front view, simplified iOS app icon glyph style, matte black with chrome accents"),
        .init(name: "Star",
              prompt: "Plump five-point star, simplified iOS app icon glyph style, glossy bright yellow with soft inner highlight"),
    ]
}

// MARK: - Mesh helper

extension MeshPreset {
    @MainActor
    var meshColors: [Color] {
        let tl = topLeft, tr = topRight, bl = bottomLeft, br = bottomRight
        return [
            tl,                       Color.mix(tl, tr, 0.5), tr,
            Color.mix(tl, bl, 0.5),   Color.mix(Color.mix(tl, tr, 0.5),
                                                Color.mix(bl, br, 0.5), 0.5),
                                                                        Color.mix(tr, br, 0.5),
            bl,                       Color.mix(bl, br, 0.5), br
        ]
    }
}

// MARK: - Presets row UI

struct BackgroundPresetsRow<Preset: Identifiable, Thumb: View>: View {
    let presets: [Preset]
    let thumbnail: (Preset) -> Thumb
    let onSelect: (Preset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    Button {
                        onSelect(preset)
                    } label: {
                        thumbnail(preset)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: PanelStyle.cornerRadius, style: .continuous)
                                    .stroke(.separator.opacity(0.5), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
}
