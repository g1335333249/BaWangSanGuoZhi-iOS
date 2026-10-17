import SwiftUI

private struct PadButton: View {
    let title: String
    let mask: UInt16
    let session: GameSession
    var diameter: CGFloat = 48
    @State private var held = false

    var body: some View {
        Text(title)
            .font(.system(size: title.count > 1 ? 12 : 20, weight: .bold))
            .frame(width: diameter, height: diameter)
            .foregroundStyle(.white)
            .background(held ? .orange.opacity(0.88) : .gray.opacity(0.74), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !held { held = true; session.press(mask) }
                }
                .onEnded { _ in held = false; session.release(mask) })
            .accessibilityLabel(title)
    }
}

struct VirtualPad: View {
    let session: GameSession

    var body: some View {
        GeometryReader { area in
            HStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    PadButton(title: "↑", mask: 0x01, session: session)
                    HStack(spacing: 0) {
                        PadButton(title: "←", mask: 0x04, session: session)
                        Color.clear.frame(width: 42, height: 48)
                        PadButton(title: "→", mask: 0x08, session: session)
                    }
                    PadButton(title: "↓", mask: 0x02, session: session)
                }
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    PadButton(title: "START", mask: 0x80, session: session, diameter: 48)
                    HStack(spacing: 5) {
                        PadButton(title: "A", mask: 0x40, session: session)
                        PadButton(title: "B", mask: 0x10, session: session)
                        PadButton(title: "C", mask: 0x20, session: session)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, max(6, area.safeAreaInsets.bottom))
        }
        .allowsHitTesting(true)
    }
}
