import Foundation

@main
struct SnapshotCodecTest {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        SaveManager.support = root
        let inputs: [UInt16] = [0x01, 0x40, 0x00, 0x8008, 0x00]
        var tape = Data()
        inputs.forEach { ReplaySnapshotStore.appendInput($0, to: &tape) }
        for (index, input) in inputs.enumerated() {
            precondition(ReplaySnapshotStore.frameInput(tape, index) == input)
        }
        let base = Data(repeating: 0x5A, count: 65536)
        let meta = ReplaySnapshotInfo(id: UUID(), name: "Repro", date: Date(), frames: inputs.count,
            appBuild: ReplaySnapshotStore.appBuild(), fingerprint: 0x123456, simplified: true)
        let payload = ReplaySnapshot(formatVersion: 1, info: meta, initialSRAM: base,
            inputsLE: tape, checksum: ReplaySnapshotStore.checksum(base, tape))
        try ReplaySnapshotStore.write(payload, preview: nil)
        precondition(ReplaySnapshotStore.list().count == 1)
        let loaded = try ReplaySnapshotStore.read(meta.id)
        precondition(loaded.inputsLE == tape && loaded.initialSRAM == base)
        let damaged = ReplaySnapshot(formatVersion: 1, info: meta, initialSRAM: base,
            inputsLE: Data(repeating: 0, count: tape.count), checksum: payload.checksum)
        do {
            try ReplaySnapshotStore.write(damaged, preview: nil)
            fatalError("checksum failure not detected")
        } catch ReplaySnapshotError.malformed { /* expected */ }
        ReplaySnapshotStore.delete(meta.id)
        precondition(ReplaySnapshotStore.list().isEmpty)
        print("Replay snapshot codec PASS")
    }
}
