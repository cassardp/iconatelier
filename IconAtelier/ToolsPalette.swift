import SwiftUI

struct ToolsPalette: View {
    enum Tool: Hashable {
        case generateBackground
        case generateOverlay
    }

    @Environment(\.dismiss) private var dismiss
    let hasBackground: Bool
    var onSelect: (Tool) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    aiSection
                    nativeSection
                    presetsSection
                }
                .padding()
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.45), .medium])
        .presentationDragIndicator(.visible)
    }

    private var aiSection: some View {
        section(title: "AI") {
            ToolButton(
                icon: "photo.fill",
                label: hasBackground ? "Replace background" : "AI background",
                tint: .blue
            ) {
                onSelect(.generateBackground)
                dismiss()
            }
            ToolButton(
                icon: "sparkles",
                label: "AI overlay",
                tint: .purple
            ) {
                onSelect(.generateOverlay)
                dismiss()
            }
        }
    }

    private var nativeSection: some View {
        section(title: "Native", footnote: "Soon") {
            ToolButton(icon: "circle.lefthalf.filled", label: "Gradient", tint: .orange, disabled: true) {}
            ToolButton(icon: "square.on.square", label: "Shape", tint: .green, disabled: true) {}
        }
    }

    private var presetsSection: some View {
        section(title: "Presets", footnote: "Soon") {
            ToolButton(icon: "square.grid.2x2", label: "Categories", tint: .pink, disabled: true) {}
        }
    }

    @ViewBuilder
    private func section(
        title: String,
        footnote: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let footnote {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 12)],
                spacing: 12
            ) {
                content()
            }
        }
    }
}

private struct ToolButton: View {
    let icon: String
    let label: String
    let tint: Color
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.18))
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 64, height: 64)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
