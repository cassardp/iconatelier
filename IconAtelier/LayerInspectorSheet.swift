import SwiftUI

struct LayerInspectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var layer: Layer
    @Bindable var project: IconProject

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    HStack {
                        Text("Opacity")
                        Spacer()
                        Text(layer.opacity, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $layer.opacity, in: 0...1)

                    if !layer.fillsCanvas {
                        HStack {
                            Text("Scale")
                            Spacer()
                            Text(String(format: "%.2f×", layer.scale))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $layer.scale, in: 0.1...4.0)
                    }
                }

                if !layer.fillsCanvas {
                    Section {
                        Button {
                            withAnimation(.snappy) {
                                layer.offset = .zero
                                layer.scale = 1.0
                                layer.rotation = .zero
                            }
                        } label: {
                            Label("Reset position", systemImage: "scope")
                        }
                    }
                }

                Section {
                    Button {
                        project.duplicate(layer)
                        dismiss()
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) {
                        project.remove(layer)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(layer.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.4)))
    }
}
