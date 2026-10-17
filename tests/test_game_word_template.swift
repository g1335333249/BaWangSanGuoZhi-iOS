import Foundation

@main struct TestGameWordTemplate {
    static func main() {
        let preferences = UserDefaults(suiteName: "BawangUnitWordTemplate_\(UUID().uuidString)")!
        let store = GameWordTemplateStore(storage: preferences)
        var bytes = [UInt8](repeating: 0, count: 320*224*4)
        for i in stride(from: 3, to: bytes.count, by: 4) { bytes[i] = 255 }
        for y in 90..<106 {
            for x in 44..<76 where ((x ^ y) & 3) != 0 {
                let i = (y*320 + x)*4
                bytes[i] = 245; bytes[i+1] = 245; bytes[i+2] = 245
            }
        }
        let f = Data(bytes)
        precondition(store.calibrate(frame: f, x: 44, y: 90, width: 32, height: 16))
        precondition(store.isCalibrated)
        let results = store.find(in: f, visibleWidth: 320)
        precondition(results.contains { $0.x == 44 && $0.y == 90 })
        let output = GameLocalizedWordPainter.render(f, region: results.first { $0.x == 44 && $0.y == 90 }!)
        precondition(output != f)
        let reload = GameWordTemplateStore(storage: preferences)
        precondition(reload.find(in: f, visibleWidth: 320).contains { $0.x == 44 && $0.y == 90 })
        reload.clear()
        precondition(reload.find(in: f, visibleWidth: 320).isEmpty)
        print("PASS calibrated ROM-font template detection, persistence, glyph replacement and clear")
    }
}
