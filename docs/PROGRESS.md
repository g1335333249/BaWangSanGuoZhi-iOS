# 开发进度

版本：0.3.5（2026-10-17，修复 iOS 横屏虚拟手柄；App 0.1.2 Build 10）

## 2026-10-17 横屏虚拟手柄紧急修复

- 用户在 iPhone 真机发现：虚拟键显示于横屏顶部，单点不响应、滑动才触发。根因分别是 `VirtualPad` 的 `HStack(alignment: .bottom)` 未占满 `GeometryReader` 的可用高度，以及按下输入仅依赖 `DragGesture(minimumDistance: 0).onChanged`；快速触摸即使产生按下/抬起，也可能在两次 `GameSession.step()` 间被漏采样。
- `VirtualPad.swift` 改用 UIKit `UIControl` 明确处理 touchDown、touchUpInside/Outside、touchCancel、touchDragEnter/Exit，保持按下橙色反馈；横屏布局明确占满高度并底部对齐，保留左右安全边距。`GameMetalView` 禁止接收触摸，顶部 ROM 导入按钮保持可用。`VirtualInputState.swift` 用锁保护虚拟按键事件，每次按下边沿至少输出 3 个按下帧、连续点击间至少 1 个释放帧；同时保留独立按键和现有 GameController 位掩码组合。暂停、后台或重启时清空虚拟按键状态。
- `swiftc apps/ios/BawangSanguozhi/Controls/VirtualInputState.swift tests/virtual_input_state_test.swift -o /tmp/bawang-virtual-input-test && /tmp/bawang-virtual-input-test` **通过**：A/START 快速触摸、方向键长按与释放、连续两次 A、右+C 同按、取消和暂停重置。触摸事件本身尚未通过自动注入测试，不能以此宣称真机手感已验证。
- XcodeGen 重新生成项目，iOS Simulator Debug 与 iphoneos ARM64 Release 无签名 `xcodebuild` 均 **BUILD SUCCEEDED**，复用现有核心静态库、未重新生成 ROM 代码。打包器核对本地 IPA 为 `BawangSanguozhi-0.1.2-build10-unsigned.ipa`，2,346,151 字节，App 内 BIN SHA256 仍为 `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`。隔离 iPhone 17 Pro 模拟器安装并启动内置 ROM 后，截图确认为真实《霸王三国志》开场 VDP 画面、方向键左下、A/B/C 右下、START 在其上，顶部无虚拟键；截图仅在本机 `/tmp/bawang-build10-landscape-correct.png`，未提交。隔离模拟器已删除。
- App 版本同步升为 **0.1.2 Build 10**，设备 IPA 文件名及手动 Actions Artifact 名称同步更新；`tests/test_ios_workflow_policy.py` 通过，工作流仍只有 `workflow_dispatch`。本轮未运行 M2/M3 长游戏回归。下一步：用户下载新手动构建包并在真机复验单点、连续点击和同时按键，尤其确认 iOS 触摸取消事件与实际菜单行为。

## 2026-10-17 手动 Actions 首次运行修复

- 用户手动触发的 [运行 #1](https://github.com/g1335333249/BaWangSanGuoZhi-iOS/actions/runs/39014467082) 使用提交 `3b0ad4b`；checkout、Xcode 26.6 检查和仓库 SMD SHA256 校验均成功，随后在 `scripts/bootstrap_upstream.sh` 应用 `m68k-m2-codegen.patch` 时失败，后续生成与 IPA 步骤未执行，故该运行没有 Artifact。
- 根因：`m68k-m2-codegen.patch` 曾以未打 RTR 补丁的原始生成器为基准制作，同时包含 `m68k-rtr-return.patch` 的同一 RTR hunk。本机已有两个补丁，重复应用检查遮蔽了干净检出的冲突。现以先打 RTR 补丁的文件为基准重新生成 M2 补丁，未改变最终生成器字节或游戏逻辑。
- `tests/test_upstream_patch_order.py` 在原始子模块文件上按脚本顺序应用 RTR、M2 补丁并比对最终字节；本机通过。另用全新 `git clone --recursive` 的固定上游提交依次验证全部六个补丁均成功应用；`sh scripts/apply_upstream_patches.sh` 的已有检出重复应用检查通过，工作流策略测试通过。修复提交推送后需重新手动触发工作流，验证代码生成、设备构建及 Artifact 上传；尚不能把首次失败运行报告为 IPA 构建成功。

## 2026-10-17 仓库 ROM 与一键构建

- 用户本轮明确授权将指定原始 SMD 随代码推送。`input/霸王三国志.smd` 实际大小 **1,049,088 字节**，SHA256 `8128fb9828b5474b37f928aed6a771cb2e03457aeb13293d29f3cfb1c83ba6b4`；本地转换 BIN 1,048,576 字节，SHA256 `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`。`.gitignore` 只放行这个 SMD，仍忽略其他输入、BIN、SRAM、IPA 与生成代码。ROM 必须以实际二进制文件提交，不使用 LFS 指针。
- `.github/workflows/build-unsigned-ipa.yml` 保持唯一 `workflow_dispatch` 入口，删除私有仓库检查、Release Asset 下载和令牌/输入参数。`actions/checkout` 后直接验证 SMD 内容与大小；随后沿用固定上游补丁、GenesisRecomp、32 C 分片、iphoneos ARM64 核心、XcodeGen 和未签名 IPA 的既有构建流程。Artifact 名称改为 `BawangSanguozhi-iOS-0.1.1-Build9`，保留 7 天；版本与 Bundle ID 不变。
- 本轮按 CI 顺序在本机再次执行：`scripts/bootstrap_upstream.sh` 的全部补丁已应用、固定重编译器构建通过、`scripts/generate.sh` 生成 **32** 个 C 分片、iphoneos ARM64 Release `libBawangCore.a` 构建通过、XcodeGen 资源阶段和 `xcodebuild` 真机 Release 构建通过。`package_unsigned_ipa.py` 生成的本地未签名 IPA **2,343,443 字节**，内置 BIN SHA256 再次核对为 `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`。`tests/test_ios_workflow_policy.py` 验证唯一手动触发及仓库 ROM 路径。此前完整游戏、Co-Simulation、内政与存档回归不重复运行。远程手动运行的实际日志和 Artifact URL 在推送后补录。

## 2026-10-17 Build 9 内置 ROM 与手动私有 IPA 构建

- `GameSession` 首次启动先尝试沙盒内已校验 ROM；缺失或损坏时尝试 Bundle `bawang_sanguozhi.bin`，通过原有 `SaveManager.importROM` 与共用 C 核心 SHA256 校验后导入可写沙盒并启动。无资源显示原导入界面，错误资源显示明确提示；原文件选择、SRAM Application Support 路径、VDP/Metal、音频及手柄代码保留。App/XcodeGen 版本均为 **0.1.1 Build 9**。
- `scripts/prepare_ios_bundle_rom.py` 只接受 1 MiB 且 SHA256 匹配的标准 BIN，复制到 Git 忽略的 `apps/ios/BawangSanguozhi/Resources/`。XcodeGen 在资源存在时自动列入 `Copy Bundle Resources`；移除资源重新生成工程时不引用 ROM。`scripts/package_unsigned_ipa.py` 检查真实 Payload、iOS ARM64 Mach-O、原生核心符号、Bundle ID/版本、ROM SHA256、无签名与无敏感附加文件。
- 本机从用户 ROM 重生 **32 个 C 分片**，重编 `libBawangCore.a` 和 iphoneos arm64 Release App，打包 `apps/ios/build-device/ipa/BawangSanguozhi-0.1.1-build9-unsigned.ipa`（仅本地、Git 忽略）。IPA **2,343,443 字节**，最终 SHA256 `1589aeebb31734a58094d6a6ced4569c2c8c7174a32631d68330a35ea98ffca6`（构建代码提交 `c4f50ed`）；解包复核资源哈希 `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`，可执行文件的 `LC_BUILD_VERSION platform IOS` 与 `arm64`、`_bawang_core_frame/_bawang_core_start_file` 均核实。未签名 IPA 仍需有效签名才能装普通 iPhone。
- 隔离 iPhone 17 Pro 模拟器的首次正确 Bundle ROM 启动后，Application Support 自动生成 SHA256 正确的 `user-rom.bin`，进程正常启动；该次截图因本机磁盘占满未能保存，故不声称新增截图验收。另一隔离模拟器中，**无 Bundle ROM** 的 Build 9 干净构建显示“导入 ROM”界面；故意篡改资源后显示“内置 ROM 校验失败”且不崩溃。磁盘不足阻断了该隔离模拟器随后的覆盖安装测试，临时设备均已删除；原有模拟器数据未动。
- `.github/workflows/build-unsigned-ipa.yml` 只由 `workflow_dispatch` 触发，使用 `macos-26` ARM64/Xcode 26.6，先检查仓库 Private，再从同仓库私有 Release Asset 下载 ROM，应用固定上游补丁、重生代码、构建与打包，7 天仅私有上传 IPA。当前公开仓库**未运行**该工作流；须先配置私有代码镜像与 `private-rom` Release Asset。`tests/test_ios_rom_staging.py` 与 `tests/test_ios_workflow_policy.py` 通过；上游 CTest **15/15**、M2 Co-Simulation **10/10**、核心 600 帧和 64 KiB SRAM 测试通过。
- 待验收：同版本覆盖升级及原存档在 Simulator 的完整路径、虚拟键实际点击、真机签名安装、私有 GitHub Actions 运行、整局游戏兼容。未推送 ROM、生成代码、IPA 或截图。

## 2026-10-17 跨平台 C 核心边界与 Build 8

- 根据新架构要求，将 SMD 解交错、BIN SHA256 验证、ROM 文件导入及 64 KiB SRAM 原子写入/备份恢复全部移至 `apps/core/bawang_storage.c`。复用上游纯 C 的 `genesis_identity_sha256`，核心不再包含 CommonCrypto；Swift 不再使用 CryptoKit 或实现游戏资源转换/存档格式。`apps/core/bawang_core.h` 统一导出 ROM、帧、画面、音频、按键、SRAM 和原生/解释执行统计接口，详见 `docs/CORE_API.md`。Objective-C++ 只传递 iOS 沙盒路径和音视频缓冲；未来 Android 可由 JNI 调用相同接口，Android 构建尚未验证。
- `BawangStorageTest` 通过：原始 SMD 与标准 BIN 在 C 转换后逐字节相同，固定 SHA256 校验通过，损坏 ROM 被拒绝，SRAM 原子写入与主文件损坏后的 `.bak` 恢复通过。`tests/test_m4_core_smoke.py` 600 帧原生 VDP/音频再次通过：原生 68000 解释执行 0、原始分发缺口 0，故意强制解释器时计数 8,076,920。macOS、arm64 Simulator 和 arm64 iphoneos 核心均重新编译成功。
- App 版本升至 **0.1.0 Build 8**。arm64 Simulator 与 iphoneos 无签名 `xcodebuild` 均成功；在 iPhone 17 Pro 模拟器安装、启动后，实拍帧缓冲显示原版人物插画与虚拟按键。该截图只保存在 `apps/core/build-macos/ios_sim_build8_10s.png`（Git 忽略）。模拟器触控流程、真机及 Android 尚未验收。
- M3 合并流程最终通过：原版「開發」扣黄金 100、194 年一月推进到二月、二月原版存档写出 64 KiB；重启并通过原版「載入遊戲」读取，仍为二月且黄金 900。`tests/test_m3_full_save.py` 两项通过；`tests/test_m3_develop_month.py` 两项通过，9,600 个原生/解释器 CPU/时序/VDP 检查点零分歧。`tests/test_m2_cosim.py` **10/10** 通过，上游 **15/15** 通过。该路径无原始分发缺口，解释器回退 0。
- 尚未解决：真机当前 Offline，模拟器虚拟按钮的真实点击未完成；音频实际听感与更长战役未验收；Z80 仍通过芯片解释路径执行，整款游戏不能称严格静态原生。ROM、生成分片、截图和 SRAM 均不提交。

## 2026-10-17 M3 内政、回合、SRAM 与 M4 首个 iOS App

- **重复「情報」的根因**：ROM 标准 BIN SHA256 仍为 `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`。游戏在 `$200000–$20FFFF` 使用卡带 SRAM，并在 `$20A001` 等地址写入菜单/游戏数据，但此前运行时仅支持 16 KiB，且要求 `$A130F1` 使能；本 ROM 始终不写该使能位，导致读回旧值并把顶栏类别反复画成「情報」。ROM header 末地址 `$000FFFFF`，SRAM 起始 `$200001`，两者不重叠。补丁 `scripts/patches/m3-sram-geometry.patch` 扩为 64 KiB，在 SRAM 位于 ROM 范围外时始终可见，并更新回滚布局断言；可选 `GENESIS_M3_SRAM_TRACE` 跟踪该范围的写入。修复后实际 VDP 顶栏显示「情報／軍事／人事／商人／內政／外交」。未直接改生成 C。
- ROM 动态入口 `$0211DA/$0208AC/$01FC7C` 逐项对照相邻 RTS 和入口指令后加入 `games/bawang_sanguozhi/game.toml`，重生 32 个 C 分片。`$01FC7C` 在选择「內政→開發」后真实命中；补入后 25,100 帧原生路径 **0 raw miss**。
- `tests/bawang_m3_develop.input` 由袁术 194 年首回合实际菜单选「內政→開發」、选择袁术、选择「終了」、输入 100 黄金。VDP 显示黄金 **1000→900**；工作 RAM 大端字段 `$FF2942` 同为 **1000→900**。`python3 tests/test_m3_develop.py` 已通过；原生/解释器在该操作期间 **4,000 个 CPU／时序／VDP 检查点零分歧**。`tests/bawang_m3_develop_month.input` 继续确认两座城的月末提示，真实进入 **194 年 2 月**，`$FF100C=1`、黄金仍 900，31,000 帧为 0 raw miss。`python3 tests/test_m3_develop_month.py` 已通过；合并路径 **9,600 个 CPU／时序／VDP 检查点零分歧**。
- `python3 tests/test_m3_month.py` 再次通过：独立首回合至下月脚本 28,500 帧 0 raw miss，原生/解释器 11,000 个 CPU／时序／VDP 检查点零分歧。项目既有 `python3 tests/test_m2_cosim.py` **10/10**，上游 CTest **15/15**。这里的 `hybrid_jmp/call_interpret` 次数是原生间接分发；`GENESIS_FLOOR=0` 时真实解释器回退为 0。
- 原版 Start→「3.存檔」→确认后，非 benchmark 桌面运行器落盘 **65,536 字节** SRAM 文件，**4,522 字节非零**；重新启动时日志显示载入 **65536/65536**。标题剧本列表第 7 项「載入遊戲」可进入保存状态，原版画面返回 194 年 1 月袁术城，RAM `$FF100C=0`、`$FF2942=1000`。独立总线/磁盘 `python3 tests/test_m3_sram_runtime.py` 通过，慢速端到端 `python3 tests/test_m3_original_save.py` **保存与重启读取两项均通过**。进一步的「開發→2 月→存档→重启读取」完整链路 `tests/test_m3_full_save.py` **两项通过**：二月存档重载后黄金仍为 900。此处的保存是原版游戏逻辑，未声称实现完整 CPU/VDP 即时快照。
- `apps/core/` 抽出 macOS/iOS 共用核心，实际链接 32 个生成 C 分片和现有 MD 硬件运行时。600 帧无窗口烟测从真实 ROM 产生原版标题 VDP 帧，`6,644,873` 条原生 68000 指令、**0 raw dispatch miss、0 解释执行指令**。FM/PSG 混音输出在该段有 **960,958 个非零 PCM 样本**。`scripts/patches/m3-native-coverage.patch` 增加单调解释执行计数，iOS 端一旦非零便停止并报错，防止悄悄回退。`python3 tests/test_m4_core_smoke.py` 两模式画面/音频哈希一致，故意强制解释器时计数 **8,076,920**，证明零计数断言确有检测能力。
- `apps/ios/BawangSanguozhi.xcodeproj` 为真正的 SwiftUI/Objective-C++/Metal App（版本 **0.1.0 Build 7**）：本地用户 ROM 导入、SMD 无损转换为标准 BIN 及 SHA256 验证、真实 VDP 帧整数缩放、虚拟方向键及 A/B/C/Start、GameController、SRAM 原子保存与备份、后台暂停、AVAudioEngine 接收核心真实 FM/PSG PCM。`xcodebuild` 的 **arm64 iOS Simulator 与 iphoneos 无签名构建均成功**；在 iPhone 17 Pro 模拟器安装并使用本地已校验 ROM 启动，自动截图显示实际开场画面及中文文字。ROM、生成资源和截图不在 Git 提交中。
- Xcode 工程未固定禁用签名；本地构建命令以 `CODE_SIGNING_ALLOWED=NO` 显式指定无签名模式。真机上线需要开发者选择合法 Team 与匹配的 provisioning profile，再完成真实设备验收。
- Build 7 收紧 `apps/core/bawang_core.c` 的扫描线输出边界为 224 行，与 Objective-C++ 桥接分配的 320×224 缓冲完全一致，避免未来 240 行 VDP 模式越界；macOS/iphoneos/Simulator 核心和 App 随后重新编译。
- Build 7 曾通过 Swift 版 SMD 转换测试；Build 8 已删除该平台专属实现，改由上述 C 核心测试覆盖相同转换与校验。
- 已知限制：尚未完成模拟器触控输入全流程验收（Computer Use 的系统辅助权限仍未授予）。本机有 Apple Development 证书，但 `xcrun xctrace list devices` 把用户 iPhone 列为 **Offline**；未验证匹配的 provisioning profile，故未宣称 iPhone 真机运行或 IPA。音频非零样本与 AVAudioEngine 链接已验证，实际听感未验收。Z80 仍通过框架芯片解释路径运行，整款游戏不能称为完全静态原生；长期 AI、战争、外交、完整统一战役也未验证。M4 目前为可启动的可玩测试版基础，不是完成版。
- 授权边界：上游 `third_party/segagenesisrecomp/LICENSE.md` 与 `LICENSE-recompiler` 均为 PolyForm Noncommercial 1.0.0；游戏内容仍属原权利人。仓库仅保留代码/补丁和哈希，ROM 与截图留在被忽略的本地目录，未推送或公开发布 App。
- 构建/回归命令：`sh scripts/generate.sh`；`cmake --build apps/macos/build -j8`、`cmake --build apps/macos/build-cosim -j8`、`cmake --build games/bawang_sanguozhi/build/{native,ios} -j8`、`cmake --build apps/core/build-{macos,ios-device,ios-simulator} -j8`；`xcodegen generate --spec apps/ios/project.yml`；`xcodebuild -project apps/ios/BawangSanguozhi.xcodeproj -scheme BawangSanguozhi -sdk iphonesimulator/iphoneos ... CODE_SIGNING_ALLOWED=NO build`。上游补丁重复应用检查 `sh scripts/apply_upstream_patches.sh` 全为 already applied。下一步：完成合并路径 9,600 点比较与慢速原版存档自动测试，继续验证触控、背景音效和真机签名部署。

## 2026-10-17 M2 中断调度与首回合命令

- 保留原工程、ROM 与 32 分片流程。标准 BIN SHA256 复核为 `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`。上游主仓库 `f875aa8`，68000 重编译器子模块 `921f67b`；上游代码修改仍由 `scripts/patches/` 中补丁复现，`sh scripts/apply_upstream_patches.sh` 重复运行均报告 already applied。ROM、生成 C、截图和运行日志仅留本地。
- `$000938` 是 `MOVE.B $2B(A5),D0; BNE $000938` 游戏标志等待循环。它不符合上游 `WaitForVBlank` 特殊函数模式，两条 CPU 路径均逐条执行；`games/bawang_sanguozhi/cosim.json` 的 `waitvbl=0` 保持不变。
- 新增默认关闭、按帧限定的 `[M2IRQ]` TSV 事件追踪（`GENESIS_M2_IRQ_TRACE_START_FRAME/END_FRAME`），记录扫描线、`master_cycle`、诊断周期、音频周期、CPU 预算、V-int asserted/accepted/entry/exit、等待进入/恢复、SR、A7、当前或最近指令 PC 与关键 RAM 标志。修复前第 13,262 帧 V-int 两路径均在扫描线 224、`master_cycle=3294113968` 接收，A7=`$FFEF7A`、SR=`$2000`；第 13,263 帧扫描线 232，原生在仍有 132 周期预算时额外 `GLUE_YIELD_IRQPOLL`，解释器继续执行至预算耗尽。这才是首个可证明的硬件调度分歧，不是第 13,262 帧逐指令列表表面上的 V-int 顺序差异。
- 首个分歧对应 ROM `$004E94 MOVE.B (A0)+` / `$004E96 BNE` 数据扫描。生成器 `profiles/genesis/code_generator.c` 的全局 `g_yield_in_next_bne` 从较早的 `TST` 泄漏到无关分支，误把数据扫描当成中断等待并插入 fiber yield。现在只在**相邻、固定内存地址的 `TST` 与回跳 BNE** 处插入该 hook；重生 32 分片，Bawang 生成代码中此类误插入数为 0。没有手改生成 C。
- 排除上述分歧后，下一处真实差异在 `$039A7A MOVE.L (SP)+,D2` / `$039A7C RTS`：原生包装把数据参数出栈误认为跨层跳过返回地址，去往 `$003B12`；解释器正确返回 `$039D7E`。生成器 JSR 包装现在以已弹出的架构 PC 是否等于该调用预期返回地址判别 `g_rte_pending`，同地址则继续、不同地址才传播提前返回。原有 RTR/RTE、CLR.L 与 JSR/BSR 修复保留。修复后从周期 `1858657800` 起 500 个逐指令 CPU/时序/VDP 检查点零分歧。
- 对第 14,330 帧至第 23,130 帧的完整单人脚本，原生/解释器逐帧 CPU、时序、VDP Co-Simulation **8,800 个连续检查点零分歧**，覆盖首回合与「情報→他國」指令。修复后第 13,262–13,264 帧 V-int 的 asserted/accepted/handler/等待恢复 **19 个事件**在两后端的硬件时间、诊断时间、预算、SR、A7、RAM 标志完全一致，均在扫描线 224 接收。修复前观察到的 1,976 诊断周期差值不能单独当作 CPU 错误，也不是应硬编码补偿的固定差值；当前同段已消失。
- 曾实验性加入“仅在指令边界耗尽预算”开关；关掉后相同的 6,500 个连续检查点仍零分歧，20,800 帧原生状态哈希亦相同。已撤销该开关和相关代码，避免把未证实的调度修改带入工程。Co-Simulation 工具的子进程关闭逻辑增加 terminate/wait/kill 兜底，避免诊断运行遗留占用 CPU 的进程。
- ROM 动态入口实际执行轨迹新增 `$021B50/$040604/$0215F4/$011078/$010F6E/$015FCC/$01041C/$023792/$0233E6/$02355E/$00198E/$02365C/$0239FC/$023814/$0238E8`，逐项核对 ROM 字节与相邻 RTS/分支后加入 `game.toml`。原生 `GENESIS_FLOOR=0` 跑满 20,800 帧为 **0 raw miss events / 0 解释器回退**；日志的 471 次 `hybrid_jmp/call_interpret` 是原生间接分发。进一步 23,100 帧命令脚本为 0 原始缺口、0 回退，488 次原生间接分发。
- `tests/bawang_one_player_command_probe.input` 使用原版输入走 194 年剧本、玩家数 `01`、袁术、难度/战斗选项、历史事件、回合提示、命令分类、选择国家与「他國」资料画面；每个命令转换留 600 帧稳定时间。画面来自实际 VDP 帧缓冲，截图和哈希保存在本地 `apps/macos/build/`，未提交。原生/原生重复运行与原生/解释器最终命令画面一致。已验证一条情报类回合命令；**消耗行动的内政操作和完整回合推进尚未验证**，属于 M3 后续任务。
- 构建命令：`cmake --build third_party/segagenesisrecomp/build/recompiler -j4`、`sh scripts/generate.sh`、`cmake --build apps/macos/build-cosim -j4`、`cmake --build apps/macos/build -j4`、`cmake --build games/bawang_sanguozhi/build/native -j4`、`cmake --build games/bawang_sanguozhi/build/ios -j4`，全部成功。上游 `ctest --test-dir third_party/segagenesisrecomp/build/tests --output-on-failure` 为 15/15；项目 `tests/test_m2_cosim.py` 为 10/10，`tests/test_m2_irq_timeline.py`、`tests/test_m2_turn_command.py` 及 `tests/test_m2_menu.py` 均通过。菜单测试只对**明确列出的 10 个动画帧**单独记录相位差，继续严格比较其余 150 个采样哈希与 11 张稳定菜单/游戏截图，并由 8,800 点 Co-Simulation 验证 CPU/VDP 语义。仍无 iOS App/真机结果。

## 2026-10-16 单人新游戏启动与新分歧

- 原版玩家数输入是两位数，初始 `00`；先前直接按 Up 得到 `10`，因此袁术确认后继续询问玩家 2。新的 `tests/bawang_one_player_probe.input` 先按 Right 移到个位、再按 Up 得到 `01`。原生真实 ROM 流程依次显示剧本选择、玩家 1 袁术确认、总确认、难度 `1`、战斗画面选项、再次总确认，以及 194 年 5 月游戏地图。
- 新游戏设置与事件入口缺口按轨迹依次发现 `$00D4E4/$00D570`、`$000580/$03C0D0/$0019A0/$0019CA/$016064/$0160F0/$02434E`、`$023EF0/$023D60/$023F5E`、`$010070/$023C52/$0100AC`、`$023B42/$023AB8`。每个入口均核对 ROM 中相邻字节，为 `RTS` 后的指令入口或 `$00199E/$0019C8` 分支跨过的有效序列；仅加入 `game.toml`，未手改生成 C。每次更新重生成 32 个分片，macOS 普通/Co-Simulation 运行器及 macOS/iOS ARM64 静态库均重建成功。最终 `GENESIS_FLOOR=0` 跑满 16,000 帧，`0 raw miss events`。日志 `[INTERP] hybrid_jmp/call_interpret: 707 total calls` 在此配置下计数的是**原生间接分发调用**，不是解释器回退；实际解释器回退为 0。
- 稳定设置画面的原生与诊断解释器 PNG 逐字节一致。`tests/test_m2_menu.py` 对完整 16,000 帧执行原生/原生确定性检查及原生/解释器比较，前者通过，后者**失败**：固定帧哈希首次在第 2700 帧不同，11 张早期/设置截图相同，但第 2700 帧动画截图和第 15,661 帧游戏截图不同。上游已注明固定帧哈希对时序漂移敏感；第 2600 帧起 200 个 Co-Simulation CPU/时序/VDP 检查点零差异，故不能将第 2700 帧采样差异直接归因于 CPU 语义。第 15,661 帧则是实质差异：原生仍显示历史事件文字，解释器已经显示袁术回合命令菜单。两张本地截图为 `apps/macos/build/bawang_one_player_event_{native,interp}.png`；未提交 ROM 或截图。
- 使用同一输入的逐帧 Co-Simulation 从第 8500 帧起，CPU/VDP 前 **4,763** 个检查点一致；第 **4,764** 个检查点首先发生 CPU 差异，VDP 此时仍一致。该点报告原生 PC=`$004E3A`、D0=`0`、D1=`4`、D2=`$0202`、A0=`$FFED8A`，解释器 PC=`$0045B4`、D0=`$F0`、D1=`5`、D2=`$0220`、A0=`$FFED8C`。帧级采样无法把该差异直接归到一条 68000 指令；从周期 3294242000 启动的逐指令比较已经处于不同调用链，尚需在此前更窄的逻辑位置做入口/退出跟踪。**不要把新游戏画面出现误报为 M2 通过。**
- 本轮回归：上游 CTest **15/15**；项目 Co-Simulation **8/8**（含两种同模式确定性、寄存器差异注入、返回/入口修复和菜单输入）。完整新游戏画面比较 **失败 1 项**，为上述未解决 CPU 分歧。`scripts/patches/m2-cosim-input-script.patch` 已包含 `--runner-benchmark`，补丁应用脚本重复运行检查通过。后续最具体任务：在第 4,763–4,764 个逐帧检查点之间记录进入/离开函数的寄存器、栈、`g_rte_pending` 与调用返回状态，找到首个逐指令差异；修复生成器或调度器后重生 32 分片并重跑 16,000 帧。
- 后续延长路径 `tests/bawang_one_player_long_probe.input` 运行 20,000 帧，首次在第 18,185 帧遇到 `$024042`；ROM `$024040 RTS` 后是有效 `MOVEM` 函数入口。加入配置并重生成/重编译后，该长路径 `0 raw miss events`、原生间接分发 2,159 次、解释器回退 0。第 19,661 帧原生仍为空地图，而解释器显示袁术命令菜单；两个结果分别保留在本地 `apps/macos/build/bawang_one_player_late_turn{,_interp}.png`。因此该阻断**不是**简单缺少此入口或短时画面延迟。
- Co-Simulation 差异报告现直接输出双方 `rte_pending`、`early_return`、`split_sp_popped`、最后生成指令 PC 及 SP 前后 64 字节。以第 13,255 帧为入口，第 9 个逐帧检查点复现同一首个 CPU 差异；两边 A7 均为 `$FFED40`，三个控制标记均为 0，但栈内有少量不同字节，原生最后生成指令为 `$0045E4 ADDQ.L #1,-8(A6)`，解释器被采样在 `$0045B4` 附近。**这是帧级采样位置，不足以证明 `$0045E4` 是致错指令。**接下来应在这段循环的同一逻辑入口/出口比较周期、寄存器与栈，排查动态分支周期和帧调度，再作语义修复。
- 同一区间的 6,000 检查点 holistic profile 确认差异持续存在：CPU 首次在第 8 个检查点分歧，之后 5,417/6,000 个 CPU 检查点不同；VDP 从第 584 个检查点开始分歧，后续 4,967/6,000 个不同。两路径短暂重新相同的帧不能视为问题已消失。概要在本地 `apps/macos/build/bawang_firstturn_profile.log`，对应测试工具的 `--profile` 模式；根因仍待逐指令对齐。
- 新增仅 Co-Simulation 构建、由 `GENESIS_COSIM_TRACE_FRAME` 控制的限定帧逐指令记录；原生 C 和解释器都在执行指令**之前**记录 PC/关键寄存器/诊断周期。第 13,262 帧两路径的前 10,088 条逐指令记录除诊断周期外完全一致。第 10,089 条首次 PC 顺序不同：原生进入 `$001130` V-int（A7 从 `$FFEF7A` 到 `$FFEFFA`，建立异常帧），解释器仍在 `$000938` 等待循环。记录起点及前 10,088 条的原生诊断周期始终比解释器少 **1,976**，两边每条指令的周期增量一致。该差值可来自更早的等待循环，不能直接宣称其本身是错误；但首次执行顺序差异可明确定位为**中断投递位置**，而非 `$0045E4` 的 ALU 语义。下一步比较两路径在同一逻辑帧的 68K 可执行预算、V-int 触发时刻与 WaitForVBlank 返回状态，修正调度器的真实根因。
- 可复核的逐指令日志保存在本地 `apps/macos/build/bawang_trace13262_{native,interp}.log`，`python3 scripts/compare_m2_trace.py <native.log> <interp.log>` 返回第 10,089 条的首个状态差异，并报告此前唯一周期差值 `-1976`。跟踪默认关闭，只在诊断 Co-Simulation 构建设置 `GENESIS_COSIM_TRACE_FRAME=13262` 时启用；普通 macOS 与 iOS ARM64 构建已复测成功。修改诊断工具后的上游 CTest 15/15、项目 Co-Simulation 8/8 保持通过。

## 2026-10-16 本轮 M2 返回传播修复

- 上轮第 1151 帧的 `$00069C` 是 ROM `$000698 RTS` 后的有效动态入口。已加入 `game.toml` 并重新生成；原先到第 1800 帧的 132 次原始分发缺口变为 0，但随后在第 1282 帧左右出现主入口异常返回。
- 《霸王三国志》专属 Co-Simulation 在周期 165976490、ROM `$03D82C RTS` 后记录两路径的 PC=`$03DB28`、A7=`$FFEF8C`、SR=`$2000`、栈周围 64 字节和其余 D/A 寄存器完全相同；**生成路径的隐藏控制状态 `g_rte_pending=65`，解释器为 0**。下一条原版指令 `$03DB28 LEA $20(SP),SP` 本应执行；原生 C 调用包装因该计数提前返回。逐指令第 108 个检查点原生周期 165976626、A7=`$FFEFBA`，解释器周期 165976498、PC=`$03DB2C`、A7=`$FFEFAC`。诊断工具新增只读 `control`/`stack` 命令，记录主机控制状态与 64 字节原始栈。
- 根因在生成器 `profiles/genesis/code_generator.c`：循环中的 `$03D7FA CLR.L -(SP)` 已正确预递减并写入 4 字节，但未把这次压栈计入 `_sp_popped`；每次 `$03D802 ADDQ.L #4,SP` 清理参数都凭空增加一个“跨层返回”计数。补上 CLR.L `-(SP)` 的预扫描与计数后重生成 32 个分片；生成的 `$03D7FA` 现有 `_sp_popped -= 1`。从周期 165975000 起原生/解释器 CPU、时序、VDP 连续 300 个逐指令检查点零差异。已有早期 1200 检查点回归也通过。中断异常帧中的 PC 字节仍存在独立的 RAM 摘要差异，所以晚期比较仅对这三个子系统宣称一致。
- 对原先 `$003A2A -> $0038A8` 的严格 JSR 栈告警做了同一路径复测：修复后 `GENESIS_STRICT_JSR_STACK=1` 运行前 120 帧成功结束，无栈失配、无解释器调用。旧日志的 `pre=$FFEFE4 slot=$FFEFE0 post=$FFEFE8` 对应 CLR.L `-(SP)` 未真实预递减的旧生成代码；本轮修复后该告警未再出现。后续长时间严格模式仍需验证。
- 普通 macOS 运行器**重新链接之后**，第 1800 帧实际帧缓冲为汉化历史叙述画面 `apps/macos/build/native_clr_relinked_1800.png`，哈希 `0x2CA864E13479BFFD`，而修复前在第 1200 帧起冻结于 `0xAB17B2922B684A9C`。该次运行解释器调用 0；第 1344 帧发现新的原始分发缺口 `$00194A`，ROM 从此地址为 `MOVE SR,-(SP)` / `ORI #$0700,SR`，已加入专属配置重新生成。新运行第 2200 帧仍显示持续变化的原版汉化开场叙述，截图 `apps/macos/build/native_194a_2200.png`；解释器调用 0、原始分发缺口 0。第 1330 帧起原生/解释器 CPU、时序、VDP 逐帧 120 个检查点零差异。标题菜单尚无验收。
- 第 5000 帧截图 `apps/macos/build/native_194a_5000.png` 显示原版董卓叙事画面，哈希 `0x252EDEF86C90164D`；解释器调用 0、原始分发缺口 0，游戏入口未异常返回。`tests/bawang_start_probe.input` 在第 650–740 帧保持 Start 后，第 1490 帧画面与无输入运行相同，说明此时按键没有跳过开场；不能据此推断菜单操作已经可用。更长开场流程正在测试。
- 第 6000 帧的原版董卓头像画面后保持 Start 90 帧，原生游戏在第 7000 帧显示原版七项剧本菜单，实拍帧缓冲在 `apps/macos/build/bawang_intro_{7000,8000}.png`。该输入路径在第 6024/6033 帧出现 `$0009F2` / `$0007A0` 两处真实动态入口；均核对 ROM 为合法指令序列、加入 `game.toml` 并重新生成 32 个分片。新原生运行 `tests/bawang_menu_probe.input` 的第 7001/7091 帧截图证明 Down 把指示箭头从第 1 项移到第 2 项。A 键后第 7451 帧仍为剧本菜单，尚未验证确认/新游戏。新入口后的解释器回退计数待无提前 EXIT 的运行收尾核对。
- Co-Simulation 工具现在支持 `--input-script`，同一绝对路径传入原生和解释器实例，补丁 `scripts/patches/m2-cosim-input-script.patch`。已检查缺失脚本会在启动前报错；修复长启动预热超过 30 秒时的工具 socket 超时。`tests/bawang_start_only.input` 在第 6000 帧按 Start，从第 6000 帧起原生/解释器 CPU、时序、VDP 逐帧 100 个检查点零差异。
- C 键选中剧本的原生首次试运行在第 7092 帧出现 `$000688` 动态入口缺口，随后的第 7691 帧第二行字符损坏；7800 帧计数为 4767 次原始分发事件及 2 次**动态分发调用**。上游日志标签 `[INTERP] hybrid_jmp/call_interpret` 容易误解：源码中的这两个函数实际转到原生 `call_by_address`；此轮明确设置 `GENESIS_FLOOR=0`，没有在这些调用中执行解释器。缺口导致目标函数被略过，仍是错误路径。ROM `$000688` 为 `$000684 RTS` 后的有效代码，已加入专属配置并重生成。
- `$000688` 补入后，macOS 普通/Co-Simulation 运行器及 macOS/iOS ARM64 静态库均重建成功；`lipo -info` 显示两套库均为 arm64。尚待 C 键复测结果，不能沿用前一次有回退的菜单结论。
- `$000688` 修复后的 C 键复测在第 7099 帧遇到新的 `$00B54E` 原始分发缺口；7800 帧累计 1 次原始缺口、3 次原生动态分发调用，最终帧为黑屏。使用同一 Start/Down/C 输入的 Co-Simulation，在第 7080–7098 帧 CPU、时序、VDP 一致，第 7100 帧首个分歧：原生 PC=`$005F26`、A7=`$FFEE8A`，解释器 PC=`$000794`、A7=`$FFEF2E`，三个子系统同时偏离。ROM `$00B54E` 以 `LINK A6,#-4` 起始，已加入专属配置重新生成。
- `$00B54E` 修复后于第 7105 帧到达 `$0005B0` 新入口；前一版 7800 帧已出现原版地图与“多少個玩家”提示，但仍有 1 次原始缺口、5 次原生动态分发调用。Co-Simulation 第 7106 帧首次仅 VDP 子系统差异，CPU/时序仍匹配。ROM `$0005B0` 为 `$0005AE RTS` 后的有效指令流，已加入配置并重生成。
- `$0005B0` 修复后的原生 benchmark 跑满 7800 帧，原始分发缺口 **0**；上游 `[INTERP]` 标签报告的 5 次实际为已生成 C 的原生间接分发，`GENESIS_FLOOR=0` 排除了缺口解释器执行。第 7691 帧原版地图 PNG 与诊断解释器逐字节一致，画面显示“多少個玩家”。此项 benchmark 的有窗口零缺口复测仍在运行。
- 玩家数输入进一步复测：地图“多少個玩家”画面按 Up 后数值变化，按 C 进入原版“玩家 1：请选择国家”君主选择画面。原生 8500 帧原始分发缺口 0；原生/诊断解释器的地图、数值变化、君主选择三张 PNG 逐字节相同，八个每 1000 帧采样哈希相同。相同输入的 Co-Simulation 从第 7680 帧起对 CPU、时序、VDP 连续 **820 个逐帧检查点零差异**。玩家数及君主选择证明原版菜单可实际操作；尚待确认君主并进入回合游戏。
- 构建：重新生成真实 ROM 的 32 个 C 分片；macOS 普通/Co-Simulation 运行器以及 macOS/iOS ARM64 静态库编译成功。上游 CTest 15/15，项目 Co-Simulation 6/6（含晚期开场和 `$00194A` 动态入口回归）。生成器/运行时补丁已更新在 `scripts/patches/`。M2 未通过，iOS App/真机仍未完成。

## 2026-10-16 M2 首个分歧修复进展

- 使用上游 `runner/cosim.c` 和 `tools/genesis_cosim.py` 建立本游戏专属 `cosim.json` 与 `BawangMac_cosim`。同模式原生/原生、解释器/解释器各 20 检查点零差异；D0 注入在检查点 7 被准确检出。修复了协同工具在 ARM64 上用 `volatile` 跨线程发布检查点造成的虚假链分歧，改为 C11 原子变量。
- 第一处实际执行顺序差异：ROM `$000300 BSR $000BEC`。原生生成代码原先在被调函数返回后才计入 BSR 周期，解释器在调用前计入。修复生成器中 JSR/BSR 的计时位置后，原生/解释器连续 5,000 个每 100 周期检查点零差异。
- 下一处：`$001A3E RTS`，原生原先到 C 调用者才弹出返回地址，解释器在 RTS 指令内弹出；中间检查点 A7 差 4。生成器现在在 RTS 指令内弹栈，保持后续 JSR 包装不重复弹栈。
- 下一处实际 RAM/寄存器分歧：`$00368A CLR.L -(SP)`。原生原先未预递减 A7，解释器正确减 4。修复生成器 CLR 的 EA 写入模式并重生成 32 个分片。
- `$FFF000` 是合法 MD 工作 RAM 中的**真实复制代码**。启动时 `$00025C` 清零该区域；`$000346/$000348/$00034A` 在第 2 帧、周期 364110/364130/364150 将 ROM `$00034E` 的 10 字节 `38ad004238ad00444e75` 复制到 `$FFF000`。原生与解释器的写入 PC、地址、值和周期一致；两者均执行到 RAM `$FFF008`，此前原生停在 RAM 分发。新增脚本从本地 ROM 验证并生成这段短程序的静态 C 翻译，运行时逐字节核对 RAM；未知变体报错退出，不回退解释器。修复后跨过该调用的 1,200 个逐指令检查点零差异。
- 中断返回仍有协同执行差异：在约 1,282,074 周期，两路径 CPU/时序/VDP 相同，合成异常帧中的返回 PC 字节不同。原生 `g_cpu.PC` 只保留块级/先前控制流位置，解释器保留逐指令下一 PC；这导致 RAM 摘要不同。运行时现为 V/H 中断压入 SR/PC 异常帧，并让诊断解释器真正执行 RTE，但**中断帧 PC 对齐尚未完成**，不能宣称全程零差异。
- macOS 原生运行：第 180 帧实际帧缓冲显示原版 SEGA 标志，第 600 帧显示《霸王三国志》游戏标志；截图分别在本地忽略目录 `apps/macos/build/native_after_fixes_{180,600}.png`。两次 `GENESIS_FLOOR=0` 运行解释器调用 0、原始分发缺口 0。第 1800 帧停在开场文字“大地已死”；第约 1150 帧出现 `$00069C` 内部标签分发缺口，随后主入口异常返回，原始分发缺口累计 132，解释器调用仍为 0。**标题菜单、新游戏和 M2 仍未通过。**
- 回归：上游 CTest 15/15；项目 `tests/test_m2_cosim.py` 4/4；macOS/iOS ARM64 生成代码静态库均成功构建。iOS App 与真机尚无结果。
- 修复源：上游生成器、运行时和协同工具的可重复补丁位于 `scripts/patches/`；游戏专属 RAM 翻译脚本为 `scripts/generate_ram_helper.py`。ROM、生成 C、截图及用户分析附件保留本地，不纳入公开 Git。

## 已完成

- M0：检查附件并解包原有分析；SMD 为 1,049,088 字节，转换 BIN 为 1,048,576 字节，SHA256 `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`。复位向量 `0x000200`，SSP `0x00FFF000`，H/V 中断向量 `0x00112C` / `0x001130`。
- 工具链：Xcode 26.6、Apple Clang 21.0.0、CMake 4.4.4、Ninja 1.13.2、Python 3.14.7；安装 SDL2 compatibility 2.32.74 用于桌面运行器。
- 上游 `segagenesisrecomp` 通过 `git clone --recursive` 拉取，提交 `f875aa8eac5e0749ce42c3f1cec601b6317c6b51`。子模块固定提交见 `git submodule status`；重编译器构建成功，框架 15/15 项 CTest 通过。
- M1：真实 ROM 经 `games/bawang_sanguozhi/game.toml` 生成 32 个 C 分片（约 26 MB）。加入运行轨迹目标后，生成器报告 1,348 个函数条目、47 处自动识别的 PC 索引表、320 个候选目标、3 个拒绝目标、2 个未解析点（两条均指复位跳板 `0x000386` 的寄存器跳转）。其中 28 处 hybrid offset-table 分派与附件的 28 处数字相同，尚未逐一动态验证。
- 全部生成 C 分片编译为 macOS ARM64 和 iOS ARM64 静态库。iOS 静态库只证明目标架构编译，尚未链接成 App。
- M2 桌面运行器 `apps/macos/BawangMac` 已链接并运行真实重编译程序。首次在第 8 帧发现 `0x001970` 分派缺口；核对 ROM 指令后将该地址加为 `late_extra`。
- 定位并修复上游生成器的 `RTR` 语义错误：ROM 的 `0x000BFC` 以 `RTR` 返回，旧生成 C 却把它当 `RTE` 向外层传播，使 `0x0039F4` 首次调用后直接退出。修复保存在 `scripts/patches/m68k-rtr-return.patch`，自动生成 C 未手改。随后按 ROM 首指令核对，把新发现的 12 个动态目标加入 `late_extra`。

## 源码和构建

- `scripts/smd_to_bin.py`：SMD 转 BIN 并强制校验 SHA256。
- `scripts/generate.sh`：从用户本地 ROM 重新生成 C。
- `games/bawang_sanguozhi/game.toml`：ROM 专属入口、栈及发现配置。
- `scripts/patches/m68k-rtr-return.patch`、`scripts/apply_upstream_patches.sh`：可重复应用的生成器修复。
- `games/bawang_sanguozhi/CMakeLists.txt`：生成代码的 macOS/iOS ARM64 静态库构建。
- `apps/macos/bawang_spec.c`、`apps/macos/CMakeLists.txt`：桌面 GameSpec 与原生运行器构建。
- 自动生成 C、ROM、截图和构建产物均位于被忽略的 `build/` / `input/`，不应公开提交。

复现命令（仓库根目录）：

```sh
cmake -S third_party/segagenesisrecomp/recompiler -B third_party/segagenesisrecomp/build/recompiler -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build third_party/segagenesisrecomp/build/recompiler -j 4
cmake -S third_party/segagenesisrecomp/tests -B third_party/segagenesisrecomp/build/tests -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build third_party/segagenesisrecomp/build/tests -j 4
ctest --test-dir third_party/segagenesisrecomp/build/tests --output-on-failure
sh scripts/apply_upstream_patches.sh
cmake --build third_party/segagenesisrecomp/build/recompiler -j 4
sh scripts/generate.sh
cmake -S games/bawang_sanguozhi -B games/bawang_sanguozhi/build/native -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build games/bawang_sanguozhi/build/native -j 4
cmake -S games/bawang_sanguozhi -B games/bawang_sanguozhi/build/ios -G Ninja -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 -DCMAKE_BUILD_TYPE=Release
cmake --build games/bawang_sanguozhi/build/ios -j 4
cmake -S apps/macos -B apps/macos/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build apps/macos/build -j 4
GENESIS_FLOOR=0 apps/macos/build/BawangMac input/bawang_sanguozhi.bin --max-frames 120 --hash-frames 30
# 仅供诊断对照，最终原生运行不得依赖解释器：
GENESIS_FORCE_INTERP=1 apps/macos/build/BawangMac input/bawang_sanguozhi.bin --max-frames 600 --hash-frames 120
```

## 测试及失败

- 附件的三个手工 C 函数：机器码范围和 10,000 组随机/边界测试通过。这不验证全游戏。
- 修复前的 120 帧：游戏入口异常返回，画面哈希固定为 `0x2A0B972960C5E325`、截图纯黑。返回时 PC `0x003A0C`，A7 `0x00FFEFE8`，A6 `0x00FFEFFC`，SR `0x2000`，原生指令数 121,225。
- 修复 RTR 并加入 12 个动态入口后的**旧基线** 180 帧：画面哈希在第 30/60/90 帧为 `0x2A0B972960C5E325` / `0x700D6FB9DFAC78BF` / `0x16B3A2435187AE99`，之后保持不变。截图为蓝色噪点。日志报 `unrunnable RAM code $FFF000 ... bad_pc=$FFF008 bad_op=$00FF`；这已证实是合法 RAM 中缺少静态分发，不能据此认定地址无效。此旧基线已被上述 0.2.0 修复取代。
- `GENESIS_STRICT_JSR_STACK=1` 的首个失败为 `JSR stack mismatch at $003A2A -> $0038A8: pre=$00FFEFE4 slot=$00FFEFE0 post=$00FFEFE8`。需用参考 68000 执行确认是有意的栈调整还是转换错误。
- 仅供开发诊断的 `GENESIS_FORCE_INTERP=1` 使用同一 ROM/同一 VDP 运行时：第 180 帧截图为原版 SEGA 标志，第 600 帧截图为原版《霸王三国志》标志，第 1200 帧为后续开场文字；1200 帧记录 1,652 个执行 PC。解释器路径验证硬件层至少能输出开场画面，不能计入原生验收。对应截图在 `apps/macos/build/bawang_interp_{180,600,1200}.png`，PC 集在 `games/bawang_sanguozhi/build/interp_1200_pcs.txt`（均未提交）。
- 逐帧画面哈希对比：原生与解释器在第 1–2 帧相同，第 3 帧首次不同（原生 `0xAC608C4CBB012B25`，解释器 `0xE97846EB7709A325`）。这只定位首个可见输出差异；首个 CPU 状态分歧仍需协同执行跟踪。
- 生成器仍有多处 `MISALIGNED_FUNC_ENTRY` 警告；应逐个核对代码/数据重叠及实际可达性，不可把 1,348 个条目视为已验证函数。

## 未解决及下一步

1. M3：从袁术「情報→他國」后继续执行一次消耗行动的内政/军事命令及回合推进，逐段对照原生与解释器 CPU/VDP/SRAM；当前只验证首回合菜单和资料查询。
2. 运行参考 MD 环境，验证 28 处原有跳转表和剩余间接调用；分类新自动发现候选，记录整局动态 PC 覆盖率。当前 23,100 帧 0 分发缺口仅证明所跑路径。
3. 继续核对中断异常帧的 PC 字节、严格 JSR 栈检查及更长剧情/AI/存档路径；不能以已通过的首回合路径推断整款游戏逻辑均完成静态覆盖。
4. M3 桌面流程更完整后建立 Swift/Metal iOS App、文件导入、SRAM、本机输入和音频；最后检查 iOS 真机。当前只有 iOS ARM64 静态库，无可安装 App、IPA 或真机运行结果。

上游主仓库及重编译器使用 PolyForm Noncommercial 1.0.0；游戏 ROM 与资源版权需要单独确认。未推送或公开 ROM。
