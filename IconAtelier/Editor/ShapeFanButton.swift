import SwiftUI

struct ShapeFanItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let label: String
    let action: () -> Void

    static func == (lhs: ShapeFanItem, rhs: ShapeFanItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct ShapeFanButton: View {
    let items: [ShapeFanItem]
    @Binding var isOpen: Bool

    private let centerSize: CGFloat = 60
    private let miniSize: CGFloat = 56
    private let radius: CGFloat = 110

    var body: some View {
        ZStack {
            backdrop
            miniButtons
            centralButton
        }
        .frame(width: centerSize, height: centerSize)
        .sensoryFeedback(.impact(weight: .light), trigger: isOpen)
    }

    private var backdrop: some View {
        Circle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: centerSize, height: centerSize)
            .scaleEffect(isOpen ? 4.0 : 1.0)
            .opacity(isOpen ? 1.0 : 0.0)
            .blur(radius: isOpen ? 16 : 0)
            .animation(.smooth(duration: 0.28), value: isOpen)
            .allowsHitTesting(false)
    }

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
        .accessibilityLabel(isOpen ? "Close add menu" : "Add layer")
    }

    private var miniButtons: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            miniButton(item: item, index: index)
        }
    }

    private func miniButton(item: ShapeFanItem, index: Int) -> some View {
        let target = position(for: index)
        let openDelay = Double(index) * 0.025
        let closeDelay = Double(items.count - 1 - index) * 0.015

        return Button {
            handleTap(item)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
                Image(systemName: item.symbol)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(uiColor: .systemBackground))
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

        let startDeg = 180.0
        let endDeg = 0.0
        let span = startDeg - endDeg
        let step = items.count > 1 ? span / Double(items.count - 1) : 0
        let deg = startDeg - step * Double(index)
        let rad = deg * .pi / 180
        return CGSize(
            width: cos(rad) * radius,
            height: -sin(rad) * radius
        )
    }

    private func handleTap(_ item: ShapeFanItem) {
        withAnimation(.spring(duration: 0.22, bounce: 0.25)) {
            isOpen = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            item.action()
        }
    }
}
