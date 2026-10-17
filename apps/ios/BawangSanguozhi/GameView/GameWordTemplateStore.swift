import Foundation

/// A user-labelled, exact 2-character bitmap from the running game.
/// This is a repeatable fallback for low-resolution Han glyphs that iOS OCR
/// often cannot recognise. It does not write to the ROM or guest VRAM.
struct GameWordTemplate: Codable {
    let width: Int
    let height: Int
    let pixels: Data  // BGRA, 4 bytes per native pixel
}

final class GameWordTemplateStore {
    static let shared = GameWordTemplateStore()
    private let lock = NSLock()
    private var recentFrame: Data?
    private var recentWidth = 320
    private var trained: GameWordTemplate?
    private let key = "BawangLiuBeiPixelTemplateV1"

    init(storage: UserDefaults = .standard) {
        if let data = storage.data(forKey: key) {
            trained = try? PropertyListDecoder().decode(GameWordTemplate.self, from: data)
        }
        self.storage = storage
    }
    private let storage: UserDefaults

    func capture(_ frame: Data, width: Int) {
        guard frame.count == 320 * 224 * 4 else { return }
        lock.lock()
        recentFrame = frame
        recentWidth = max(1, min(320, width))
        lock.unlock()
    }

    func snapshot() -> (Data, Int)? {
        lock.lock(); defer { lock.unlock() }
        guard let frame = recentFrame else { return nil }
        return (frame, recentWidth)
    }

    var isCalibrated: Bool {
        lock.lock(); defer { lock.unlock() }
        return trained != nil
    }

    @discardableResult
    func calibrate(frame: Data, x: Int, y: Int, width: Int, height: Int) -> Bool {
        guard frame.count == 320 * 224 * 4,
              x >= 0, y >= 0, width >= 20, width <= 80,
              height >= 10, height <= 32, x + width <= 320,
              y + height <= 224 else { return false }
        let input = [UInt8](frame)
        var output = [UInt8]()
        output.reserveCapacity(width * height * 4)
        var counts: [UInt32: Int] = [:]
        for yy in y..<(y + height) {
            for xx in x..<(x + width) {
                let i = (yy * 320 + xx) * 4
                output.append(contentsOf: input[i..<(i + 4)])
                let c = UInt32(input[i]) | UInt32(input[i+1]) << 8 |
                    UInt32(input[i+2]) << 16 | UInt32(input[i+3]) << 24
                counts[c, default: 0] += 1
            }
        }
        let ordered = counts.sorted { $0.value > $1.value }
        guard let background = ordered.first,
              background.value * 100 >= width * height * 30,
              let ink = ordered.dropFirst().first(where: { $0.value >= 6 }) else { return false }
        let luminance: (UInt32) -> Int = { c in
            Int(c & 255) + Int((c >> 8) & 255) + Int((c >> 16) & 255)
        }
        guard abs(luminance(background.key) - luminance(ink.key)) >= 100 else { return false }
        let newTemplate = GameWordTemplate(width: width, height: height, pixels: Data(output))
        guard let encoded = try? PropertyListEncoder().encode(newTemplate) else { return false }
        lock.lock()
        trained = newTemplate
        lock.unlock()
        storage.set(encoded, forKey: key)
        return true
    }

    func clear() {
        lock.lock(); trained = nil; lock.unlock()
        storage.removeObject(forKey: key)
    }

    func find(in frame: Data, visibleWidth: Int, maxResults: Int = 12) -> [GameLocalizedWordRegion] {
        lock.lock()
        let template = trained
        lock.unlock()
        guard let t = template, t.pixels.count == t.width * t.height * 4,
              frame.count == 320 * 224 * 4,
              visibleWidth >= t.width else { return [] }
        let source = [UInt8](frame), sample = [UInt8](t.pixels)
        let w = t.width, h = t.height
        let maxX = min(320, visibleWidth) - w
        let maxY = 224 - h
        // Select both ink/background sample coordinates so a large flat
        // rectangle cannot register as a match.
        let positions: [Int] = [0, w - 1, (h - 1) * w,
                                h * w - 1, (h / 2) * w + w / 2,
                                (h / 3) * w + w / 3,
                                (h * 2 / 3) * w + w * 2 / 3]
        func approximate(_ a: Int, _ b: Int) -> Bool {
            abs(Int(source[a]) - Int(sample[b])) <= 14 &&
            abs(Int(source[a + 1]) - Int(sample[b + 1])) <= 14 &&
            abs(Int(source[a + 2]) - Int(sample[b + 2])) <= 14
        }
        var found: [GameLocalizedWordRegion] = []
        for y in 0...maxY {
            for x in 0...maxX {
                var anchorsMatch = true
                for p in positions {
                    let sx = p % w, sy = p / w
                    if !approximate(((y + sy) * 320 + x + sx) * 4, p * 4) {
                        anchorsMatch = false; break
                    }
                }
                if !anchorsMatch { continue }
                var matches = 0
                // Compare all pixels only after cheap anchor rejection.
                for sy in 0..<h {
                    for sx in 0..<w {
                        if approximate(((y + sy) * 320 + x + sx) * 4,
                                       (sy * w + sx) * 4) { matches += 1 }
                    }
                }
                guard matches * 100 >= w * h * 96,
                      let hash = GameLocalizedWordPainter.fingerprint(frame,
                        x:x, y:y, width:w, height:h) else { continue }
                found.append(GameLocalizedWordRegion(x:x, y:y, width:w,
                                                    height:h, sourceFingerprint:hash))
                if found.count >= maxResults { return found }
            }
        }
        return found
    }
}
