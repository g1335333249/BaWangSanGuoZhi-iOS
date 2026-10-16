# 开发进度

版本：0.2.0（2026-10-16，M2 原生开场已显示，菜单尚未通过）

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

1. 继续协同执行，解决中断异常帧保存 PC 的逐指令一致性；再复核 `$003A2A -> $0038A8` 的栈调用链，定位当前 `$00069C` 内部标签缺口和主入口异常返回，不修改生成 C。
2. 运行参考 MD 环境，验证 28 处原有跳转表和剩余间接调用；分类 47 处新自动发现候选，记录动态 PC 覆盖率。
3. 修复 VDP/中断启动，达到桌面原版标题画面、菜单和新游戏验收；保持解释器回退计数与画面证据。
4. 桌面流程跑通后再建立 Swift/Metal iOS App、文件导入、SRAM、本机输入和音频；最后检查 iOS 真机及严格无解释器路径。当前无 App、IPA 或真机运行结果。

上游主仓库及重编译器使用 PolyForm Noncommercial 1.0.0；游戏 ROM 与资源版权需要单独确认。未推送或公开 ROM。
