import SwiftUI
import PhotosUI
import UIKit

struct AIPromptBar: View {
    @Binding var text: String
    @Binding var attachments: [UIImage]
    let placeholder: String
    let isGenerating: Bool
    let canSubmit: Bool
    var focused: FocusState<Bool>.Binding
    let onGenerate: () -> Void

    static let maxAttachments = 4

    @State private var pickerItems: [PhotosPickerItem] = []

    private var circleFill: Color {
        if isGenerating || canSubmit { return .primary }
        return PanelStyle.rowFillActive
    }

    private var canAttachMore: Bool {
        !isGenerating && attachments.count < Self.maxAttachments
    }

    var body: some View {
        VStack(spacing: 8) {
            if !attachments.isEmpty {
                attachmentStrip
            }

            HStack(alignment: .center, spacing: 8) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: Self.maxAttachments - attachments.count,
                    matching: .images
                ) {
                    ZStack {
                        Circle().fill(Color(uiColor: .systemBackground))
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                }
                .tint(.primary)
                .disabled(!canAttachMore)
                .opacity(canAttachMore ? 1 : 0.4)
                .accessibilityLabel("Attach image")
                .simultaneousGesture(
                    TapGesture().onEnded { focused.wrappedValue = false }
                )

                HStack(alignment: .bottom, spacing: 4) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1 ... 5)
                        .focused(focused)
                        .disabled(isGenerating)
                        .padding(.leading, 16)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)

                    Button(action: onGenerate) {
                        ZStack {
                            Circle().fill(circleFill)
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
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit && !isGenerating)
                    .accessibilityLabel(isGenerating ? "Generating" : "Generate")
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
                }
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await loadPickedItems(newItems) }
        }
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(attachments.enumerated()), id: \.offset) { index, image in
                    AttachmentThumbnail(image: image) {
                        attachments.remove(at: index)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 56)
    }

    private func loadPickedItems(_ items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
            }
        }
        await MainActor.run {
            let room = Self.maxAttachments - attachments.count
            if room > 0 {
                attachments.append(contentsOf: loaded.prefix(room))
            }
            pickerItems = []
        }
    }
}

private struct AttachmentThumbnail: View {
    let image: UIImage
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.primary))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .accessibilityLabel("Remove image")
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
    }
}
