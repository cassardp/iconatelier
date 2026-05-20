import SwiftUI
import UIKit

@MainActor
@Observable
final class LassoController {
    var canvasFrame: CGRect = .zero
    var layersBarFrame: CGRect = .zero
    var fabFrame: CGRect = .zero
    var layerRowFrames: [UUID: CGRect] = [:]
    var lassoRect: CGRect? = nil

    func dragGesture(
        project: IconProject,
        session: ProjectSession,
        spaceName: String
    ) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .named(spaceName))
            .onChanged { value in
                MainActor.assumeIsolated {
                    self.handleDragChanged(value: value, project: project, session: session)
                }
            }
            .onEnded { _ in
                MainActor.assumeIsolated {
                    self.handleDragEnded(session: session)
                }
            }
    }

    func clearTapGesture(
        session: ProjectSession,
        spaceName: String
    ) -> some Gesture {
        SpatialTapGesture(coordinateSpace: .named(spaceName))
            .onEnded { value in
                MainActor.assumeIsolated {
                    self.handleClearTap(location: value.location, session: session)
                }
            }
    }

    func performBooleanOperation(
        _ op: BooleanOpKind,
        project: IconProject,
        session: ProjectSession
    ) {
        let uuids = session.lassoSelectedLayerUUIDs
        guard uuids.count >= 2 else { return }
        if let result = project.performBooleanOperation(op, on: uuids) {
            session.clearLassoSelection()
            session.selectLayer(result.uuid)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Private

    private func handleDragChanged(
        value: DragGesture.Value,
        project: IconProject,
        session: ProjectSession
    ) {
        let start = value.startLocation
        guard !canvasFrame.contains(start),
              !layersBarFrame.contains(start)
        else { return }

        let rect = CGRect(
            x: min(start.x, value.location.x),
            y: min(start.y, value.location.y),
            width: abs(value.location.x - start.x),
            height: abs(value.location.y - start.y)
        )
        lassoRect = rect

        let canvasLocal = rect.offsetBy(dx: -canvasFrame.minX, dy: -canvasFrame.minY)
        var newSelection = hitTest(rect: canvasLocal, side: canvasFrame.width, project: project)
        for (uuid, frame) in layerRowFrames where rect.intersects(frame) {
            if let layer = project.layer(withID: uuid), !layer.isLocked {
                newSelection.insert(layer.uuid)
            }
        }
        if newSelection != session.lassoSelectedLayerUUIDs {
            if newSelection.count > session.lassoSelectedLayerUUIDs.count {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            session.setLassoSelection(newSelection)
        }
    }

    private func handleDragEnded(session: ProjectSession) {
        withAnimation(.smooth(duration: 0.22)) {
            lassoRect = nil
        }
        if session.lassoSelectedLayerUUIDs.count == 1 {
            if let only = session.lassoSelectedLayerUUIDs.first {
                session.selectLayer(only)
            }
        } else if session.lassoSelectedLayerUUIDs.isEmpty {
            session.clearLassoSelection()
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func handleClearTap(location: CGPoint, session: ProjectSession) {
        guard session.isMultiSelecting else { return }
        guard !canvasFrame.contains(location),
              !layersBarFrame.contains(location),
              !fabFrame.contains(location)
        else { return }
        session.clearLassoSelection()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func hitTest(rect: CGRect, side: CGFloat, project: IconProject) -> Set<UUID> {
        guard side > 0 else { return [] }
        var matched: Set<UUID> = []
        for layer in project.layers where !layer.isLocked {
            let bboxSide = LayerGeometry.frameSide(for: layer, canvasSide: side)
            let centerX = side / 2 + layer.offset.width * side
            let centerY = side / 2 + layer.offset.height * side
            let layerRect = CGRect(
                x: centerX - bboxSide / 2,
                y: centerY - bboxSide / 2,
                width: bboxSide,
                height: bboxSide
            )
            if rect.intersects(layerRect) {
                matched.insert(layer.uuid)
            }
        }
        return matched
    }
}
