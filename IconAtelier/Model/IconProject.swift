import SwiftUI
import UIKit

struct IconProjectSnapshot {
    let background: BackgroundSnapshot
    let layers: [Layer]
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

    // MARK: - Indexed mutation helpers

    func mutate(id: UUID, _ block: (inout Layer) -> Void) {
        guard let idx = layers.firstIndex(where: { $0.uuid == id }) else { return }
        block(&layers[idx])
    }

    func mutateLayers(ids: Set<UUID>, _ block: (inout Layer) -> Void) {
        for idx in layers.indices where ids.contains(layers[idx].uuid) {
            block(&layers[idx])
        }
    }

    func layerBinding(id: UUID) -> Binding<Layer>? {
        guard layers.contains(where: { $0.uuid == id }) else { return nil }
        return Binding(
            get: { [weak self] in
                self?.layers.first(where: { $0.uuid == id }) ?? Layer.image(name: "")
            },
            set: { [weak self] newValue in
                guard let self else { return }
                if let idx = self.layers.firstIndex(where: { $0.uuid == id }) {
                    self.layers[idx] = newValue
                }
            }
        )
    }

    // MARK: - Snapshot / undo

    private func currentSnapshot() -> IconProjectSnapshot {
        IconProjectSnapshot(
            background: (background ?? Background()).snapshot(),
            layers: layers
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
        layers = snapshot.layers
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
        return append(Layer.image(
            name: nextName(for: .image, baseFallback: "Import"),
            image: image
        ))
    }

    @discardableResult
    func addGeneratedImage(image: UIImage) -> Layer {
        recordUndo()
        return append(Layer.image(
            name: nextName(for: .image, baseFallback: "Generated"),
            image: image
        ))
    }

    @discardableResult
    func addShapeLayer(spec: ShapeSpec) -> Layer {
        recordUndo()
        var layer = Layer.shape(
            name: nextName(for: .parametricShape, baseFallback: spec.displayName),
            spec: spec,
            tintColor: .white
        )
        layer.scaleValue = 2.0 / 3.0
        return append(layer)
    }

    @discardableResult
    func addSilhouetteLayer(spec: ShapeSpec = .iosSquircle) -> Layer {
        recordUndo()
        var layer = Layer.shape(
            name: nextName(for: .parametricShape, baseFallback: spec.displayName),
            spec: spec,
            tintColor: .white
        )
        layer.scaleValue = 1.7
        layer.opacity = 0.2
        layers.insert(layer, at: 0)
        return layer
    }

    @discardableResult
    func addTextOverlay(text: String = "Aa") -> Layer {
        recordUndo()
        var layer = Layer.text(name: text, text: text, tintColor: .black)
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
            var newLayer = layer
            newLayer.uuid = UUID()
            return newLayer
        }
        return copy
    }

    @discardableResult
    func duplicate(_ layer: Layer) -> Layer {
        recordUndo()
        var copy = layer
        copy.uuid = UUID()
        copy.name = layer.name + " copy"

        let nudge: CGFloat = 0.05
        let limit = LayerGeometry.maxOffsetMagnitude(for: copy)
        copy.offset = CGSize(
            width: min(max(copy.offset.width + nudge, -limit), limit),
            height: min(max(copy.offset.height + nudge, -limit), limit)
        )

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
        for var layer in pasted {
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
           let bottom = targets.first,
           let layer = buildVectorBooleanLayer(
               vector: vector,
               op: op,
               source: bottom
           ) {
            newLayer = layer
        } else {
            guard let result = BooleanOpRenderer.compose(layers: targets, op: op) else {
                return nil
            }
            var layer = Layer.image(name: op.label, image: result.image)
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

    func toggleLock(id: UUID) {
        recordUndo()
        mutate(id: id) { $0.isLocked.toggle() }
    }

    @MainActor
    private func buildVectorBooleanLayer(
        vector: BooleanVectorResult,
        op: BooleanOpKind,
        source: Layer
    ) -> Layer? {
        var baseT = CGAffineTransform(
            translationX: source.offset.width * vector.canvasSide,
            y: source.offset.height * vector.canvasSide
        )
        baseT = baseT.rotated(by: CGFloat(source.rotationRadians))
        if source.isFlippedHorizontally { baseT = baseT.scaledBy(x: -1, y: 1) }
        if source.isFlippedVertically { baseT = baseT.scaledBy(x: 1, y: -1) }

        let localPath = vector.path.applying(baseT.inverted())
        let bbox = localPath.boundingRect
        guard bbox.width > 0, bbox.height > 0 else { return nil }
        guard let primitive = PathPrimitive(path: localPath) else { return nil }

        let maxSide = max(bbox.width, bbox.height)
        let scale = maxSide / (vector.canvasSide * 0.5)

        let localCenter = CGPoint(x: bbox.midX, y: bbox.midY)
        let worldCenter = localCenter.applying(baseT)
        let offset = CGSize(
            width: worldCenter.x / vector.canvasSide,
            height: worldCenter.y / vector.canvasSide
        )

        var layer = Layer.shape(
            name: op.label,
            spec: .customPath(primitive),
            tintColor: source.tintColor
        )
        if let paint = source.storedFillPaint { layer.fillPaint = paint }
        layer.fillEnabled = source.fillEnabled
        layer.borderWidth = source.borderWidth
        layer.borderColor = source.borderColor
        layer.borderPosition = source.borderPosition
        layer.lineCap = source.lineCap
        layer.opacity = source.opacity
        layer.appearance.effects = source.appearance.effects
        layer.offset = offset
        layer.scaleValue = Double(scale)
        layer.rotationRadians = source.rotationRadians
        layer.isFlippedHorizontally = source.isFlippedHorizontally
        layer.isFlippedVertically = source.isFlippedVertically
        return layer
    }
}
