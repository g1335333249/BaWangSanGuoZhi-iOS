import Foundation

/// Presentation-only history of flag tiles. This never mutates emulated VRAM,
/// game state or save data. A frame must first show the authentic coloured
/// icon before its pixels can be restored during a later blackout.
final class GameMapFlagRecovery {
    private let stridePixels = 320
    private let height = 224
    private let cellSize = 8
    private let scanHeight = 176
    private var cleanTiles: [Int: [UInt32]] = [:]
    private var lastWasMap = false
    private(set) var restoredCellCount = 0
    var enabled = true

    func reset() {
        cleanTiles.removeAll()
        lastWasMap = false
        restoredCellCount = 0
    }

    private func channels(_ c: UInt32) -> (Int, Int, Int) {
        (Int((c >> 16) & 255), Int((c >> 8) & 255), Int(c & 255))
    }

    private func land(_ c: UInt32) -> Bool {
        let (r,g,b) = channels(c)
        return r >= 175 && g >= 175 && b >= 100 && r - b >= 18 && g - b >= 18
    }

    private func vivid(_ c: UInt32) -> Bool {
        if land(c) { return false }
        let (r,g,b) = channels(c)
        return max(r,g,b) - min(r,g,b) >= 55 && max(r,g,b) >= 120
    }

    private func dark(_ c: UInt32) -> Bool {
        let (r,g,b) = channels(c)
        return r + g + b < 145
    }

    func present(_ frame: Data, visibleWidth: Int) -> Data {
        guard enabled, frame.count == stridePixels * height * 4 else {
            reset(); return frame
        }
        let width = min(stridePixels, max(0, visibleWidth))
        guard width >= 128 else { reset(); return frame }
        let pixels = frame.withUnsafeBytes { raw -> [UInt32] in
            Array(raw.bindMemory(to: UInt32.self))
        }
        // Only activate on the distinctive beige strategy map. In particular,
        // never let a previous flag image bleed into title cards or battle scenes.
        var beigeCount = 0
        for y in stride(from: 32, to: 160, by: 4) {
            for x in stride(from: 8, to: width - 8, by: 4) {
                if land(pixels[y * stridePixels + x]) { beigeCount += 1 }
            }
        }
        let sampleCount = 32 * max(0, (width - 16 + 3) / 4)
        let isMap = sampleCount > 0 && beigeCount * 100 >= sampleCount * 32
        if !isMap {
            if lastWasMap { reset() }
            return frame
        }
        lastWasMap = true

        var output = pixels
        var repaired = 0
        for ty in stride(from: 24, to: scanHeight, by: cellSize) {
            for tx in stride(from: 8, to: width - 7, by: cellSize) {
                let key = ty * 64 + tx / cellSize
                var current: [UInt32] = []
                current.reserveCapacity(64)
                for y in ty..<(ty + cellSize) {
                    for x in tx..<(tx + cellSize) {
                        current.append(pixels[y * stridePixels + x])
                    }
                }
                let vividCount = current.filter(vivid).count
                let landCount = current.filter(land).count
                // A coloured flag must have been observed *on land* in a
                // previous healthy frame. Mountains/sea usually fail this.
                if vividCount >= 4 && landCount >= 5 {
                    cleanTiles[key] = current
                    continue
                }
                guard let old = cleanTiles[key] else { continue }
                let oldColorIndices = old.indices.filter { vivid(old[$0]) }
                guard oldColorIndices.count >= 4 else { continue }
                let lost = oldColorIndices.filter { dark(current[$0]) }.count
                guard lost * 5 >= oldColorIndices.count * 4,
                      vividCount <= 2, landCount >= 4 else { continue }
                // Restore *only* the pixels that became anomalously dark;
                // regular map redraw, new coloured flags and text are untouched.
                var didRepair = false
                for i in 0..<64 where dark(current[i]) && !dark(old[i]) {
                    let y = ty + i / cellSize, x = tx + i % cellSize
                    output[y * stridePixels + x] = old[i]
                    didRepair = true
                }
                if didRepair { repaired += 1 }
            }
        }
        restoredCellCount = repaired
        guard repaired > 0 else { return frame }
        return output.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
