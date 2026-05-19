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
    var center: UnitPoint? = nil
    var spread: Double? = nil
}

struct MeshPreset: Identifiable {
    let id = UUID()
    let name: String
    let topLeft: Color
    let topRight: Color
    let bottomLeft: Color
    let bottomRight: Color
    var cornerPoints: [UnitPoint]? = nil
    var rotationDegrees: Double? = nil
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

enum BackgroundPresets {
    static let linear: [LinearPreset] = [
        .init(name: "Sunset Sherbet",
              colors: [Color(hex: 0xFF9966), Color(hex: 0xFF5E62)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Mango Tango",
              colors: [Color(hex: 0xFDC830), Color(hex: 0xF37335)],
              start: .top, end: .bottom),
        .init(name: "Ed's Sunset",
              colors: [Color(hex: 0xFF7E5F), Color(hex: 0xFEB47B)],
              start: .top, end: .bottom),
        .init(name: "Bloody Mary",
              colors: [Color(hex: 0xFF512F), Color(hex: 0xDD2476)],
              start: .leading, end: .trailing),
        .init(name: "Aurora",
              colors: [Color(hex: 0x00C9FF), Color(hex: 0x92FE9D)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Aqua Marine",
              colors: [Color(hex: 0x1A2980), Color(hex: 0x26D0CE)],
              start: .top, end: .bottom),
        .init(name: "Vice",
              colors: [Color(hex: 0x3494E6), Color(hex: 0xEC6EAD)],
              start: .leading, end: .trailing),
        .init(name: "Cosmic Fusion",
              colors: [Color(hex: 0xFF00CC), Color(hex: 0x333399)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Royal",
              colors: [Color(hex: 0x141E30), Color(hex: 0x243B55)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Mojito",
              colors: [Color(hex: 0x1D976C), Color(hex: 0x93F9B9)],
              start: .top, end: .bottom),
        .init(name: "Twilight",
              colors: [Color(hex: 0x4776E6), Color(hex: 0x8E54E9)],
              start: .topLeading, end: .bottomTrailing),
        .init(name: "Steel",
              colors: [Color(hex: 0xBDC3C7), Color(hex: 0x2C3E50)],
              start: .top, end: .bottom),
    ]

    static let radial: [RadialPreset] = [

        .init(name: "Sunburst",
              colors: [Color(hex: 0xFFEDA0), Color(hex: 0xFF9500), Color(hex: 0xC62828)]),
        .init(name: "Glow",
              colors: [Color(hex: 0xFFE94A), Color(hex: 0xFF6B00), Color(hex: 0x8B1A0E)]),
        .init(name: "Volcano",
              colors: [Color(hex: 0xFFEB3B), Color(hex: 0xFF3D00), Color(hex: 0x0A0A0A)]),
        .init(name: "Dusk",
              colors: [Color(hex: 0xFFD89B), Color(hex: 0xFF6B35), Color(hex: 0x0E2A47)]),

        .init(name: "Aurora Burst",
              colors: [Color(hex: 0x84FFC9), Color(hex: 0x7B9AFF), Color(hex: 0x2D0A4E)]),
        .init(name: "Magenta Halo",
              colors: [Color(hex: 0xFF00C8), Color(hex: 0x4A0080), Color(hex: 0x0A0014)]),
        .init(name: "Tide",
              colors: [Color(hex: 0xE8F5FF), Color(hex: 0x4A90E2), Color(hex: 0x0A3A8F)]),

        .init(name: "Cherry",
              colors: [Color(hex: 0xFF3D5C), Color(hex: 0x600018)]),
        .init(name: "Forest Glow",
              colors: [Color(hex: 0xD4FF4A), Color(hex: 0x2E7D32), Color(hex: 0x0A2E1F)]),

        .init(name: "Cream",
              colors: [Color(hex: 0xFFF4D6), Color(hex: 0xFFB4A2), Color(hex: 0xC1416B)]),
        .init(name: "Spotlight",
              colors: [Color(hex: 0xFFFFFF), Color(hex: 0xFFCC33), Color(hex: 0x2D2D2D)]),

        .init(name: "Moonlight",
              colors: [Color(hex: 0xFFFFFF), Color(hex: 0xB0BEC5), Color(hex: 0x37474F)]),
    ]

    static let mesh: [MeshPreset] = [
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
        .init(name: "Aurora",
              topLeft: Color(hex: 0x5856D6),
              topRight: Color(hex: 0x007AFF),
              bottomLeft: Color(hex: 0x32D74B),
              bottomRight: Color(hex: 0x64D2FF)),
        .init(name: "Sunset",
              topLeft: Color(hex: 0xFF2D55),
              topRight: Color(hex: 0xFF9500),
              bottomLeft: Color(hex: 0xAF52DE),
              bottomRight: Color(hex: 0xFFCC00)),
        .init(name: "Iris Bloom",
              topLeft: Color(hex: 0xC9356F),
              topRight: Color(hex: 0xFF66B3),
              bottomLeft: Color(hex: 0x6A11CB),
              bottomRight: Color(hex: 0xE066FF)),
        .init(name: "Cosmic",
              topLeft: Color(hex: 0x1A1A2E),
              topRight: Color(hex: 0x6A11CB),
              bottomLeft: Color(hex: 0x3A1C71),
              bottomRight: Color(hex: 0xC33764)),
        .init(name: "Citrus",
              topLeft: Color(hex: 0xFFE066),
              topRight: Color(hex: 0xFF9500),
              bottomLeft: Color(hex: 0xA8E063),
              bottomRight: Color(hex: 0xFFCC33)),
        .init(name: "Berry Smoothie",
              topLeft: Color(hex: 0xFF66B3),
              topRight: Color(hex: 0xC33764),
              bottomLeft: Color(hex: 0x753A88),
              bottomRight: Color(hex: 0xFF8C8C)),
        .init(name: "Spring Bloom",
              topLeft: Color(hex: 0xA8E063),
              topRight: Color(hex: 0xFFE066),
              bottomLeft: Color(hex: 0xB3E0FF),
              bottomRight: Color(hex: 0xFFC0CB)),
        .init(name: "Ocean Depths",
              topLeft: Color(hex: 0x0083B0),
              topRight: Color(hex: 0x00B4DB),
              bottomLeft: Color(hex: 0x1A2980),
              bottomRight: Color(hex: 0x26D0CE)),
        .init(name: "Coral Reef",
              topLeft: Color(hex: 0x00CDAC),
              topRight: Color(hex: 0xFF6E7F),
              bottomLeft: Color(hex: 0x02AAB0),
              bottomRight: Color(hex: 0xFFCC95)),
        .init(name: "Mist",
              topLeft: Color(hex: 0xE8EAED),
              topRight: Color(hex: 0xCCD0D5),
              bottomLeft: Color(hex: 0xB1B6BD),
              bottomRight: Color(hex: 0xDDE0E4)),
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
    var canDelete: (Preset) -> Bool = { _ in false }
    var onDelete: (Preset) -> Void = { _ in }

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
                    .contextMenu {
                        if canDelete(preset) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                onDelete(preset)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
}
