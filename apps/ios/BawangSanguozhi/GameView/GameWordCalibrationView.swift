import SwiftUI
import UIKit

/// The player marks the exact two-character bitmap once, avoiding fragile OCR
/// on 16-pixel traditional-Chinese glyphs. The template stores only a small
/// screenshot selection in local preferences, never ROM or save-game bytes.
struct GameWordCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void
    @State private var captured = GameWordTemplateStore.shared.snapshot()
    @State private var first: CGPoint?
    @State private var selected = CGRect.zero
    @State private var notice = "请在下面的画面上框选完整的『劉備』两个字。"

    private func image(from frame: Data) -> UIImage? {
        guard let source = CGDataProvider(data: frame as CFData),
              let rgb = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGImage(width: 320, height: 224, bitsPerComponent: 8,
                               bitsPerPixel: 32, bytesPerRow: 320 * 4,
                               space: rgb,
                               bitmapInfo: CGBitmapInfo.byteOrder32Little.union(
                                 CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)),
                               provider: source, decode: nil, shouldInterpolate: false,
                               intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Text(notice).font(.footnote).multilineTextAlignment(.center)
                if let screenshot = captured?.0, let preview = image(from: screenshot) {
                    GeometryReader { geometry in
                        let scale = min(geometry.size.width / 320, geometry.size.height / 224)
                        let rw = 320 * scale, rh = 224 * scale
                        let ox = (geometry.size.width - rw) / 2
                        let oy = (geometry.size.height - rh) / 2
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: preview)
                                .resizable()
                                .interpolation(.none)
                                .frame(width: rw, height: rh)
                                .position(x: ox + rw / 2, y: oy + rh / 2)
                            if !selected.isEmpty {
                                Rectangle().stroke(Color.orange, lineWidth: 2)
                                    .background(Color.orange.opacity(0.16))
                                    .frame(width: selected.width * scale,
                                           height: selected.height * scale)
                                    .position(x: ox + selected.midX * scale,
                                              y: oy + selected.midY * scale)
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 4)
                            .onChanged { event in
                                func coord(_ point: CGPoint) -> CGPoint {
                                    CGPoint(x: max(0, min(320, (point.x - ox) / scale)),
                                            y: max(0, min(224, (point.y - oy) / scale)))
                                }
                                if first == nil { first = coord(event.startLocation) }
                                let start = first ?? coord(event.startLocation)
                                let end = coord(event.location)
                                selected = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                                                  width: abs(end.x - start.x),
                                                  height: abs(end.y - start.y))
                            }.onEnded { _ in first = nil })
                    }
                    .frame(height: 245)
                    Text("建议框选约 32×16 像素，尽量贴近文字边缘，避免包括光标、边框。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("保存『劉備』字形样本") {
                        let rect = selected.integral
                        let success = GameWordTemplateStore.shared.calibrate(
                            frame: screenshot,
                            x: Int(rect.minX), y: Int(rect.minY),
                            width: Int(rect.width), height: Int(rect.height))
                        if success { onSaved(); dismiss() }
                        else { notice = "选区必须是 20–80 × 10–32 像素的双字文本且背景清晰，请重新框选。" }
                    }
                    .disabled(selected.isEmpty)
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("尚无可标定的游戏画面。请进入游戏，让『劉備』显示出来后再打开。")
                        .font(.footnote)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("校准简体字形")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("关闭") { dismiss() }
            }}
        }
    }
}
