import SwiftUI
import UIKit

struct SeedPreview: View {
    let seed: AIFlowSeed
    let isGenerating: Bool
    let isReady: Bool
    let cornerRadius: CGFloat
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: { if isReady && !isGenerating { onTap() } }) {
            content
                .clipShape(clipShape)
                .overlay(haloOverlay)
                .overlay(generatingOverlay)
                .overlay(alignment: .top) { readyBadge }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isReady && !isGenerating)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isReady && !isGenerating ? "Double tap to generate" : "")
    }

    @ViewBuilder
    private var content: some View {
        switch seed {
        case .photo(let image), .drawing(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
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
    private var haloOverlay: some View {
        if isReady && !isGenerating {
            PhaseAnimator([0, 1], content: { phase in
                clipShape
                    .strokeBorder(Color.primary.opacity(0.55), lineWidth: 2)
                    .opacity(reduceMotion ? 0.6 : (phase == 0 ? 0.35 : 0.85))
                    .scaleEffect(reduceMotion ? 1 : (phase == 0 ? 1.0 : 1.008))
            }, animation: { _ in
                reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 1.2)
            })
            .allowsHitTesting(false)
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

    @ViewBuilder
    private var readyBadge: some View {
        if isReady && !isGenerating {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.footnote.weight(.semibold))
                Text("Tap to generate")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Color(uiColor: .systemBackground))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(.primary))
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            .offset(y: -14)
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
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
