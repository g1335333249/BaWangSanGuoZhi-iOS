import Foundation

/// The game stays at 256/320 x 224 internally. Only its presentation scales.
/// Reserve equal side bands for the bottom-left and bottom-right touch pads.
enum GameDisplayGeometry {
    static func normalizedHalfSize(canvasWidth: Float, canvasHeight: Float,
                                   sourceWidth: Float, sourceHeight: Float = 224) -> (Float, Float) {
        let w = max(1, canvasWidth), h = max(1, canvasHeight)
        let sw = max(1, sourceWidth), sh = max(1, sourceHeight)
        let sideReserve = min(230, max(118, w * 0.185))
        let useWidth = max(1, w - 2 * sideReserve)
        let useHeight = max(1, h - 12)
        let scale = min(useWidth / sw, useHeight / sh)
        return (sw * scale / w, sh * scale / h)
    }
}
