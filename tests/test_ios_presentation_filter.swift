import Foundation

private func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
}

private func coloredFrame(_ rgb: (UInt8, UInt8, UInt8)) -> Data {
    var bytes = [UInt8](repeating: 255, count: 320 * 224 * 4)
    for i in stride(from: 0, to: bytes.count, by: 4) {
        bytes[i] = rgb.2; bytes[i + 1] = rgb.1; bytes[i + 2] = rgb.0
    }
    return Data(bytes)
}

private func paint(_ data: Data, xRange: Range<Int>, yRange: Range<Int>,
                   rgb: (UInt8, UInt8, UInt8)) -> Data {
    var b = [UInt8](data)
    for y in yRange {
        for x in xRange {
            let i = (y * 320 + x) * 4
            b[i] = rgb.2; b[i + 1] = rgb.1; b[i + 2] = rgb.0
        }
    }
    return Data(b)
}

@main
struct PresentationTests {
    static func main() {
        let f = GameFramePresentationFilter()
        let menu = coloredFrame((168, 204, 155))
        let corrupted = paint(menu, xRange: 25..<215, yRange: 12..<50,
                              rgb: (8, 8, 130))
        expect(f.present(menu, visibleWidth: 256) == menu, "initial menu")
        expect(f.present(corrupted, visibleWidth: 256) == menu,
               "partial top-row corruption must be held")
        // A real full-screen transition must not be frozen.
        let black = coloredFrame((0, 0, 0))
        expect(f.present(black, visibleWidth: 256) == black,
               "full-screen black transition should appear immediately")
        f.reset()
        expect(f.present(menu, visibleWidth: 256) == menu, "restart")
        for _ in 0..<8 {
            expect(f.present(corrupted, visibleWidth: 256) == menu,
                   "hold transient title row, not background")
        }
        expect(f.present(corrupted, visibleWidth: 256) == corrupted,
               "legitimate persistent title change eventually becomes visible")

        f.reset()
        let map = coloredFrame((218, 190, 116))
        let suddenBlackTile = paint(map, xRange: 96..<112, yRange: 80..<96,
                                    rgb: (0, 0, 0))
        expect(f.present(map, visibleWidth: 320) == map, "initial map")
        expect(f.present(suddenBlackTile, visibleWidth: 320) == map,
               "small sudden black tile should preserve last-known display")
        // The guard only works for transient drops; persistent true black wins.
        var eventual = map
        for _ in 0..<38 { eventual = f.present(suddenBlackTile, visibleWidth: 320) }
        expect(eventual == suddenBlackTile, "persistent black must not be suppressed indefinitely")
        f.reset()
        expect(f.present(map, visibleWidth: 320) == map, "map reset")
        let smallBlackText = paint(map, xRange: 96..<99, yRange: 80..<88,
                                   rgb: (0, 0, 0))
        expect(f.present(smallBlackText, visibleWidth: 320) == smallBlackText,
               "narrow black font stroke must remain visible")
        f.reset()
        expect(f.present(map, visibleWidth: 320) == map, "map reset for fade")
        expect(f.present(black, visibleWidth: 320) == black,
               "scene-wide fade must not be suppressed")
        for (w, h) in [(1112, 512), (844, 390), (1800, 800), (960, 440)] {
            for sw in [Float(256), Float(320)] {
                let s = GameDisplayGeometry.normalizedHalfSize(
                    canvasWidth: Float(w), canvasHeight: Float(h), sourceWidth: sw)
                let dw = Float(w) * s.0, dh = Float(h) * s.1
                expect(dw > 0 && dh > 0 && dw <= Float(w) && dh <= Float(h), "viewport bounds")
                expect(abs(dw/dh - sw/224) < 0.0002, "no aspect distortion")
            }
        }
        print("PASS: partial-menu transition, full fade, transient map blackout, persistent black, normal text, scaling")
    }
}
