import Foundation

@main struct GameTextLocalizationTests {
    static func main() {
        let width = 320, height = 224
        let baseColor: [UInt8] = [0, 0, 0, 255]
        let textColor: [UInt8] = [255, 255, 255, 255]
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                pixels[i..<(i+4)] = baseColor[0..<4]
            }
        }
        for y in 70..<86 {
            for x in 30..<62 where (x + y) % 5 == 0 {
                let i = (y * width + x) * 4
                pixels[i..<(i+4)] = textColor[0..<4]
            }
        }
        let original = Data(pixels)
        guard let fingerprint = GameLocalizedWordPainter.fingerprint(original, x:30,y:70,width:32,height:16) else { fatalError("hash") }
        let box = GameLocalizedWordRegion(x:30,y:70,width:32,height:16,sourceFingerprint:fingerprint)
        let newFrame = GameLocalizedWordPainter.render(original,region:box)
        precondition(newFrame != original, "expected simplified test glyphs to replace the original bitmap")
        precondition(newFrame.count == original.count)
        precondition(newFrame.prefix(2000) == original.prefix(2000), "unrelated pixels changed")
        precondition(GameLocalizedWordPainter.render(newFrame,region:box) == newFrame, "stale fingerprint must not overwrite new pixels")
        let wrongBox = GameLocalizedWordRegion(x:30,y:70,width:32,height:16,sourceFingerprint:0)
        precondition(GameLocalizedWordPainter.render(original,region:wrongBox) == original)
        let invalidBox = GameLocalizedWordRegion(x:-1,y:70,width:32,height:16,sourceFingerprint:fingerprint)
        precondition(GameLocalizedWordPainter.render(original,region:invalidBox) == original)
        let flat = Data([UInt8](repeating: 0, count: width*height*4))
        let flatHash = GameLocalizedWordPainter.fingerprint(flat,x:30,y:70,width:32,height:16)!
        let flatBox = GameLocalizedWordRegion(x:30,y:70,width:32,height:16,sourceFingerprint:flatHash)
        precondition(GameLocalizedWordPainter.render(flat,region:flatBox) == flat, "flat area must not gain glyphs")
        print("PASS: exact-match region, single-target painter, stale-region safety, bounds, flat-field safety")
    }
}
