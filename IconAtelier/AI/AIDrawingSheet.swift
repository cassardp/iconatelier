import SwiftUI
import PencilKit
import UIKit

struct AIDrawingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onUse: (UIImage) -> Void

    @State private var drawing = PKDrawing()
    @State private var canvasSize: CGSize = .zero

    private var isEmpty: Bool { drawing.strokes.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                GeometryReader { geo in
                    DrawingCanvas(drawing: $drawing)
                        .onAppear { canvasSize = geo.size }
                        .onChange(of: geo.size) { _, new in canvasSize = new }
                }

                if isEmpty {
                    Text("Draw the icon you want…")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { submit() }
                        .disabled(isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        drawing = PKDrawing()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(isEmpty)
                }
            }
        }
    }

    private func submit() {
        guard !isEmpty else { return }
        let image = renderImage()
        onUse(image)
        dismiss()
    }

    // Render the drawing onto an opaque white square so it works as a clean
    // reference image for the generation model. The drawing is centered and
    // scaled to fit the square with a small margin.
    private func renderImage() -> UIImage {
        let side: CGFloat = 1024
        let margin: CGFloat = 64
        let target = CGRect(x: 0, y: 0, width: side, height: side)
        let bounds = drawing.bounds.isEmpty ? CGRect(origin: .zero, size: canvasSize) : drawing.bounds

        let availableSide = side - margin * 2
        let scale = min(availableSide / max(bounds.width, 1),
                        availableSide / max(bounds.height, 1))
        let translation = CGAffineTransform(translationX: -bounds.midX, y: -bounds.midY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: side / 2, y: side / 2))

        let transformed = drawing.transformed(using: translation)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target.size, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(target)
            let strokes = transformed.image(from: target, scale: 1)
            strokes.draw(in: target)
        }
    }
}

// MARK: - PKCanvasView bridge

private struct DrawingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .label, width: 8)
        canvas.drawing = drawing
        context.coordinator.canvas = canvas
        DispatchQueue.main.async {
            let picker = context.coordinator.toolPicker
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvas
        let toolPicker = PKToolPicker()
        weak var canvas: PKCanvasView?

        init(_ parent: DrawingCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
