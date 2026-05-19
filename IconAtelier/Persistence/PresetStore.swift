import SwiftUI
import os

@MainActor
@Observable
final class PresetStore {
    var linear: [LinearPreset] {
        BackgroundPresets.linear + userLinear.map { $0.asPreset }
    }
    var radial: [RadialPreset] {
        BackgroundPresets.radial + userRadial.map { $0.asPreset }
    }
    var mesh: [MeshPreset] {
        BackgroundPresets.mesh + userMesh.map { $0.asPreset }
    }

    private var userLinear: [LinearPresetEntry] = []
    private var userRadial: [RadialPresetEntry] = []
    private var userMesh: [MeshPresetEntry] = []

    private let fm = FileManager.default
    private let fileURL: URL
    private let logger = Logger(subsystem: "fr.cassard.IconAtelier", category: "PresetStore")

    init() {
        fileURL = URL.documentsDirectory.appendingPathComponent("presets-user.json", isDirectory: false)
        load()
    }

    // MARK: - Add

    func addLinear(name: String, from paint: Paint) {
        userLinear.append(LinearPresetEntry(
            name: name,
            colors: paint.gradientColors,
            start: paint.linearStart,
            end: paint.linearEnd
        ))
        save()
    }

    func addRadial(name: String, from paint: Paint) {
        userRadial.append(RadialPresetEntry(
            name: name,
            colors: paint.gradientColors,
            center: paint.gradientCenter,
            spread: paint.radialSpread
        ))
        save()
    }

    func addMesh(name: String, from paint: Paint) {
        guard paint.meshColors.count == 9 else { return }
        userMesh.append(MeshPresetEntry(
            name: name,
            topLeft: paint.meshColors[0],
            topRight: paint.meshColors[2],
            bottomLeft: paint.meshColors[6],
            bottomRight: paint.meshColors[8],
            cornerPoints: paint.meshCornerPoints,
            rotationDegrees: paint.meshRotationDegrees
        ))
        save()
    }

    // MARK: - Reset

    func reset(kind: PaintKind) {
        switch kind {
        case .solid: return
        case .linearGradient: userLinear.removeAll()
        case .radialGradient: userRadial.removeAll()
        case .meshGradient: userMesh.removeAll()
        }
        save()
    }

    // MARK: - Remove individual user preset

    func isUserPreset(kind: PaintKind, name: String) -> Bool {
        switch kind {
        case .solid: return false
        case .linearGradient: return userLinear.contains(where: { $0.name == name })
        case .radialGradient: return userRadial.contains(where: { $0.name == name })
        case .meshGradient: return userMesh.contains(where: { $0.name == name })
        }
    }

    func removeUserPreset(kind: PaintKind, name: String) {
        switch kind {
        case .solid: return
        case .linearGradient: userLinear.removeAll(where: { $0.name == name })
        case .radialGradient: userRadial.removeAll(where: { $0.name == name })
        case .meshGradient: userMesh.removeAll(where: { $0.name == name })
        }
        save()
    }

    var userCount: (linear: Int, radial: Int, mesh: Int) {
        (userLinear.count, userRadial.count, userMesh.count)
    }

    // MARK: - Export

    func exportJSON(kind: PaintKind) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data: Data?
        switch kind {
        case .solid:
            return "[]"
        case .linearGradient:
            let all = BackgroundPresets.linear.map { LinearPresetEntry($0) } + userLinear
            data = try? encoder.encode(all.map { $0.asExport })
        case .radialGradient:
            let all = BackgroundPresets.radial.map { RadialPresetEntry($0) } + userRadial
            data = try? encoder.encode(all.map { $0.asExport })
        case .meshGradient:
            let all = BackgroundPresets.mesh.map { MeshPresetEntry($0) } + userMesh
            data = try? encoder.encode(all.map { $0.asExport })
        }
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let bundle = try? JSONDecoder().decode(PresetsBundle.self, from: data)
        else { return }
        userLinear = bundle.linear ?? []
        userRadial = bundle.radial ?? []
        userMesh = bundle.mesh ?? []
    }

    private func save() {
        let bundle = PresetsBundle(linear: userLinear, radial: userRadial, mesh: userMesh)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(bundle)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save presets: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Codable storage entries

private struct PresetsBundle: Codable {
    var linear: [LinearPresetEntry]?
    var radial: [RadialPresetEntry]?
    var mesh: [MeshPresetEntry]?
}

private struct LinearPresetEntry: Codable {
    var name: String
    var colors: [StoredColor]
    var start: StoredPoint
    var end: StoredPoint

    init(name: String, colors: [StoredColor], start: StoredPoint, end: StoredPoint) {
        self.name = name; self.colors = colors; self.start = start; self.end = end
    }

    @MainActor
    init(_ preset: LinearPreset) {
        self.name = preset.name
        self.colors = preset.colors.map { StoredColor($0) }
        self.start = StoredPoint(preset.start)
        self.end = StoredPoint(preset.end)
    }

    @MainActor
    var asPreset: LinearPreset {
        LinearPreset(
            name: name,
            colors: colors.map { $0.color },
            start: start.unitPoint,
            end: end.unitPoint
        )
    }

    var asExport: LinearPresetExport {
        LinearPresetExport(
            name: name,
            colors: colors.map { $0.hexString },
            start: PointExport(x: start.x, y: start.y),
            end: PointExport(x: end.x, y: end.y)
        )
    }
}

private struct RadialPresetEntry: Codable {
    var name: String
    var colors: [StoredColor]
    var center: StoredPoint?
    var spread: Double?

    init(name: String, colors: [StoredColor], center: StoredPoint? = nil, spread: Double? = nil) {
        self.name = name; self.colors = colors
        self.center = center; self.spread = spread
    }

    @MainActor
    init(_ preset: RadialPreset) {
        self.name = preset.name
        self.colors = preset.colors.map { StoredColor($0) }
        self.center = preset.center.map { StoredPoint($0) }
        self.spread = preset.spread
    }

    @MainActor
    var asPreset: RadialPreset {
        RadialPreset(
            name: name,
            colors: colors.map { $0.color },
            center: center?.unitPoint,
            spread: spread
        )
    }

    var asExport: RadialPresetExport {
        RadialPresetExport(
            name: name,
            colors: colors.map { $0.hexString },
            center: center.map { PointExport(x: $0.x, y: $0.y) },
            spread: spread
        )
    }
}

private struct MeshPresetEntry: Codable {
    var name: String
    var topLeft: StoredColor
    var topRight: StoredColor
    var bottomLeft: StoredColor
    var bottomRight: StoredColor
    var cornerPoints: [StoredPoint]?
    var rotationDegrees: Double?

    init(
        name: String,
        topLeft: StoredColor,
        topRight: StoredColor,
        bottomLeft: StoredColor,
        bottomRight: StoredColor,
        cornerPoints: [StoredPoint]? = nil,
        rotationDegrees: Double? = nil
    ) {
        self.name = name
        self.topLeft = topLeft; self.topRight = topRight
        self.bottomLeft = bottomLeft; self.bottomRight = bottomRight
        self.cornerPoints = cornerPoints
        self.rotationDegrees = rotationDegrees
    }

    @MainActor
    init(_ preset: MeshPreset) {
        self.name = preset.name
        self.topLeft = StoredColor(preset.topLeft)
        self.topRight = StoredColor(preset.topRight)
        self.bottomLeft = StoredColor(preset.bottomLeft)
        self.bottomRight = StoredColor(preset.bottomRight)
        self.cornerPoints = preset.cornerPoints?.map { StoredPoint($0) }
        self.rotationDegrees = preset.rotationDegrees
    }

    @MainActor
    var asPreset: MeshPreset {
        MeshPreset(
            name: name,
            topLeft: topLeft.color,
            topRight: topRight.color,
            bottomLeft: bottomLeft.color,
            bottomRight: bottomRight.color,
            cornerPoints: cornerPoints?.map { $0.unitPoint },
            rotationDegrees: rotationDegrees
        )
    }

    var asExport: MeshPresetExport {
        MeshPresetExport(
            name: name,
            topLeft: topLeft.hexString,
            topRight: topRight.hexString,
            bottomLeft: bottomLeft.hexString,
            bottomRight: bottomRight.hexString,
            cornerPoints: cornerPoints?.map { PointExport(x: $0.x, y: $0.y) },
            rotationDegrees: rotationDegrees
        )
    }
}

// MARK: - Export shapes (hex strings, human-pasteable)

private struct PointExport: Encodable {
    let x: Double
    let y: Double
}

private struct LinearPresetExport: Encodable {
    let name: String
    let colors: [String]
    let start: PointExport
    let end: PointExport
}

private struct RadialPresetExport: Encodable {
    let name: String
    let colors: [String]
    let center: PointExport?
    let spread: Double?
}

private struct MeshPresetExport: Encodable {
    let name: String
    let topLeft: String
    let topRight: String
    let bottomLeft: String
    let bottomRight: String
    let cornerPoints: [PointExport]?
    let rotationDegrees: Double?
}

private extension StoredColor {
    var hexString: String {
        let R = Int(round(max(0, min(1, r)) * 255))
        let G = Int(round(max(0, min(1, g)) * 255))
        let B = Int(round(max(0, min(1, b)) * 255))
        return String(format: "%02X%02X%02X", R, G, B)
    }
}
