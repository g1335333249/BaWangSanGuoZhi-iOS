import Foundation
import GameController
import SwiftUI
import UIKit
import CoreGraphics

final class GameSession: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var paused = false
    @Published var message = ""
    @Published private(set) var snapshots: [ReplaySnapshotInfo] = []
    @Published private(set) var restoring = false
    @Published private(set) var restoreProgress: Double = 0

    private let bridge = GameCoreBridge()
    private let audio = GameAudio()
    private let virtualInput = VirtualInputState()
    private var frameNumber = 0
    private var history = Data()
    private var initialSRAM = Data(repeating: 0, count: 65536)
    private var lastFrame: Data?
    /* These are NOT files: native stack snapshots are valid only for the
       currently alive process/fiber. Reset when the core is recreated. */
    private var quickCache: [UUID: Data] = [:]
    private var quickOrder: [UUID] = [] // cap native stack copies to bound RAM
    private var pendingReplay: ReplaySnapshot?
    private var replayCursor = 0
    private var replayCancelled = false
    private var synthetic: [(mask: UInt16, remaining: Int)] = []

    var videoWidth: Int { bridge.videoWidth }

    init() {
        snapshots = ReplaySnapshotStore.list()
        if snapshots.isEmpty { startNewGame() }
        else { message = "选择已有进度，或开始新游戏" }
    }

    private func prepareROM() -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: SaveManager.romURL.path) { return true }
        guard let bundled = Bundle.main.url(forResource: "bawang_sanguozhi", withExtension: "bin") else {
            message = "当前 IPA 不包含内置 ROM。"; return false
        }
        do { try SaveManager.importROM(bundled, through: bridge); return true }
        catch { message = "内置 ROM 校验失败。"; return false }
    }

    func startNewGame() {
        guard !restoring, prepareROM() else { return }
        if running { persistSRAM() }
        audio.stop()
        bridge.stop()
        virtualInput.reset()
        quickCache.removeAll()
        quickOrder.removeAll()
        history.removeAll(keepingCapacity: false)
        synthetic.removeAll()
        let direct = try? Data(contentsOf: SaveManager.sramURL)
        let backup = try? Data(contentsOf: URL(fileURLWithPath: SaveManager.sramURL.path + ".bak"))
        initialSRAM = (direct?.count == 65536 ? direct : nil)
            ?? (backup?.count == 65536 ? backup : nil)
            ?? Data(repeating: 0, count: 65536)
        bridge.setSimplifiedLanguage(UserDefaults.standard.string(forKey: "BawangGameLanguage") == "simplified")
        guard bridge.start(withROMPath: SaveManager.romURL.path, sramPath: SaveManager.sramURL.path) else {
            message = "原生游戏核心无法启动。"; running = false; return
        }
        frameNumber = 0
        running = true
        paused = false
        message = ""
        audio.start()
    }

    func setSimplifiedLanguage(_ simplified: Bool) { bridge.setSimplifiedLanguage(simplified) }
    func press(_ mask: UInt16) { virtualInput.press(mask) }
    func release(_ mask: UInt16) { virtualInput.release(mask) }

    /* Touch input maps to genuine three-button pad events. A tap confirms,
       a swipe navigates. No guest RAM / menu state is overwritten. */
    func tapGame(x: Int, y: Int, width: Int) {
        guard running, !paused, !restoring, (0..<width).contains(x), (0..<224).contains(y) else { return }
        // Main 4-tab menu: identify the ROM's pink selected tab and blue
        // unselected tabs from the *actual 320x224 VDP framebuffer*. Only
        // issue directional presses when this scene is unambiguous.
        if y < 25, let active = selectedTopTab(width: width) {
            let target = min(3, max(0, x * 4 / width))
            if active != target {
                let direction: UInt16 = target > active ? 0x08 : 0x04
                for _ in 0..<abs(target - active) { enqueue(direction) }
            }
            enqueue(0x20) // activate selected tab
            return
        }
        enqueue(0x20) // other scenes: tap to confirm, no unsafe RAM edits
    }

    private func selectedTopTab(width: Int) -> Int? {
        guard let pixels = lastFrame, pixels.count == 320 * 224 * 4 else { return nil }
        var reds = [Int](repeating: 0, count: 4)
        var blues = [Int](repeating: 0, count: 4)
        for i in 0..<4 {
            for y in [6, 10, 15, 19] {
                for offset in [9, 12, 45, 62] {
                    let x = min(319, i * width / 4 + offset * width / 320)
                    let o = (y * 320 + x) * 4
                    let b = Int(pixels[o]), g = Int(pixels[o + 1]), r = Int(pixels[o + 2])
                    if r > 150 && r > g * 12 / 10 && r > b * 12 / 10 { reds[i] += 1 }
                    if b > 160 && b > r * 12 / 10 && b > g * 11 / 10 { blues[i] += 1 }
                }
            }
        }
        guard let chosen = reds.enumerated().max(by: { $0.element < $1.element }),
              chosen.element >= 5, reds.filter({ $0 >= 5 }).count == 1,
              blues.enumerated().allSatisfy({ $0.offset == chosen.offset || $0.element >= 3 })
        else { return nil }
        return chosen.offset
    }

    func swipeGame(dx: CGFloat, dy: CGFloat) {
        guard running, !paused, !restoring else { return }
        let mask: UInt16 = abs(dx) > abs(dy) ? (dx > 0 ? 0x08 : 0x04) : (dy > 0 ? 0x02 : 0x01)
        enqueue(mask)
    }
    private func enqueue(_ mask: UInt16) {
        /* A held edge must be visible across several emulated frames and
           separated by at least one released frame from the next edge. */
        synthetic.append((mask, 3))
        synthetic.append((0, 2))
    }
    private func sampledButtons() -> UInt16 {
        let regular = virtualInput.sample() | controllerButtons()
        guard !synthetic.isEmpty else { return regular }
        let mask = synthetic[0].mask
        synthetic[0].remaining -= 1
        if synthetic[0].remaining == 0 { synthetic.removeFirst() }
        return regular | mask
    }

    func step() -> Data? {
        guard running, !paused, !restoring else { return nil }
        let buttons = sampledButtons()
        guard let image = bridge.step(withButtons: buttons) else {
            failNative("游戏核心停止，现有快照和 SRAM 文件不会因本次失败被删除。")
            return nil
        }
        if bridge.rawDispatchMissCount != 0 || bridge.interpretedInstructionCount != 0 {
            failNative("遇到未重编译入口／解释器回退，已停止运行。")
            return nil
        }
        if history.count >= ReplaySnapshotStore.maxFrames * 2 {
            /* Continue playing: only durable replay recording has a bound. */
            message = "录制达到上限，暂不能再创建新快照。"
        } else {
            // Bit 15 records the chosen visual font mode without entering the
            // emulated 3-button controller mask. Needed for deterministic
            // replay if the player changes language mid-session.
            let languageBit: UInt16 = UserDefaults.standard.string(forKey: "BawangGameLanguage") == "simplified" ? 0x8000 : 0
            ReplaySnapshotStore.appendInput(buttons | languageBit, to: &history)
        }
        lastFrame = image
        frameNumber += 1
        if let sound = bridge.copyAudio() { audio.append(sound) }
        if frameNumber % 300 == 0 { persistSRAM() }
        return image
    }
    private func failNative(_ reason: String) {
        audio.stop(); bridge.stop(); virtualInput.reset()
        running = false; paused = false; message = reason
    }
    func persistSRAM() {
        guard running else { return }
        if bridge.persistSRAM(atPath: SaveManager.sramURL.path) == 0 { message = "SRAM 写入失败。" }
    }
    func setPaused(_ value: Bool) {
        if value { virtualInput.reset(); synthetic.removeAll() }
        guard running, paused != value else { return }
        paused = value
        if value { persistSRAM(); audio.stop() } else { audio.start() }
    }

    func saveSnapshot(named name: String) throws {
        guard running, paused, !restoring else { throw ReplaySnapshotError.unavailable }
        guard history.count <= ReplaySnapshotStore.maxFrames * 2,
              history.count == frameNumber * 2 else { throw ReplaySnapshotError.tooLong }
        let digest = bridge.stateFingerprint
        guard digest != 0, let native = bridge.checkpointData() else { throw ReplaySnapshotError.unavailable }
        let info = ReplaySnapshotInfo(id: UUID(), name: name.isEmpty ? "手动快照" : name,
            date: Date(), frames: frameNumber, appBuild: ReplaySnapshotStore.appBuild(),
            fingerprint: digest,
            simplified: UserDefaults.standard.string(forKey: "BawangGameLanguage") == "simplified")
        let payload = ReplaySnapshot(formatVersion: 1, info: info, initialSRAM: initialSRAM,
            inputsLE: history, checksum: ReplaySnapshotStore.checksum(initialSRAM, history))
        try ReplaySnapshotStore.write(payload, preview: makeThumbnail(lastFrame))
        quickCache[info.id] = native
        quickOrder.append(info.id)
        while quickOrder.count > 3 {
            let evicted = quickOrder.removeFirst()
            quickCache.removeValue(forKey: evicted)
        }
        snapshots = ReplaySnapshotStore.list()
        message = "已保存独立快照「\(info.name)」。"
    }
    func deleteSnapshot(_ id: UUID) {
        quickCache.removeValue(forKey: id)
        quickOrder.removeAll { $0 == id }
        ReplaySnapshotStore.delete(id)
        snapshots = ReplaySnapshotStore.list()
    }
    private func makeThumbnail(_ frame: Data?) -> Data? {
        guard let frame, frame.count == 320 * 224 * 4,
              let provider = CGDataProvider(data: frame as CFData),
              let cg = CGImage(width: 320, height: 224, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: 320 * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                        .union(.byteOrder32Little),
                    provider: provider, decode: nil, shouldInterpolate: false,
                    intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }

    func restoreSnapshot(_ id: UUID) {
        guard !restoring else { return }
        do {
            let snap = try ReplaySnapshotStore.read(id)
            guard prepareROM() else { return }
            if let native = quickCache[id], running, bridge.restoreCheckpoint(native),
               bridge.stateFingerprint == snap.info.fingerprint {
                finishRestore(snap, immediate: true)
                return
            }
            /* This restart path works even when the app process changed.
               Never apply a raw in-process fiber blob across a restart. */
            audio.stop()
            running = false; paused = false
            bridge.stop()
            quickCache.removeAll()
            quickOrder.removeAll()
            virtualInput.reset(); synthetic.removeAll()
            let temp = SaveManager.support.appendingPathComponent("replay-initial.srm")
            try snap.initialSRAM.write(to: temp, options: .atomic)
            let firstLanguage = snap.info.frames > 0
                ? (ReplaySnapshotStore.frameInput(snap.inputsLE, 0) & 0x8000) != 0
                : snap.info.simplified
            bridge.setSimplifiedLanguage(firstLanguage)
            guard bridge.start(withROMPath: SaveManager.romURL.path, sramPath: temp.path) else {
                throw ReplaySnapshotError.unavailable
            }
            pendingReplay = snap
            replayCursor = 0; replayCancelled = false
            restoreProgress = 0; restoring = true
            message = "正在重放并校验历史进度…"
            DispatchQueue.main.async { [weak self] in self?.replayBatch() }
        } catch { message = "载入失败：\(error.localizedDescription)" }
    }
    func cancelRestore() { replayCancelled = true }
    private func replayBatch() {
        guard restoring, let snap = pendingReplay else { return }
        if replayCancelled { failRestore("恢复已取消，原始 SRAM 没有被覆盖。"); return }
        let end = min(snap.info.frames, replayCursor + 200)
        while replayCursor < end {
            let recorded = ReplaySnapshotStore.frameInput(snap.inputsLE, replayCursor)
            bridge.setSimplifiedLanguage((recorded & 0x8000) != 0)
            guard bridge.step(withButtons: recorded & 0x00FF) != nil,
                  bridge.rawDispatchMissCount == 0,
                  bridge.interpretedInstructionCount == 0 else {
                failRestore("回放期间遇到原生执行错误，已拒绝恢复。")
                return
            }
            replayCursor += 1
        }
        restoreProgress = Double(replayCursor) / Double(max(1, snap.info.frames))
        if replayCursor < snap.info.frames {
            DispatchQueue.main.async { [weak self] in self?.replayBatch() }
            return
        }
        guard bridge.stateFingerprint == snap.info.fingerprint else {
            failRestore("回放校验不一致，不能安全恢复。原始 SRAM 未覆盖。")
            return
        }
        finishRestore(snap, immediate: false)
    }
    private func failRestore(_ reason: String) {
        restoring = false; pendingReplay = nil
        audio.stop(); bridge.stop()
        running = false; paused = false; message = reason
    }
    private func finishRestore(_ snap: ReplaySnapshot, immediate: Bool) {
        // Restored sessions must continue recording the same visual mode as
        // the saved state; updates remain in UserDefaults for AppSettings.
        UserDefaults.standard.set(snap.info.simplified ? "simplified" : "traditional", forKey: "BawangGameLanguage")
        bridge.setSimplifiedLanguage(snap.info.simplified)
        history = snap.inputsLE
        initialSRAM = snap.initialSRAM
        frameNumber = snap.info.frames
        virtualInput.reset(); synthetic.removeAll()
        /* Only after successful replay verification, protect the previous
           battery save then persist the restored cartridge SRAM. */
        let fm = FileManager.default
        if fm.fileExists(atPath: SaveManager.sramURL.path) {
            let backup = SaveManager.support.appendingPathComponent("bawang.before-restore.srm")
            try? fm.removeItem(at: backup)
            try? fm.copyItem(at: SaveManager.sramURL, to: backup)
        }
        guard bridge.forcePersistSRAM(atPath: SaveManager.sramURL.path) else {
            failRestore("回放通过，但写入 SRAM 失败。请勿删除原备份。")
            return
        }
        pendingReplay = nil
        restoring = false; restoreProgress = 1
        running = true; paused = false
        audio.start()
        message = immediate ? "已即时恢复快照" : "已完成跨重启重放，游戏状态校验通过。"
    }

    private func controllerButtons() -> UInt16 {
        guard let pad = GCController.controllers().first?.extendedGamepad else { return 0 }
        var bits: UInt16 = 0
        if pad.dpad.up.isPressed { bits |= 0x01 }
        if pad.dpad.down.isPressed { bits |= 0x02 }
        if pad.dpad.left.isPressed { bits |= 0x04 }
        if pad.dpad.right.isPressed { bits |= 0x08 }
        if pad.buttonB.isPressed { bits |= 0x10 }
        if pad.buttonA.isPressed { bits |= 0x40 }
        if pad.buttonX.isPressed { bits |= 0x20 }
        if pad.buttonMenu.isPressed { bits |= 0x80 }
        return bits
    }
}
