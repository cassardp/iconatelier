// TEMPORARY single-project persistence.
//
// This file persists the current IconProject to a JSON file in Documents so
// that the app reopens on the last edited state. It is intentionally minimal
// and self-contained — it will be DELETED when the gallery / multi-project
// feature lands and SwiftData takes over. Do not build on top of this.

import SwiftUI
import UIKit

// MARK: - Codable DTOs

struct PersistedProject: Codable {
    var background: PersistedBackground
    var layers: [PersistedLayer]
    var selectedLayerID: UUID?
    var isBackgroundSelected: Bool
}

struct PersistedBackground: Codable {
    var kind: String
    var solidColor: PersistedColor
    var gradientColors: [PersistedColor]
    var linearStart: PersistedPoint
    var linearEnd: PersistedPoint
    var gradientCenter: PersistedPoint
    var meshColors: [PersistedColor]
    var aiImagePNG: Data?
    var aiPrompt: String?
    var isHidden: Bool
}

struct PersistedLayer: Codable {
    var id: UUID
    var name: String
    var kind: String
    var imagePNG: Data?
    var sourcePrompt: String?
    var symbolName: String
    var emoji: String
    var text: String
    var fontWeight: String
    var tintColor: PersistedColor
    var offsetW: Double
    var offsetH: Double
    var scale: Double
    var rotationRadians: Double
    var opacity: Double
    var shadowOpacity: Double
    var shadowRadius: Double
    var shadowOffsetX: Double
    var shadowOffsetY: Double
    var isHidden: Bool
    var isLocked: Bool
}

struct PersistedColor: Codable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
}

struct PersistedPoint: Codable {
    var x: Double
    var y: Double
}

// MARK: - Color helpers

extension Color {
    func persisted() -> PersistedColor {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return PersistedColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
    }
}

extension PersistedColor {
    var color: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
}

extension UnitPoint {
    func persisted() -> PersistedPoint {
        PersistedPoint(x: Double(x), y: Double(y))
    }
}

extension PersistedPoint {
    var unitPoint: UnitPoint {
        UnitPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

// MARK: - Project <-> Persisted

@MainActor
extension IconProject {
    func persistedSnapshot() -> PersistedProject {
        PersistedProject(
            background: background.persisted(),
            layers: layers.map { $0.persisted() },
            selectedLayerID: selectedLayerID,
            isBackgroundSelected: isBackgroundSelected
        )
    }

    convenience init(persisted: PersistedProject) {
        self.init()
        background = Background(persisted: persisted.background)
        layers = persisted.layers.map { Layer(persisted: $0) }
        selectedLayerID = persisted.selectedLayerID
        isBackgroundSelected = persisted.isBackgroundSelected
        clearHistory()
    }
}

@MainActor
extension Background {
    func persisted() -> PersistedBackground {
        PersistedBackground(
            kind: kind.rawValue,
            solidColor: solidColor.persisted(),
            gradientColors: gradientColors.map { $0.persisted() },
            linearStart: linearStart.persisted(),
            linearEnd: linearEnd.persisted(),
            gradientCenter: gradientCenter.persisted(),
            meshColors: meshColors.map { $0.persisted() },
            aiImagePNG: aiImage?.pngData(),
            aiPrompt: aiPrompt,
            isHidden: isHidden
        )
    }

    convenience init(persisted p: PersistedBackground) {
        self.init(
            kind: BackgroundKind(rawValue: p.kind) ?? .meshGradient,
            solidColor: p.solidColor.color,
            gradientColors: p.gradientColors.map { $0.color },
            linearStart: p.linearStart.unitPoint,
            linearEnd: p.linearEnd.unitPoint,
            gradientCenter: p.gradientCenter.unitPoint,
            meshColors: p.meshColors.map { $0.color },
            aiImage: p.aiImagePNG.flatMap { UIImage(data: $0) },
            aiPrompt: p.aiPrompt
        )
        isHidden = p.isHidden
    }
}

@MainActor
extension Layer {
    func persisted() -> PersistedLayer {
        PersistedLayer(
            id: id,
            name: name,
            kind: kind.rawValue,
            imagePNG: image?.pngData(),
            sourcePrompt: sourcePrompt,
            symbolName: symbolName,
            emoji: emoji,
            text: text,
            fontWeight: fontWeight.rawValue,
            tintColor: tintColor.persisted(),
            offsetW: Double(offset.width),
            offsetH: Double(offset.height),
            scale: Double(scale),
            rotationRadians: rotation.radians,
            opacity: opacity,
            shadowOpacity: shadowOpacity,
            shadowRadius: Double(shadowRadius),
            shadowOffsetX: Double(shadowOffsetX),
            shadowOffsetY: Double(shadowOffsetY),
            isHidden: isHidden,
            isLocked: isLocked
        )
    }

    convenience init(persisted p: PersistedLayer) {
        self.init(
            id: p.id,
            kind: LayerKind(rawValue: p.kind) ?? .aiOverlay,
            name: p.name,
            image: p.imagePNG.flatMap { UIImage(data: $0) },
            sourcePrompt: p.sourcePrompt,
            symbolName: p.symbolName,
            emoji: p.emoji,
            text: p.text,
            fontWeight: LayerFontWeight(rawValue: p.fontWeight) ?? .bold,
            tintColor: p.tintColor.color
        )
        offset = CGSize(width: p.offsetW, height: p.offsetH)
        scale = CGFloat(p.scale)
        rotation = .radians(p.rotationRadians)
        opacity = p.opacity
        shadowOpacity = p.shadowOpacity
        shadowRadius = CGFloat(p.shadowRadius)
        shadowOffsetX = CGFloat(p.shadowOffsetX)
        shadowOffsetY = CGFloat(p.shadowOffsetY)
        isHidden = p.isHidden
        isLocked = p.isLocked
    }
}

// MARK: - Storage

enum ProjectPersistence {
    static var fileURL: URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        return docs.appendingPathComponent("iconatelier-state.json")
    }

    @MainActor
    static func save(_ project: IconProject) {
        let dto = project.persistedSnapshot()
        do {
            let data = try JSONEncoder().encode(dto)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ProjectPersistence save failed: \(error)")
        }
    }

    static func load() -> PersistedProject? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PersistedProject.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
