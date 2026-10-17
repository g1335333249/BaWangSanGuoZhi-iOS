import Foundation

// UIControl sends touch events on the main thread; MTKView may sample elsewhere.
// Every down edge has three pressed frames, with a released frame between taps.
final class VirtualInputState {
    private enum Phase { case idle, pressed, release }
    private struct Key {
        var physical = false
        var queuedEdges = 0
        var pressedFrames = 0
        var phase: Phase = .idle
    }
    private let lock = NSLock()
    private var keys = Array(repeating: Key(), count: 8)

    func press(_ mask: UInt16) {
        lock.lock(); defer { lock.unlock() }
        for bit in 0..<8 where mask & (1 << bit) != 0 {
            if !keys[bit].physical {
                keys[bit].physical = true
                keys[bit].queuedEdges += 1
            }
        }
    }

    func release(_ mask: UInt16) {
        lock.lock(); defer { lock.unlock() }
        for bit in 0..<8 where mask & (1 << bit) != 0 { keys[bit].physical = false }
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        keys = Array(repeating: Key(), count: 8)
    }

    func sample() -> UInt16 {
        lock.lock(); defer { lock.unlock() }
        var result: UInt16 = 0
        for bit in 0..<8 {
            switch keys[bit].phase {
            case .idle:
                if keys[bit].queuedEdges > 0 {
                    keys[bit].queuedEdges -= 1
                    keys[bit].pressedFrames = 2
                    keys[bit].phase = .pressed
                    result |= 1 << bit
                }
            case .pressed:
                if keys[bit].pressedFrames > 0 {
                    keys[bit].pressedFrames -= 1
                    result |= 1 << bit
                } else if keys[bit].queuedEdges > 0 {
                    keys[bit].phase = .release
                } else if keys[bit].physical {
                    result |= 1 << bit
                } else {
                    keys[bit].phase = .idle
                }
            case .release:
                keys[bit].phase = .idle
            }
        }
        return result
    }
}
