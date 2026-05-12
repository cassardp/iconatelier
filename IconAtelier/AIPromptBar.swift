import SwiftUI

struct AIPromptBar: View {
    @Binding var text: String
    let placeholder: String
    let isGenerating: Bool
    let canSubmit: Bool
    var focused: FocusState<Bool>.Binding
    let onGenerate: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1 ... 5)
                .focused(focused)
                .disabled(isGenerating)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(
                    Capsule(style: .continuous)
                        .fill(PanelStyle.rowFill)
                )

            Button(action: onGenerate) {
                ZStack {
                    Circle().fill(canSubmit ? Color.primary : PanelStyle.rowFill)
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color(uiColor: .systemBackground))
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(
                                canSubmit
                                    ? Color(uiColor: .systemBackground)
                                    : .secondary
                            )
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .accessibilityLabel("Generate")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
