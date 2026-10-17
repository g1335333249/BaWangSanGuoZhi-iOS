import Foundation
import GameController
import SwiftUI

final class GameSession: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var paused = false
    @Published var message = "导入用户持有的 ROM 后开始游戏"
    private let bridge = GameCoreBridge()
    private let audio = GameAudio()
    private let virtualInput = VirtualInputState()
    private var frameNumber = 0
    var videoWidth: Int { bridge.videoWidth }

    init() { bootstrapROM() }

    private func bootstrapROM() {
        // A previously imported and verified ROM wins across app upgrades.
        if FileManager.default.fileExists(atPath: SaveManager.romURL.path) {
            start()
            if running { return }
        }
        guard let bundled = Bundle.main.url(forResource: "bawang_sanguozhi", withExtension: "bin") else {
            if !FileManager.default.fileExists(atPath: SaveManager.romURL.path) {
                message = "导入用户持有的 ROM 后开始游戏"
            }
            return
        }
        do {
            try SaveManager.importROM(bundled, through: bridge)
            start()
        } catch {
            message = "内置 ROM 校验失败。请手动导入正确版本的 ROM。"
        }
    }

    func importROM(_ url: URL) {
        do { try SaveManager.importROM(url, through: bridge); start() }
        catch { message = error.localizedDescription }
    }

    private func start() {
        virtualInput.reset()
        if running { persistSRAM(); audio.stop(); bridge.stop(); running = false }
        guard bridge.start(withROMPath: SaveManager.romURL.path,
                           sramPath: SaveManager.sramURL.path) else {
            message = "原生核心无法启动这份 ROM。"; return
        }
        frameNumber = 0
        running = true
        paused = false
        audio.start()
        message = ""
    }

    func press(_ mask: UInt16) { virtualInput.press(mask) }
    func release(_ mask: UInt16) { virtualInput.release(mask) }

    func step() -> Data? {
        guard running, !paused else { return nil }
        let buttons = virtualInput.sample() | controllerButtons()
        guard let image = bridge.step(withButtons: buttons) else {
            persistSRAM()
            message = "游戏核心已停止。"
            audio.stop()
            bridge.stop()
            running = false
            virtualInput.reset()
            return nil
        }
        if let sound = bridge.copyAudio() { audio.append(sound) }
        frameNumber += 1
        if frameNumber % 300 == 0 { persistSRAM() }
        let rawMiss = bridge.rawDispatchMissCount != 0
        let interpreted = bridge.interpretedInstructionCount != 0
        if rawMiss || interpreted {
            persistSRAM()
            message = interpreted ? "游戏触及 68000 解释器路径，原生执行已停止。"
                                  : "遇到尚未静态重编译的 ROM 入口。"
            audio.stop()
            bridge.stop()
            running = false
            virtualInput.reset()
        }
        return image
    }

    func persistSRAM() {
        guard running else { return }
        if bridge.persistSRAM(atPath: SaveManager.sramURL.path) == 0 {
            message = "存档写入失败。"
        }
    }

    func setPaused(_ value: Bool) {
        if value { virtualInput.reset() }
        guard running, paused != value else { return }
        paused = value
        if value { persistSRAM(); audio.stop() }
        else { audio.start() }
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
