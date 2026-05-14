import SwiftUI
import UIKit

struct CreateActionItem: Identifiable, Equatable {
    let id: String
    let label: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    static func == (lhs: CreateActionItem, rhs: CreateActionItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct CreateRadialMenu: View {
    let items: [CreateActionItem]
    @Binding var isOpen: Bool

    private let centerSize: CGFloat = 60
    private let miniSize: CGFloat = 60
    private let radius: CGFloat = 130

    var body: some View {
        ZStack {
            backdrop
            miniButtons
            centralButton
        }
        .frame(width: centerSize, height: centerSize)
        .sensoryFeedback(.impact(weight: .light), trigger: isOpen)
    }

    // MARK: - Backdrop (subtle halo behind the central button)

    private var backdrop: some View {
        Circle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: centerSize, height: centerSize)
            .scaleEffect(isOpen ? 4.0 : 1.0)
            .opacity(isOpen ? 1.0 : 0.0)
            .blur(radius: isOpen ? 18 : 0)
            .animation(.smooth(duration: 0.28), value: isOpen)
            .allowsHitTesting(false)
    }

    // MARK: - Central + button

    private var centralButton: some View {
        Button {
            withAnimation(.spring(duration: 0.28, bounce: 0.35)) {
                isOpen.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.title.weight(.regular))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .rotationEffect(.degrees(isOpen ? 45 : 0))
                .frame(width: centerSize, height: centerSize)
                .background(Color.primary, in: .circle)
                .shadow(
                    color: .black.opacity(isOpen ? 0.28 : 0.18),
                    radius: isOpen ? 14 : 10,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isOpen ? 1.06 : 1.0)
                .animation(.spring(duration: 0.28, bounce: 0.45), value: isOpen)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "Close create menu" : "Create new layer")
    }

    // MARK: - Mini buttons radial layout

    private var miniButtons: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            miniButton(item: item, index: index)
        }
    }

    private func miniButton(item: CreateActionItem, index: Int) -> some View {
        let target = position(for: index)
        // Stagger: when opening, lower indexes come out first; when closing,
        // the order reverses so the menu "collapses" toward the center cleanly.
        let openDelay = Double(index) * 0.025
        let closeDelay = Double(items.count - 1 - index) * 0.015

        return Button {
            handleTap(item)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                Image(systemName: item.systemImage)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(width: miniSize, height: miniSize, alignment: .center)
            }
            .frame(width: miniSize, height: miniSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .offset(isOpen ? target : .zero)
        .scaleEffect(isOpen ? 1.0 : 0.05)
        .opacity(isOpen ? 1.0 : 0.0)
        .rotationEffect(.degrees(isOpen ? 0 : -25))
        .animation(
            .spring(duration: 0.32, bounce: 0.40)
                .delay(isOpen ? openDelay : closeDelay),
            value: isOpen
        )
        .disabled(!isOpen)
        .accessibilityHidden(!isOpen)
    }

    private func position(for index: Int) -> CGSize {
        guard !items.isEmpty else { return .zero }
        // Tight fan around the vertical, biased upward.
        let startDeg = 145.0
        let endDeg = 35.0
        let span = startDeg - endDeg
        let step = items.count > 1 ? span / Double(items.count - 1) : 0
        let deg = startDeg - step * Double(index)
        let rad = deg * .pi / 180
        return CGSize(
            width: cos(rad) * radius,
            height: -sin(rad) * radius
        )
    }

    // MARK: - Tap handling

    private func handleTap(_ item: CreateActionItem) {
        withAnimation(.spring(duration: 0.22, bounce: 0.25)) {
            isOpen = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            item.action()
        }
    }
}
