import SwiftUI
import UIKit

struct IconProjectSnapshot {
    let background: BackgroundSnapshot
    let layers: [LayerSnapshot]
}

@Observable
final class IconProject: Codable, Identifiable {

    var uuid: UUID = UUID()

    var title: String = "Untitled"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var thumbnailPNG: Data? {
        didSet { thumbnailPNGDirty = true }
    }

    @ObservationIgnored
    var thumbnailPNGDirty: Bool = true

    // MARK: - Target app metadata

    var appName: String?

    var appStoreURL: URL?

    var appBundleID: String?

    // MARK: - Gallery metadata

    var notes: String?

    var tags: [String] = []

    var authorName: String?

    // MARK: - Publication state

    var isPublic: Bool = false

    var publishedID: String?

    var publishedAt: Date?

    var background: Background?

    var layers: [Layer] = []

    @ObservationIgnored private var undoStack: [IconProjectSnapshot] = []
    @ObservationIgnored private var redoStack: [IconProjectSnapshot] = []
    @ObservationIgnored private var lastRecordedAt: Date?
    private static let maxUndoSteps = 50
    private static let coalesceWindow: TimeInterval = 0.5

    var id: UUID { uuid }

    init(title: String = "Untitled") {
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case uuid, title, createdAt, updatedAt
        case appName, appStoreURL, appBundleID
        case notes, tags, authorName
        case isPublic, publishedID, publishedAt
        case background, layers
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try c.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        appName = try c.decodeIfPresent(String.self, forKey: .appName)
        appStoreURL = try c.decodeIfPresent(URL.self, forKey: .appStoreURL)
        appBundleID = try c.decodeIfPresent(String.self, forKey: .appBundleID)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        authorName = try c.decodeIfPresent(String.self, forKey: .authorName)
        isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        publishedID = try c.decodeIfPresent(String.self, forKey: .publishedID)
        publishedAt = try c.decodeIfPresent(Date.self, forKey: .publishedAt)
        background = try c.decodeIfPresent(Background.self, forKey: .background)
        layers = try c.decodeIfPresent([Layer].self, forKey: .layers) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uuid, forKey: .uuid)
        try c.encode(title, forKey: .title)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(appName, forKey: .appName)
        try c.encodeIfPresent(appStoreURL, forKey: .appStoreURL)
        try c.encodeIfPresent(appBundleID, forKey: .appBundleID)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(authorName, forKey: .authorName)
        try c.encode(isPublic, forKey: .isPublic)
        try c.encodeIfPresent(publishedID, forKey: .publishedID)
        try c.encodeIfPresent(publishedAt, forKey: .publishedAt)
        try c.encodeIfPresent(background, forKey: .background)
        try c.encode(layers, forKey: .layers)
    }

    func ensureBackground() {
        if background == nil { background = Background() }
    }

    var safeBackground: Background {
        if let bg = background { return bg }
        let bg = Background()
        background = bg
        return bg
    }

    // MARK: - Layers

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func layer(withID uuid: UUID?) -> Layer? {
        guard let uuid else { return nil }
        return layers.first { $0.uuid == uuid }
    }

    var hasContent: Bool { !layers.isEmpty }

    // MARK: - Snapshot / undo

    private func currentSnapshot() -> IconProjectSnapshot {
        IconProjectSnapshot(
            background: (background ?? Background()).snapshot(),
            layers: layers.map { $0.snapshot() }
        )
    }

    private func apply(_ snapshot: IconProjectSnapshot) {
        if let bg = background {
            bg.apply(snapshot.background)
        } else {
            let bg = Background()
            bg.apply(snapshot.background)
            background = bg
        }

        let existingByUUID = Dictionary(uniqueKeysWithValues: layers.map { ($0.uuid, $0) })
        var rebuilt: [Layer] = []

        for snap in snapshot.layers {
            if let existing = existingByUUID[snap.uuid] {
                existing.apply(snap)
                rebuilt.append(existing)
            } else {
                let layer = Layer(uuid: snap.uuid, kind: snap.kind, name: snap.name)
                layer.apply(snap)
                rebuilt.append(layer)
            }
        }

        layers = rebuilt
    }

    func recordUndo() {

        let now = Date()
        if let last = lastRecordedAt, now.timeIntervalSince(last) < Self.coalesceWindow {
            return
        }
        lastRecordedAt = now
        undoStack.append(currentSnapshot())
        if undoStack.count > Self.maxUndoSteps {
            undoStack.removeFirst(undoStack.count - Self.maxUndoSteps)
        }
        redoStack.removeAll()
    }

    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        lastRecordedAt = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        apply(previous)
        lastRecordedAt = nil
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        apply(next)
        lastRecordedAt = nil
    }

    // MARK: - Layer add helpers

    @discardableResult
    private func append(_ layer: Layer) -> Layer {
        layers.append(layer)
        return layer
    }

    private func nextName(for kind: LayerKind, baseFallback: String) -> String {
        let n = layers.filter { $0.kind == kind }.count + 1
        return n == 1 ? baseFallback : "\(baseFallback) \(n)"
    }

    @discardableResult
    func addImportedOverlay(image: UIImage) -> Layer {
        recordUndo()
        return append(Layer(
            kind: .image,
            name: nextName(for: .image, baseFallback: "Import"),
            image: image
        ))
    }

    @discardableResult
    func addGeneratedImage(image: UIImage) -> Layer {
        recordUndo()
        return append(Layer(
            kind: .image,
            name: nextName(for: .image, baseFallback: "Generated"),
            image: image
        ))
    }

    @discardableResult
    func addShapeLayer(spec: ShapeSpec) -> Layer {
        recordUndo()
        let layer = Layer(
            kind: .parametricShape,
            name: nextName(for: .parametricShape, baseFallback: spec.displayName),
            tintColor: .white,
            shapeSpec: spec
        )
        layer.scaleValue = 2.0 / 3.0
        return append(layer)
    }

    @discardableResult
    func addTextOverlay(text: String = "Aa") -> Layer {
        recordUndo()
        let layer = Layer(kind: .text, name: text, text: text, tintColor: .black)
        layer.scaleValue = 1.0 / 1.8
        return append(layer)
    }

    // MARK: - Layer mutations

    func remove(_ layer: Layer) {
        recordUndo()
        layers.removeAll { $0.uuid == layer.uuid }
    }

    func removeLayers(uuids: Set<UUID>) {
        guard !uuids.isEmpty else { return }
        recordUndo()
        layers.removeAll { uuids.contains($0.uuid) }
    }

    func duplicated() -> IconProject {
        let copy = IconProject(title: title + " copy")
        copy.uuid = UUID()
        copy.thumbnailPNG = thumbnailPNG
        copy.appName = appName
        copy.appStoreURL = appStoreURL
        copy.appBundleID = appBundleID
        copy.notes = notes
        copy.tags = tags
        copy.authorName = authorName

        let bg = Background()
        bg.apply((background ?? Background()).snapshot())
        copy.background = bg

        copy.layers = layers.map { layer in
            let snap = layer.snapshot()
            let newLayer = Layer(kind: snap.kind, name: snap.name)
            newLayer.apply(snap)
            newLayer.uuid = UUID()
            return newLayer
        }
        return copy
    }

    @discardableResult
    func duplicate(_ layer: Layer) -> Layer {
        recordUndo()
        let snap = layer.snapshot()
        let copy = Layer(kind: snap.kind, name: snap.name + " copy")
        copy.apply(snap)
        copy.uuid = UUID()

        if let idx = layers.firstIndex(where: { $0.uuid == layer.uuid }) {
            layers.insert(copy, at: idx + 1)
        } else {
            layers.append(copy)
        }
        return copy
    }

    @discardableResult
    func addPastedLayers(_ pasted: [Layer]) -> [Layer] {
        guard !pasted.isEmpty else { return [] }
        recordUndo()
        var inserted: [Layer] = []
        for layer in pasted {
            layer.uuid = UUID()
            layers.append(layer)
            inserted.append(layer)
        }
        return inserted
    }

    func move(from source: IndexSet, to destination: Int) {
        recordUndo()
        layers.move(fromOffsets: source, toOffset: destination)
    }

    func bringToFront(uuids: Set<UUID>) {
        guard !uuids.isEmpty else { return }
        let moving = layers.filter { uuids.contains($0.uuid) }
        guard !moving.isEmpty else { return }
        let tailUUIDs = layers.suffix(moving.count).map(\.uuid)
        guard tailUUIDs != moving.map(\.uuid) else { return }
        recordUndo()
        let remaining = layers.filter { !uuids.contains($0.uuid) }
        layers = remaining + moving
    }

    func sendToBack(uuids: Set<UUID>) {
        guard !uuids.isEmpty else { return }
        let moving = layers.filter { uuids.contains($0.uuid) }
        guard !moving.isEmpty else { return }
        let headUUIDs = layers.prefix(moving.count).map(\.uuid)
        guard headUUIDs != moving.map(\.uuid) else { return }
        recordUndo()
        let remaining = layers.filter { !uuids.contains($0.uuid) }
        layers = moving + remaining
    }

    // MARK: - Boolean operations

    @MainActor
    @discardableResult
    func performBooleanOperation(
        _ op: BooleanOpKind,
        on layerUUIDs: Set<UUID>
    ) -> Layer? {
        let targets = layers.filter { layerUUIDs.contains($0.uuid) }
        guard targets.count >= 2 else { return nil }

        let newLayer: Layer
        if let vector = BooleanOpRenderer.vectorCompose(layers: targets, op: op),
           let layer = buildVectorBooleanLayer(
               vector: vector,
               op: op,
               bottomColor: targets.first?.tintColor ?? .white
           ) {
            newLayer = layer
        } else {
            guard let result = BooleanOpRenderer.compose(layers: targets, op: op) else {
                return nil
            }
            let layer = Layer(
                kind: .image,
                name: op.label,
                image: result.image
            )
            layer.offset = CGSize(
                width: result.centerInUnit.x,
                height: result.centerInUnit.y
            )
            layer.scaleValue = Double(result.sizeInUnit / 0.7)
            layer.tintColor = .white
            newLayer = layer
        }

        recordUndo()

        let bottomUUID = targets.first?.uuid
        let removeUUIDs = Set(targets.map(\.uuid))
        var remaining = layers.filter { !removeUUIDs.contains($0.uuid) }

        let insertAt: Int
        if let bottomUUID,
           let originalIdx = layers.firstIndex(where: { $0.uuid == bottomUUID }) {

            let priorRemoved = layers.prefix(originalIdx).filter { removeUUIDs.contains($0.uuid) }.count
            insertAt = min(originalIdx - priorRemoved, remaining.count)
        } else {
            insertAt = remaining.count
        }
        remaining.insert(newLayer, at: insertAt)
        layers = remaining

        return newLayer
    }

    func toggleLock(_ layer: Layer) {
        recordUndo()
        layer.isLocked.toggle()
    }

    @MainActor
    private func buildVectorBooleanLayer(
        vector: BooleanVectorResult,
        op: BooleanOpKind,
        bottomColor: Color
    ) -> Layer? {
        let bbox = vector.path.boundingRect
        guard bbox.width > 0, bbox.height > 0 else { return nil }
        guard let primitive = PathPrimitive(path: vector.path) else { return nil }

        let maxSide = max(bbox.width, bbox.height)
        let scale = maxSide / (vector.canvasSide * 0.5)
        let offset = CGSize(
            width: bbox.midX / vector.canvasSide,
            height: bbox.midY / vector.canvasSide
        )

        let layer = Layer(
            kind: .parametricShape,
            name: op.label,
            tintColor: bottomColor,
            shapeSpec: .customPath(primitive)
        )
        layer.offset = offset
        layer.scaleValue = Double(scale)
        return layer
    }
}
