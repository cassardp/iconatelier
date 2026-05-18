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
        // 3-stops narratives (sunset-style gradients)
        .init(name: "Glow",
              colors: [Color(hex: 0xFFE94A), Color(hex: 0xFF6B00), Color(hex: 0x8B1A0E)]),
        .init(name: "Volcano",
              colors: [Color(hex: 0xFFEB3B), Color(hex: 0xFF3D00), Color(hex: 0x0A0A0A)]),
        .init(name: "Dusk",
              colors: [Color(hex: 0xFFD89B), Color(hex: 0xFF6B35), Color(hex: 0x0E2A47)]),
        .init(name: "Coral",
              colors: [Color(hex: 0xFFE5DA), Color(hex: 0xFF6E5B), Color(hex: 0x2D0A05)]),

        // Saturated halo (vivid center → dark monochrome edge)
        .init(name: "Cherry",
              colors: [Color(hex: 0xFF3D5C), Color(hex: 0x1A0006)]),
        .init(name: "Magenta",
              colors: [Color(hex: 0xFF00C8), Color(hex: 0x1B003A)]),
        .init(name: "Gold",
              colors: [Color(hex: 0xFFD700), Color(hex: 0x5D3A00)]),

        // Cross-hue saturated (two contrasting vivid hues)
        .init(name: "Bubblegum",
              colors: [Color(hex: 0xFF4DA6), Color(hex: 0x4A0080)]),
        .init(name: "Forest",
              colors: [Color(hex: 0xD4FF4A), Color(hex: 0x0A2E1F)]),
        .init(name: "Mint",
              colors: [Color(hex: 0x00E5C4), Color(hex: 0x001A14)]),

        // Pastel center → saturated edge
        .init(name: "Tide",
              colors: [Color(hex: 0xE8F5FF), Color(hex: 0x0A3A8F)]),
        .init(name: "Lavender",
              colors: [Color(hex: 0xFFFFFF), Color(hex: 0x6B4FCF)]),
        .init(name: "Cream",
              colors: [Color(hex: 0xFFF4D6), Color(hex: 0xFF4D6D)]),
        .init(name: "Pale Sky",
              colors: [Color(hex: 0xFFFFFF), Color(hex: 0x3D5A8C)]),

        // Inverted (dark center → luminous edge — "eclipse")
        .init(name: "Aubergine",
              colors: [Color(hex: 0x1A0014), Color(hex: 0xC13584)]),
        .init(name: "Lush",
              colors: [Color(hex: 0x0A2E1A), Color(hex: 0xC6FF00)]),
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

}

// MARK: - Mesh helper

extension MeshPreset {
    @MainActor
    var meshColors: [Color] {
        Color.mesh3x3(
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight
        )
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
