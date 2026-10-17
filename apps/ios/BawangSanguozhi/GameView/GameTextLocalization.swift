import Foundation
#if canImport(Vision) && canImport(CoreGraphics)
import Vision
import CoreGraphics
#endif

/// Experimental, presentation-only proof of concept for one exact phrase.
/// Does not change ROM, VRAM, game logic, SRAM or the original language table.
/// A later ROM/VDP glyph-map implementation should replace this OCR fallback.
struct GameLocalizedWordRegion: Equatable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let sourceFingerprint: UInt64
}

enum GameLocalizedWordPainter {
    static let stridePixels = 320
    static let screenHeight = 224
    private static let rowLiu: [UInt16] = [
        0x0000, 0x0000, 0x0800, 0x0C06, 0x0426, 0x7FA6, 0x0326, 0x0226,
        0x2226, 0x3626, 0x1E26, 0x0C26, 0x0E26, 0x0E26, 0x1B06, 0x3106
    ]
    private static let rowBei: [UInt16] = [
        0x0000, 0x0000, 0x0200, 0x0600, 0x0FF8, 0x1C30, 0x7660, 0x03C0,
        0x1E78, 0x780E, 0x1FF8, 0x1188, 0x1188, 0x1FF8, 0x1188, 0x1188
    ]

    static func fingerprint(_ frame: Data, x: Int, y: Int, width: Int, height: Int) -> UInt64? {
        guard frame.count == stridePixels * screenHeight * 4,
              x >= 0, y >= 0, width > 0, height > 0,
              x + width <= stridePixels, y + height <= screenHeight else { return nil }
        let pixels = [UInt8](frame)
        var hash: UInt64 = 0xcbf29ce484222325
        for yy in y..<(y + height) {
            for xx in x..<(x + width) {
                let i = (yy * stridePixels + xx) * 4
                for b in i..<(i + 4) {
                    hash = (hash ^ UInt64(pixels[b])) &* 0x100000001b3
                }
            }
        }
        return hash
    }

    /// Only replaces an OCR-confirmed, *unchanged* region on a sufficiently flat
    /// background. Bail out rather than painting a rectangle over map artwork.
    static func render(_ frame: Data, region: GameLocalizedWordRegion) -> Data {
        guard let hash = fingerprint(frame, x: region.x, y: region.y,
                                     width: region.width, height: region.height),
              hash == region.sourceFingerprint,
              region.width >= 20, region.width <= 88,
              region.height >= 10, region.height <= 34 else { return frame }
        var bytes = [UInt8](frame)
        var histogram: [UInt32: Int] = [:]
        for y in region.y..<(region.y + region.height) {
            for x in region.x..<(region.x + region.width) {
                let i = (y * stridePixels + x) * 4
                let c = UInt32(bytes[i]) | UInt32(bytes[i+1]) << 8 |
                    UInt32(bytes[i+2]) << 16 | UInt32(bytes[i+3]) << 24
                histogram[c, default: 0] += 1
            }
        }
        let sorted = histogram.sorted { $0.value > $1.value }
        guard let backdrop = sorted.first,
              Double(backdrop.value) / Double(region.width * region.height) >= 0.35,
              let foreground = sorted.dropFirst().first(where: { $0.value >= 3 }) else { return frame }
        let bg = backdrop.key, fg = foreground.key
        let brightness: (UInt32) -> Int = { v in
            Int((v >> 16) & 255) + Int((v >> 8) & 255) + Int(v & 255)
        }
        guard abs(brightness(bg) - brightness(fg)) >= 100 else { return frame }

        func write(_ color: UInt32, at x: Int, _ y: Int) {
            let i = (y * stridePixels + x) * 4
            bytes[i] = UInt8(truncatingIfNeeded: color)
            bytes[i+1] = UInt8(truncatingIfNeeded: color >> 8)
            bytes[i+2] = UInt8(truncatingIfNeeded: color >> 16)
            bytes[i+3] = UInt8(truncatingIfNeeded: color >> 24)
        }
        // Constrained to OCR's text box. In a flat text-panel background this
        // removes the old traditional glyphs before drawing the two new glyphs.
        for yy in 0..<region.height {
            for xx in 0..<region.width {
                write(bg, at: region.x + xx, region.y + yy)
            }
        }
        for yy in 0..<region.height {
            let glyphY = min(15, yy * 16 / region.height)
            for xx in 0..<region.width {
                let half = xx < region.width / 2
                let localX = half ? xx : xx - region.width / 2
                let localWidth = half ? region.width / 2 : region.width - region.width / 2
                let glyphX = min(15, localX * 16 / max(1, localWidth))
                let row = half ? rowLiu[glyphY] : rowBei[glyphY]
                if row & (UInt16(1) << (15 - glyphX)) != 0 {
                    write(fg, at: region.x + xx, region.y + yy)
                }
            }
        }
        return Data(bytes)
    }
}

final class GameTextLocalization {
    private var counter: UInt64 = 0
    private var scanning = false
    private var detected: [GameLocalizedWordRegion] = []
    private let lock = NSLock()
    private let recognitionQueue = DispatchQueue(label: "Bawang.TextLocalization", qos: .utility)

    func reset() {
        lock.lock()
        detected = []
        lock.unlock()
    }

    func present(_ frame: Data, visibleWidth: Int, simplified: Bool) -> Data {
        guard simplified, frame.count == 320 * 224 * 4 else { reset(); return frame }
        counter += 1
        // Prefer the native-pixel template explicitly marked by the user.
        // ROM text is usually 16px bitmap lettering and is unreliable for OCR.
        if GameWordTemplateStore.shared.isCalibrated {
            // A template match is performed against the *current* frame, so
            // menu blink/cursor movement cannot invalidate a stale OCR hash.
            var output = frame
            for box in GameWordTemplateStore.shared.find(in: frame, visibleWidth: visibleWidth) {
                output = GameLocalizedWordPainter.render(output, region: box)
            }
            return output
        }
        if counter % 20 == 1 {
            lock.lock()
            let shouldScan = !scanning
            if shouldScan { scanning = true }
            lock.unlock()
            if shouldScan {
                let capture = frame
                let width = max(1, min(320, visibleWidth))
                recognitionQueue.async { [weak self] in
                    guard let self else { return }
                    let matches = self.detectExactTraditionalPhrase(in: capture, width: width)
                    self.lock.lock()
                    self.detected = matches
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(matches.count, forKey: "BawangTextLocalizationLastHits")
                    }
                    self.scanning = false
                    self.lock.unlock()
                }
            }
        }
        lock.lock()
        let regions = detected
        lock.unlock()
        var output = frame
        for region in regions {
            output = GameLocalizedWordPainter.render(output, region: region)
        }
        return output
    }

    private func detectExactTraditionalPhrase(in frame: Data, width: Int) -> [GameLocalizedWordRegion] {
#if canImport(Vision) && canImport(CoreGraphics)
        // The first experiment is intentionally exact-match only: no other
        // officer names, event dialogue, or arbitrary OCR text are modified.
        guard let provider = CGDataProvider(data: frame as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let full = CGImage(width: 320, height: 224, bitsPerComponent: 8,
                                 bitsPerPixel: 32, bytesPerRow: 320 * 4, space: space,
                                 bitmapInfo: CGBitmapInfo.byteOrder32Little.union(
                                     CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)),
                                 provider: provider, decode: nil, shouldInterpolate: false,
                                 intent: .defaultIntent),
              let clipped = full.cropping(to: CGRect(x: 0, y: 0, width: width, height: 224)),
              let context = CGContext(data: nil, width: width * 4, height: 224 * 4,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return [] }
        context.interpolationQuality = .none
        context.draw(clipped, in: CGRect(x: 0, y: 0, width: width * 4, height: 224 * 4))
        guard let enlarged = context.makeImage() else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hant"]
        let handler = VNImageRequestHandler(cgImage: enlarged, options: [:])
        do { try handler.perform([request]) }
        catch { return [] } // Unsupported recognition language: fail closed.
        return (request.results ?? []).compactMap { observation -> GameLocalizedWordRegion? in
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.30,
                  candidate.string.filter({ !$0.isWhitespace }) == "劉備" else { return nil }
            let b = observation.boundingBox
            let x = max(0, Int(floor(b.minX * CGFloat(width))))
            let y = max(0, Int(floor((1 - b.maxY) * 224)))
            let w = min(width - x, Int(ceil(b.width * CGFloat(width))))
            let h = min(224 - y, Int(ceil(b.height * 224)))
            guard let hash = GameLocalizedWordPainter.fingerprint(frame, x: x, y: y,
                                                                 width: w, height: h) else { return nil }
            return GameLocalizedWordRegion(x: x, y: y, width: w,
                                           height: h, sourceFingerprint: hash)
        }
#else
        return []
#endif
    }
}
