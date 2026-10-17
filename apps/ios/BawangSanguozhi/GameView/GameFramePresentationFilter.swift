import Foundation

/// Presentation-only guard against two transient classes of partially written
/// VDP frames. Never changes ROM, VDP, guest RAM, controller state or SRAM.
/// A genuine renderer/timing defect must still be fixed against a VDP oracle.
final class GameFramePresentationFilter {
    private let rowStride = 320
    private let height = 224
    private var previous: Data?
    private var topRowHoldFrames = 0
    private var darkTileHoldFrames: [Int: Int] = [:]

    /// Can be disabled independently for native-vs-oracle screenshot comparisons.
    var suppressPartialMenuFrames = true
    var suppressTransientMapBlackTiles = true
    private let maxMenuHoldFrames = 8
    private let maxDarkTileHoldFrames = 36

    func reset() {
        previous = nil
        topRowHoldFrames = 0
        darkTileHoldFrames.removeAll()
    }

    func present(_ input: Data, visibleWidth: Int) -> Data {
        let width = min(rowStride, max(1, visibleWidth))
        guard input.count == rowStride * height * 4 else { reset(); return input }
        guard let last = previous else { previous = input; return input }

        var topChanges = 0, topCount = 0
        var bottomChanges = 0, bottomCount = 0
        var mapBright = 0, mapSamples = 0
        input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            last.withUnsafeBytes { (old: UnsafeRawBufferPointer) in
                let src = raw.bindMemory(to: UInt8.self)
                let dst = old.bindMemory(to: UInt8.self)
                // Chapter-menu title band (normalised to raw 256/320 x 224).
                // Sample below the band independently: a *whole-screen*
                // transition must NEVER be frozen or interpreted as corruption.
                for y in stride(from: 6, to: 214, by: 4) {
                    for x in stride(from: 12, to: max(13, width - 12), by: 4) {
                        let i = (y * rowStride + x) * 4
                        let changed = abs(Int(src[i]) - Int(dst[i])) > 35 ||
                            abs(Int(src[i + 1]) - Int(dst[i + 1])) > 35 ||
                            abs(Int(src[i + 2]) - Int(dst[i + 2])) > 35
                        if y < 55 { topCount += 1; if changed { topChanges += 1 } }
                        else { bottomCount += 1; if changed { bottomChanges += 1 } }
                        if y < 160 {
                            mapSamples += 1
                            if Int(dst[i]) + Int(dst[i + 1]) + Int(dst[i + 2]) > 350 {
                                mapBright += 1
                            }
                        }
                    }
                }
            }
        }
        let topRatio = Double(topChanges) / Double(max(1, topCount))
        let bottomRatio = Double(bottomChanges) / Double(max(1, bottomCount))
        let partialTitleChange = suppressPartialMenuFrames &&
            topRatio > 0.055 && bottomRatio < 0.008
        if partialTitleChange && topRowHoldFrames < maxMenuHoldFrames {
            topRowHoldFrames += 1
            return last
        }
        topRowHoldFrames = 0

        // The map dropout guard is deliberately narrow: small, almost-solid
        // black rectangular updates against a previously bright tile, while
        // the *rest* of the scene remains stable. It is NOT a VDP bug fix.
        // Global fades, black scene transitions and normal animated sprites
        // are left alone. Any unchanged dark tile expires after 36 frames.
        var output = input
        if suppressTransientMapBlackTiles &&
           bottomRatio < 0.12 && topRatio < 0.12 &&
           mapSamples > 0 && Double(mapBright) / Double(mapSamples) > 0.26 {
            var candidateTiles: [(Int, Int, Int)] = []
            input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                last.withUnsafeBytes { (old: UnsafeRawBufferPointer) in
                    let src = raw.bindMemory(to: UInt8.self)
                    let dst = old.bindMemory(to: UInt8.self)
                    for ty in stride(from: 0, to: 160, by: 8) {
                        for tx in stride(from: 0, to: width - 7, by: 8) {
                            var blackout = 0
                            for y in ty..<(ty + 8) {
                                for x in tx..<(tx + 8) {
                                    let i = (y * rowStride + x) * 4
                                    let before = Int(dst[i]) + Int(dst[i + 1]) + Int(dst[i + 2])
                                    let after = Int(src[i]) + Int(src[i + 1]) + Int(src[i + 2])
                                    if before > 350 && after < 72 { blackout += 1 }
                                }
                            }
                            if blackout >= 43 {
                                let tileKey = ty * 64 + tx / 8
                                candidateTiles.append((ty, tx, tileKey))
                            }
                        }
                    }
                }
            }
            if !candidateTiles.isEmpty && candidateTiles.count <= 12 {
                output.withUnsafeMutableBytes { (newRaw: UnsafeMutableRawBufferPointer) in
                    last.withUnsafeBytes { (oldRaw: UnsafeRawBufferPointer) in
                        let dst = newRaw.bindMemory(to: UInt8.self)
                        let old = oldRaw.bindMemory(to: UInt8.self)
                        for (ty, tx, key) in candidateTiles {
                            let seen = darkTileHoldFrames[key, default: 0]
                            if seen >= maxDarkTileHoldFrames { continue }
                            darkTileHoldFrames[key] = seen + 1
                            for y in ty..<(ty + 8) {
                                for x in tx..<(tx + 8) {
                                    let i = (y * rowStride + x) * 4
                                    let before = Int(old[i]) + Int(old[i + 1]) + Int(old[i + 2])
                                    let after = Int(dst[i]) + Int(dst[i + 1]) + Int(dst[i + 2])
                                    if before > 350 && after < 72 {
                                        dst[i] = old[i]; dst[i + 1] = old[i + 1]
                                        dst[i + 2] = old[i + 2]; dst[i + 3] = old[i + 3]
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                darkTileHoldFrames.removeAll()
            }
        } else {
            darkTileHoldFrames.removeAll()
        }
        previous = output
        return output
    }
}
