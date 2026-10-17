import SwiftUI
import UIKit

private final class PadTouchControl: UIControl {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    private var pressed = false {
        didSet { backgroundColor = pressed ? UIColor.orange.withAlphaComponent(0.88)
                                      : UIColor.darkGray.withAlphaComponent(0.78) }
    }

    init(title: String, diameter: CGFloat) {
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        layer.cornerRadius = diameter / 2
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        backgroundColor = UIColor.darkGray.withAlphaComponent(0.78)
        let label = UILabel(frame: .zero)
        label.text = title
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: title.count > 1 ? 12 : 20)
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        accessibilityLabel = title
        isAccessibilityElement = true
        addTarget(self, action: #selector(down), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(up), for: [.touchUpInside, .touchUpOutside,
                                                    .touchCancel, .touchDragExit])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func down() {
        guard !pressed else { return }
        pressed = true
        onPress?()
    }

    @objc private func up() {
        guard pressed else { return }
        pressed = false
        onRelease?()
    }

    func cancelPress() { up() }
}

private struct PadButton: UIViewRepresentable {
    let title: String
    let mask: UInt16
    let session: GameSession
    var diameter: CGFloat = 48

    func makeUIView(context: Context) -> PadTouchControl {
        let control = PadTouchControl(title: title, diameter: diameter)
        control.onPress = { session.press(mask) }
        control.onRelease = { session.release(mask) }
        return control
    }

    func updateUIView(_ control: PadTouchControl, context: Context) {
        if session.paused || !session.running { control.cancelPress() }
    }
}

struct VirtualPad: View {
    let session: GameSession

    var body: some View {
        GeometryReader { area in
            HStack(alignment: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    PadButton(title: "↑", mask: 0x01, session: session).frame(width: 48, height: 48)
                    HStack(spacing: 42) {
                        PadButton(title: "←", mask: 0x04, session: session).frame(width: 48, height: 48)
                        PadButton(title: "→", mask: 0x08, session: session).frame(width: 48, height: 48)
                    }
                    PadButton(title: "↓", mask: 0x02, session: session).frame(width: 48, height: 48)
                }
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    PadButton(title: "START", mask: 0x80, session: session)
                        .frame(width: 48, height: 48)
                    HStack(spacing: 5) {
                        PadButton(title: "A", mask: 0x40, session: session).frame(width: 48, height: 48)
                        PadButton(title: "B", mask: 0x10, session: session).frame(width: 48, height: 48)
                        PadButton(title: "C", mask: 0x20, session: session).frame(width: 48, height: 48)
                    }
                }
            }
            .padding(.horizontal, max(8, area.safeAreaInsets.leading))
            .padding(.bottom, max(8, area.safeAreaInsets.bottom))
            .frame(width: area.size.width, height: area.size.height, alignment: .bottom)
        }
    }
}
