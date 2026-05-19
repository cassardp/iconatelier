import SwiftUI
import UIKit

struct EditActionsMenu: View {
    @Bindable var project: IconProject
    let session: ProjectSession
    @Binding var showImportPicker: Bool

    var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }

    private var actions: LayerActions {
        LayerActions(project: project, session: session)
    }

    @ViewBuilder
    private var menuContent: some View {
        let canPaste = actions.canPaste
        let hasActiveLayers = actions.hasActiveLayers

        if hasActiveLayers || canPaste {
            ControlGroup {
                if hasActiveLayers {
                    Button {
                        actions.copy()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button {
                        actions.cut()
                    } label: {
                        Label("Cut", systemImage: "scissors")
                    }
                }
                if canPaste {
                    Button {
                        actions.paste()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                }
            }
            Divider()
        }

        if session.isBackgroundSelected {
            Button {
                withAnimation(.bouncy(duration: 0.25, extraBounce: 0.25)) {
                    let layer = project.addShapeLayer(spec: .iosSquircle)
                    session.selectLayer(layer.uuid)
                }
            } label: {
                Label("Add App Silhouette", systemImage: "app.fill")
            }
            Divider()
        } else if hasActiveLayers {
            if let single = actions.singleActiveLayer {
                Button {
                    actions.toggleLock(single)
                } label: {
                    Label(
                        single.isLocked ? "Unlock" : "Lock",
                        systemImage: single.isLocked ? "lock" : "lock.open"
                    )
                }
            }
            Button {
                actions.duplicate()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button {
                actions.bringToFront()
            } label: {
                Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled")
            }
            Button {
                actions.sendToBack()
            } label: {
                Label("Send to Back", systemImage: "square.3.layers.3d.bottom.filled")
            }
            Button {
                actions.flip(horizontal: true)
            } label: {
                Label("Flip Horizontal", systemImage: "arrow.left.and.right")
            }
            Button {
                actions.flip(horizontal: false)
            } label: {
                Label("Flip Vertical", systemImage: "arrow.up.and.down")
            }
            Divider()
        }

        if !project.layers.isEmpty {
            Button {
                actions.selectAll()
            } label: {
                Label("Select All", systemImage: "square.on.square.dashed")
            }
        }
        Button {
            showImportPicker = true
        } label: {
            Label("Import Image", systemImage: "square.and.arrow.down")
        }

        if hasActiveLayers {
            Divider()
            Button(role: .destructive) {
                actions.delete()
            } label: {
                Label(
                    actions.activeLayerUUIDs.count > 1 ? "Delete Layers" : "Delete Layer",
                    systemImage: "trash"
                )
            }
        }
    }
}
