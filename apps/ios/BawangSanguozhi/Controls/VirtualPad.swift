import SwiftUI
import UIKit

private final class PadTouchControl: UIControl {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    private var pressed = false {
        didSet { backgroundColor = pressed ? UIColor.orange.withAlphaComponent(0.72)
                                      : UIColor.darkGray.withAlphaComponent(0.31) }
    }

    init(title: String, diameter: CGFloat) {
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        layer.cornerRadius = diameter / 2
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        backgroundColor = UIColor.darkGray.withAlphaComponent(0.31)
        let label = UILabel(frame: .zero)
        label.text = title
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: title.count > 1 ? max(13, diameter * 0.25) : diameter * 0.41)
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
        control.layer.cornerRadius = diameter / 2
        if session.paused || !session.running { control.cancelPress() }
    }
}

struct VirtualPad: View {
    let session: GameSession

    var body: some View {
        GeometryReader { area in
            // 48pt was too small on wide phones. Adapt 52..68pt so smaller
            // landscape devices still retain a large touch target.
            let d = min(CGFloat(68), max(CGFloat(52), area.size.width * 0.059))
            // Three-column cross: left/right and up/down are equally far
            // from the empty centre. The old 2-button middle row was cramped.
            let crossGap = min(CGFloat(15), max(CGFloat(9), d * 0.16))
            HStack(alignment: .bottom, spacing: 0) {
                VStack(spacing: crossGap) {
                    HStack(spacing: crossGap) {
                        Color.clear.frame(width: d, height: d).allowsHitTesting(false)
                        PadButton(title: "↑", mask: 0x01, session: session, diameter: d)
                            .frame(width: d, height: d)
                        Color.clear.frame(width: d, height: d).allowsHitTesting(false)
                    }
                    HStack(spacing: crossGap) {
                        PadButton(title: "←", mask: 0x04, session: session, diameter: d)
                            .frame(width: d, height: d)
                        Color.clear.frame(width: d, height: d).allowsHitTesting(false)
                        PadButton(title: "→", mask: 0x08, session: session, diameter: d)
                            .frame(width: d, height: d)
                    }
                    HStack(spacing: crossGap) {
                        Color.clear.frame(width: d, height: d).allowsHitTesting(false)
                        PadButton(title: "↓", mask: 0x02, session: session, diameter: d)
                            .frame(width: d, height: d)
                        Color.clear.frame(width: d, height: d).allowsHitTesting(false)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 9) {
                    PadButton(title: "START", mask: 0x80, session: session, diameter: d)
                        .frame(width: d, height: d)
                    HStack(spacing: 5) {
                        PadButton(title: "A", mask: 0x40, session: session, diameter: d)
                            .frame(width: d, height: d)
                        PadButton(title: "B", mask: 0x10, session: session, diameter: d)
                            .frame(width: d, height: d)
                        PadButton(title: "C", mask: 0x20, session: session, diameter: d)
                            .frame(width: d, height: d)
                    }
                }
            }
            .padding(.leading, max(9, area.safeAreaInsets.leading))
            .padding(.trailing, max(9, area.safeAreaInsets.trailing))
            .padding(.bottom, max(9, area.safeAreaInsets.bottom))
            .frame(width: area.size.width, height: area.size.height, alignment: .bottom)
        }
    }
}
