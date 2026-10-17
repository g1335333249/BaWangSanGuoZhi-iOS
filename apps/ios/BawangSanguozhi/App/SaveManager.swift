import Foundation

/* iOS owns sandbox locations and the security-scoped grant. The common C core
 * owns ROM decoding, verification and SRAM file semantics. */
enum SaveManager {
    static let support: URL = {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = root.appendingPathComponent("BawangSanguozhi", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()
    static var romURL: URL { support.appendingPathComponent("user-rom.bin") }
    static var sramURL: URL { support.appendingPathComponent("bawang.srm") }

    static func importROM(_ url: URL, through bridge: GameCoreBridge) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard bridge.importROM(atPath: url.path, toPath: romURL.path) else {
            throw SaveError.invalidROM
        }
    }
}

enum SaveError: LocalizedError {
    case invalidROM
    var errorDescription: String? {
        "请选择与本移植版本匹配的《霸王三国志》原版 ROM。"
    }
}
