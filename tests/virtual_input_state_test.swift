import Foundation

@main
struct VirtualInputStateTest {
    static func main() {
        let input = VirtualInputState()

        input.press(0x40); input.release(0x40)
        assert((0..<3).allSatisfy { _ in input.sample() & 0x40 != 0 })
        assert(input.sample() & 0x40 == 0)

        input.press(0x80); input.release(0x80)
        assert((0..<3).allSatisfy { _ in input.sample() & 0x80 != 0 })
        assert(input.sample() == 0)

        input.press(0x01)
        assert((0..<8).allSatisfy { _ in input.sample() == 0x01 })
        input.release(0x01)
        assert(input.sample() == 0)

        input.press(0x40); input.release(0x40)
        input.press(0x40); input.release(0x40)
        let taps = (0..<9).map { _ in input.sample() & 0x40 != 0 }
        assert(taps == [true, true, true, false, false, true, true, true, false])

        input.press(0x08); input.press(0x20)
        assert(input.sample() == 0x28)
        input.release(0x20) // UIKit touchCancel / touchDragExit
        assert(input.sample() == 0x28)
        assert(input.sample() == 0x28)
        assert(input.sample() == 0x08)
        input.release(0x08)
        assert(input.sample() == 0)

        input.press(0x01 | 0x40)
        assert(input.sample() == 0x41)
        input.reset() // background / pause
        assert(input.sample() == 0)
        print("PASS virtual input taps, hold, repeat, chord, cancel and reset")
    }
}
