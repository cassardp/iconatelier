import SwiftUI
import UIKit

struct SeedPreview: View {
    let seed: AIFlowSeed
    let isGenerating: Bool
    let side: CGFloat
    let cornerRadius: CGFloat

    private var clipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        content
            .frame(width: side, height: side)
            .clipShape(clipShape)
            .overlay(generatingOverlay)
            .allowsHitTesting(false)
            .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var content: some View {
        switch seed {
        case .photo(let image), .drawing(let image):
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: side, height: side)
                .clipped()
        case .prompt(let text):
            promptCard(text)
        }
    }

    private func promptCard(_ text: String) -> some View {
        ZStack {
            Color.iaDefaultBackground

            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(8)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
    }

    @ViewBuilder
    private var generatingOverlay: some View {
        if isGenerating {
            ZStack {
                clipShape
                    .fill(.black.opacity(0.35))
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
            .transition(.opacity)
        }
    }

    private var accessibilityLabel: String {
        switch seed {
        case .photo: return "Photo seed"
        case .drawing: return "Drawing seed"
        case .prompt(let text): return "Prompt: \(text)"
        }
    }
}
