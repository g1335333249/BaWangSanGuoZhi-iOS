import Foundation

@main struct TestFlagRecovery {
    static func main() {
        let w = 320, h = 224
        let beige: UInt32 = 0xFFFFFFAA
        let purple: UInt32 = 0xFF7F20BC
        let dark: UInt32 = 0xFF050505
        func base() -> [UInt32] {
            var v = [UInt32](repeating: 0xFF000000, count: w * h)
            for y in 0..<185 { for x in 0..<w { v[y*w+x] = beige } }
            return v
        }
        func drawFlag(_ a: inout [UInt32], color: UInt32) {
            for y in 86..<94 { for x in 64..<72 {
                // 6 vivid pixels per row, two beige border pixels.
                if x > 64 && x < 71 { a[y*w+x] = color }
            }}
        }
        func frame(_ a: [UInt32]) -> Data {
            a.withUnsafeBufferPointer { Data(buffer: $0) }
        }
        var healthy = base()
        drawFlag(&healthy, color: purple)
        let guarder = GameMapFlagRecovery()
        precondition(guarder.present(frame(healthy), visibleWidth: 320) == frame(healthy))
        var broken = healthy
        drawFlag(&broken, color: dark)
        let out = guarder.present(frame(broken), visibleWidth: 320)
        precondition(out != frame(broken), "previously coloured flag not repaired")
        let pixels = out.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
        precondition(pixels[90*w + 67] == purple, "flag not restored")
        precondition(pixels[70*w + 67] == beige, "unrelated map pixel modified")
        precondition(guarder.restoredCellCount > 0)
        // Valid new ownership colour takes precedence over old cache.
        var ownershipChange = healthy
        drawFlag(&ownershipChange, color: 0xFFCC2828)
        let changed = guarder.present(frame(ownershipChange), visibleWidth: 320)
        precondition(changed == frame(ownershipChange), "genuine colour change must survive")
        // Scene transition must invalidate the old map cache.
        let black = frame([UInt32](repeating: dark, count: w*h))
        precondition(guarder.present(black, visibleWidth: 320) == black)
        precondition(guarder.restoredCellCount == 0)
        precondition(guarder.present(frame(broken), visibleWidth: 320) == frame(broken),
                     "must not restore icons learned in another scene")
        print("PASS flag restore, ownership update, scene reset and no other pixels affected")
    }
}
