import SwiftUI
import SwiftData
import UIKit

struct IconProjectSnapshot {
    let background: BackgroundSnapshot
    let layers: [LayerSnapshot]
}

@Model
final class IconProject {
    /// Stable identifier for sync, sharing, and gallery publication.
    var uuid: UUID = UUID()

    var title: String = "Untitled"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    @Attribute(.externalStorage) var thumbnailPNG: Data?

    // MARK: - Target app metadata
    /// Display name of the app this icon is designed for (may differ from `title`).
    var appName: String?
    /// App Store URL of the target app (e.g. https://apps.apple.com/app/id...).
    var appStoreURL: URL?
    /// Bundle identifier of the target app, when known.
    var appBundleID: String?

    // MARK: - Gallery metadata
    /// Free-form caption / description shown in the gallery.
    var notes: String?
    /// User-defined tags for search and filtering.
    var tags: [String] = []
    /// Display name credited as author when published.
    var authorName: String?

    // MARK: - Publication state
    /// Whether the icon is intended to be visible in the public gallery.
    var isPublic: Bool = false
    /// Server-assigned identifier once the icon has been uploaded.
    var publishedID: String?
    /// Timestamp of the most recent successful publish.
    var publishedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Background.project)
    var background: Background?

    @Relationship(deleteRule: .cascade, inverse: \Layer.project)
    var rawLayers: [Layer] = []

    @Transient private var undoStack: [IconProjectSnapshot] = []
    @Transient private var redoStack: [IconProjectSnapshot] = []
    @Transient private var lastRecordedAt: Date?
    private static let maxUndoSteps = 50
    private static let coalesceWindow: TimeInterval = 0.5

    init(title: String = "Untitled") {
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
    }

    func ensureBackground() {
        if background == nil { background = Background() }
    }

    /// Guaranteed non-nil background. Caller must have invoked `ensureBackground()` on entry.
    var safeBackground: Background {
        if let bg = background { return bg }
        let bg = Background()
        background = bg
        return bg
    }

    // MARK: - Layers (ordered)

    var layers: [Layer] {
        get { rawLayers.sorted(by: { $0.orderIndex < $1.orderIndex }) }
        set {
            for (i, l) in newValue.enumerated() { l.orderIndex = i }
            rawLayers = newValue
        }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func layer(withID uuid: UUID?) -> Layer? {
        guard let uuid else { return nil }
        return rawLayers.first { $0.uuid == uuid }
    }

    var hasContent: Bool { !rawLayers.isEmpty }

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

        let context = modelContext
        let existingByUUID = Dictionary(uniqueKeysWithValues: rawLayers.map { ($0.uuid, $0) })
        var rebuilt: [Layer] = []
        var seen: Set<UUID> = []

        for (i, snap) in snapshot.layers.enumerated() {
            seen.insert(snap.uuid)
            if let existing = existingByUUID[snap.uuid] {
                existing.apply(snap)
                existing.orderIndex = i
                rebuilt.append(existing)
            } else {
                let layer = Layer(uuid: snap.uuid, kind: snap.kind, name: snap.name)
                layer.apply(snap)
                layer.orderIndex = i
                rebuilt.append(layer)
            }
        }

        // Remove layers no longer in snapshot
        if let context {
            for layer in rawLayers where !seen.contains(layer.uuid) {
                context.delete(layer)
            }
        }
        rawLayers = rebuilt
    }

    func recordUndo() {
        // Coalesce rapid-fire calls (e.g. SwiftUI ColorPicker drags) so a single
        // edit session does not push dozens of snapshots. The "before" state is
        // already captured by the first call in the window.
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
        layer.orderIndex = rawLayers.count
        rawLayers.append(layer)
        return layer
    }

    private func nextName(for kind: LayerKind, baseFallback: String) -> String {
        let n = rawLayers.filter { $0.kind == kind }.count + 1
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
        return append(Layer(
            kind: .parametricShape,
            name: nextName(for: .parametricShape, baseFallback: spec.displayName),
            tintColor: .white,
            shapeSpec: spec
        ))
    }

    @discardableResult
    func addEmojiOverlay() -> Layer {
        recordUndo()
        return append(Layer(kind: .emoji, name: "✨"))
    }

    @discardableResult
    func addTextOverlay(text: String = "Aa") -> Layer {
        recordUndo()
        return append(Layer(kind: .text, name: text, text: text, tintColor: .black))
    }

    // MARK: - Layer mutations

    func remove(_ layer: Layer) {
        recordUndo()
        let removedUUID = layer.uuid
        var ordered = layers
        ordered.removeAll { $0.uuid == removedUUID }
        for (i, l) in ordered.enumerated() { l.orderIndex = i }
        rawLayers = ordered
        if let context = modelContext {
            context.delete(layer)
        }
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

        var copiedLayers: [Layer] = []
        for (i, layer) in layers.enumerated() {
            let snap = layer.snapshot()
            let newLayer = Layer(kind: snap.kind, name: snap.name)
            newLayer.apply(snap)
            newLayer.uuid = UUID()
            newLayer.orderIndex = i
            copiedLayers.append(newLayer)
        }
        copy.rawLayers = copiedLayers
        return copy
    }

    @discardableResult
    func duplicate(_ layer: Layer) -> Layer {
        recordUndo()
        let snap = layer.snapshot()
        let copy = Layer(kind: snap.kind, name: snap.name + " copy")
        copy.apply(snap)
        copy.uuid = UUID() // new identity for the copy

        var ordered = layers
        if let idx = ordered.firstIndex(where: { $0.uuid == layer.uuid }) {
            ordered.insert(copy, at: idx + 1)
        } else {
            ordered.append(copy)
        }
        for (i, l) in ordered.enumerated() { l.orderIndex = i }
        rawLayers = ordered
        return copy
    }

    func move(from source: IndexSet, to destination: Int) {
        recordUndo()
        var ordered = layers
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, l) in ordered.enumerated() { l.orderIndex = i }
        rawLayers = ordered
    }

    // MARK: - Boolean operations

    /// Rasterize the selected layers, apply the boolean op, and replace the
    /// sources with a single new image layer at the position of the
    /// bottom-most source.
    @MainActor
    @discardableResult
    func performBooleanOperation(
        _ op: BooleanOpKind,
        on layerUUIDs: Set<UUID>
    ) -> Layer? {
        let targets = rawLayers
            .filter { layerUUIDs.contains($0.uuid) && !$0.isHidden }
            .sorted { $0.orderIndex < $1.orderIndex }
        guard targets.count >= 2 else { return nil }

        // Try the vector path first — if every source is a parametric shape
        // or text layer, the result stays a real Shape and inherits border,
        // radial-repeat, and color edits like any other parametric layer.
        // Falls back to raster for image/emoji sources (or when the vector
        // boolean ops yield an empty path, e.g. an intersect with no overlap).
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

        let bottomIndex = targets.first?.orderIndex ?? 0
        let removeUUIDs = Set(targets.map(\.uuid))

        var remaining = layers.filter { !removeUUIDs.contains($0.uuid) }

        let insertAt = min(bottomIndex, remaining.count)
        remaining.insert(newLayer, at: insertAt)

        if let context = modelContext {
            for layer in targets {
                context.delete(layer)
            }
        }
        for (i, l) in remaining.enumerated() { l.orderIndex = i }
        rawLayers = remaining

        return newLayer
    }

    func toggleVisibility(_ layer: Layer) {
        recordUndo()
        layer.isHidden.toggle()
    }

    /// Wrap a vector boolean result as a parametric-shape layer. Derives
    /// the layer's offset and scale from the path's bbox so that, when the
    /// shape pipeline renders the `customPath` into its standard
    /// `canvasSide * 0.5 * scale` square frame, the path lands exactly
    /// where the silhouette was computed. Returns nil for a degenerate
    /// (empty / zero-area) result — caller falls back to raster compose.
    @MainActor
    private func buildVectorBooleanLayer(
        vector: BooleanVectorResult,
        op: BooleanOpKind,
        bottomColor: Color
    ) -> Layer? {
        let bbox = vector.path.boundingRect
        guard bbox.width > 0, bbox.height > 0 else { return nil }
        guard let primitive = PathPrimitive(path: vector.path) else { return nil }

        // Layer rendering uses a `canvasSide * 0.5 * scale` square frame for
        // parametric shapes. We want the frame's side to equal the path's
        // longest dimension, so `scale = maxSide / (canvasSide * 0.5)`. The
        // offset is the bbox center expressed in canvas-normalized units
        // (canvas = unit square, origin = canvas center) — same convention
        // as `Layer.offset` everywhere else.
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
