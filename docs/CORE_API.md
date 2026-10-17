# 共用游戏核心接口

`apps/core/bawang_core.h` 是 macOS/iOS 及将来 Android JNI 适配共同使用的 C ABI。所有 68000 静态重编译代码、MD 硬件状态、SMD 解交错、ROM SHA256 校验、SRAM 文件格式和原子写入、输入掩码、VDP 输出及 FM/PSG 混音都在 C/C++ 核心内。核心不调用 SwiftUI、Metal、CryptoKit 或其他 Apple 专有游戏逻辑接口。

宿主提供两个本地路径：用户持有的 ROM 文件及沙盒里的 SRAM 文件。`bawang_rom_import_file(source, destination)` 接受 1 MiB 标准 BIN 或 1 MiB+512 字节 SMD，校验固定 SHA256 后在 destination 原子写入标准 BIN。`bawang_core_start_file(rom_path, sram_path)` 加载已校验 ROM 和可选的 64 KiB SRAM；若主存档损坏，会读取 `.bak`。`bawang_core_frame(buttons, argb, stride)` 执行一帧，输出 320×224 ARGB；`bawang_core_audio` 复制本帧 48 kHz 双声道 PCM。`bawang_core_save_sram_if_changed(path)` 返回 0=错误、1=无变化、2=已写入。`bawang_core_stop` 结束运行；宿主须在停止前调用存档接口。

手柄位定义在 `bawang_core.h` 的 `BAWANG_PAD_*` 常量中，宿主把触摸或物理手柄状态合并为一份 `uint16_t`。当前核心为单实例，所有接口应在同一串行调用上下文使用。Swift/Objective-C++ 只管理文件选择和沙盒路径、MTKView/Metal 渲染、AVAudioEngine 播放以及屏幕和 GameController 按键。未来 Android 适配通过 JNI 调用同一 C ABI，以 Kotlin 管理文件 URI、屏幕、声音及生命周期；无需复制任何游戏规则或资源转换算法。Android 构建与运行目前**未验证**。

诊断 `bawang_core_native_instructions`、`bawang_core_interpreted_instructions` 和 `bawang_core_raw_dispatch_misses` 可区分原生指令、诊断解释器和静态分发缺口。iOS 宿主遇到后两项非零会停止执行。Z80 仍使用框架音频芯片解释路径，因此未满足整款游戏严格静态原生目标。
