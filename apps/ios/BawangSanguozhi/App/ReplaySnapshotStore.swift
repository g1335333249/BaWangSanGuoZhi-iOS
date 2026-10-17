import Foundation
import UIKit

/* Durable save format v1: a verified, deterministic INPUT REPLAY, not a raw
 * address-bearing native coroutine snapshot. Preserves the exact boot SRAM
 * and one controller-mask word per completed game frame. Restoration boots a
 * fresh native core, replays inputs, and compares its guest-state fingerprint.
 * The same-process shortcut is an independent in-memory rb_state image. */
struct ReplaySnapshotInfo: Codable, Identifiable {
    let id: UUID
    var name: String
    let date: Date
    let frames: Int
    let appBuild: String
    let fingerprint: UInt64
    let simplified: Bool
}

struct ReplaySnapshot: Codable {
    let formatVersion: Int
    let info: ReplaySnapshotInfo
    let initialSRAM: Data
    let inputsLE: Data
    let checksum: UInt64
}

enum ReplaySnapshotError: LocalizedError {
    case malformed, incompatible, unavailable, tooLong
    var errorDescription: String? {
        switch self {
        case .malformed: return "快照文件不完整或校验失败，原有游戏存档未被覆盖。"
        case .incompatible: return "快照属于其他 App 核心版本，不能安全恢复。"
        case .unavailable: return "当前核心状态尚不能创建即时快照。"
        case .tooLong: return "本局输入记录超过安全上限，请先使用游戏内原版存档。"
        }
    }
}

enum ReplaySnapshotStore {
    static let maxFrames = 1_000_000
    static var directory: URL {
        let folder = SaveManager.support.appendingPathComponent("Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    static func appBuild() -> String {
        let b = Bundle.main.infoDictionary
        return "\(b?["CFBundleShortVersionString"] as? String ?? "unknown")/\(b?["CFBundleVersion"] as? String ?? "0")"
    }
    private static func url(_ id: UUID, _ ext: String) -> URL {
        directory.appendingPathComponent("\(id.uuidString).\(ext)")
    }
    /* FNV-1a detects accidental truncation/corruption, not hostile tampering. */
    static func checksum(_ initial: Data, _ inputs: Data) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for b in initial { hash = (hash ^ UInt64(b)) &* 0x100000001b3 }
        for b in inputs { hash = (hash ^ UInt64(b)) &* 0x100000001b3 }
        return hash
    }
    static func list() -> [ReplaySnapshotInfo] {
        let names = (try? FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: nil)) ?? []
        return names.filter { $0.pathExtension == "info" }.compactMap {
            guard let raw = try? Data(contentsOf: $0),
                  let info = try? JSONDecoder().decode(ReplaySnapshotInfo.self, from: raw),
                  FileManager.default.fileExists(atPath: url(info.id, "bws").path)
            else { return nil }
            return info
        }.sorted { $0.date > $1.date }
    }
    static func write(_ state: ReplaySnapshot, preview: Data?) throws {
        guard state.formatVersion == 1, state.initialSRAM.count == 65536,
              state.inputsLE.count == state.info.frames * 2,
              state.info.frames <= maxFrames,
              state.checksum == checksum(state.initialSRAM, state.inputsLE) else {
            throw ReplaySnapshotError.malformed
        }
        /* Atomic payload first, public catalog entry last. Existing saves are
         * immutable; each tap creates an independent UUID and file set. */
        try JSONEncoder().encode(state).write(to: url(state.info.id, "bws"), options: .atomic)
        if let preview { try preview.write(to: url(state.info.id, "png"), options: .atomic) }
        try JSONEncoder().encode(state.info).write(to: url(state.info.id, "info"), options: .atomic)
    }
    static func read(_ id: UUID) throws -> ReplaySnapshot {
        let state = try JSONDecoder().decode(ReplaySnapshot.self, from: Data(contentsOf: url(id, "bws")))
        // A newer build may still replay the same ROM identically. Do not
        // reject purely on CFBundleVersion; the guest fingerprint verifies
        // behavior before any existing SRAM is replaced.
        guard state.formatVersion == 1, state.info.id == id else {
            throw ReplaySnapshotError.incompatible
        }
        guard state.initialSRAM.count == 65536, state.info.frames >= 0,
              state.info.frames <= maxFrames,
              state.inputsLE.count == state.info.frames * 2,
              state.checksum == checksum(state.initialSRAM, state.inputsLE) else {
            throw ReplaySnapshotError.malformed
        }
        return state
    }
    static func thumbnail(_ id: UUID) -> UIImage? {
        UIImage(contentsOfFile: url(id, "png").path)
    }
    static func delete(_ id: UUID) {
        for ext in ["info", "bws", "png"] { try? FileManager.default.removeItem(at: url(id, ext)) }
    }
    static func frameInput(_ data: Data, _ frame: Int) -> UInt16 {
        let lo = UInt16(data[data.startIndex + frame * 2])
        let hi = UInt16(data[data.startIndex + frame * 2 + 1])
        return lo | hi << 8
    }
    static func appendInput(_ input: UInt16, to history: inout Data) {
        history.append(UInt8(truncatingIfNeeded: input))
        history.append(UInt8(truncatingIfNeeded: input >> 8))
    }
}
