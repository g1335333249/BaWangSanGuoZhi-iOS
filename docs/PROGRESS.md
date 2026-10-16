# 开发进度

版本：0.2.3（2026-10-16，原生新游戏启动进入 194 年地图；回合状态分歧未解决，M2 未通过）

## 2026-10-16 单人新游戏启动与新分歧

- 原版玩家数输入是两位数，初始 `00`；先前直接按 Up 得到 `10`，因此袁术确认后继续询问玩家 2。新的 `tests/bawang_one_player_probe.input` 先按 Right 移到个位、再按 Up 得到 `01`。原生真实 ROM 流程依次显示剧本选择、玩家 1 袁术确认、总确认、难度 `1`、战斗画面选项、再次总确认，以及 194 年 5 月游戏地图。
- 新游戏设置与事件入口缺口按轨迹依次发现 `$00D4E4/$00D570`、`$000580/$03C0D0/$0019A0/$0019CA/$016064/$0160F0/$02434E`、`$023EF0/$023D60/$023F5E`、`$010070/$023C52/$0100AC`、`$023B42/$023AB8`。每个入口均核对 ROM 中相邻字节，为 `RTS` 后的指令入口或 `$00199E/$0019C8` 分支跨过的有效序列；仅加入 `game.toml`，未手改生成 C。每次更新重生成 32 个分片，macOS 普通/Co-Simulation 运行器及 macOS/iOS ARM64 静态库均重建成功。最终 `GENESIS_FLOOR=0` 跑满 16,000 帧，`0 raw miss events`。日志 `[INTERP] hybrid_jmp/call_interpret: 707 total calls` 在此配置下计数的是**原生间接分发调用**，不是解释器回退；实际解释器回退为 0。
- 稳定设置画面的原生与诊断解释器 PNG 逐字节一致。`tests/test_m2_menu.py` 对完整 16,000 帧执行原生/原生确定性检查及原生/解释器比较，前者通过，后者**失败**：固定帧哈希首次在第 2700 帧不同，11 张早期/设置截图相同，但第 2700 帧动画截图和第 15,661 帧游戏截图不同。上游已注明固定帧哈希对时序漂移敏感；第 2600 帧起 200 个 Co-Simulation CPU/时序/VDP 检查点零差异，故不能将第 2700 帧采样差异直接归因于 CPU 语义。第 15,661 帧则是实质差异：原生仍显示历史事件文字，解释器已经显示袁术回合命令菜单。两张本地截图为 `apps/macos/build/bawang_one_player_event_{native,interp}.png`；未提交 ROM 或截图。
- 使用同一输入的逐帧 Co-Simulation 从第 8500 帧起，CPU/VDP 前 **4,763** 个检查点一致；第 **4,764** 个检查点首先发生 CPU 差异，VDP 此时仍一致。该点报告原生 PC=`$004E3A`、D0=`0`、D1=`4`、D2=`$0202`、A0=`$FFED8A`，解释器 PC=`$0045B4`、D0=`$F0`、D1=`5`、D2=`$0220`、A0=`$FFED8C`。帧级采样无法把该差异直接归到一条 68000 指令；从周期 3294242000 启动的逐指令比较已经处于不同调用链，尚需在此前更窄的逻辑位置做入口/退出跟踪。**不要把新游戏画面出现误报为 M2 通过。**
- 本轮回归：上游 CTest **15/15**；项目 Co-Simulation **8/8**（含两种同模式确定性、寄存器差异注入、返回/入口修复和菜单输入）。完整新游戏画面比较 **失败 1 项**，为上述未解决 CPU 分歧。`scripts/patches/m2-cosim-input-script.patch` 已包含 `--runner-benchmark`，补丁应用脚本重复运行检查通过。后续最具体任务：在第 4,763–4,764 个逐帧检查点之间记录进入/离开函数的寄存器、栈、`g_rte_pending` 与调用返回状态，找到首个逐指令差异；修复生成器或调度器后重生 32 分片并重跑 16,000 帧。

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

1. 继续协同执行，解决中断异常帧保存 PC 的逐指令一致性；复核 `$003A2A -> $0038A8` 的栈调用链和第 1344 帧 `$00194A` 动态入口后的执行，不修改生成 C。
2. 运行参考 MD 环境，验证 28 处原有跳转表和剩余间接调用；分类 47 处新自动发现候选，记录动态 PC 覆盖率。
3. 修复 VDP/中断启动，达到桌面原版标题画面、菜单和新游戏验收；保持解释器回退计数与画面证据。
4. 桌面流程跑通后再建立 Swift/Metal iOS App、文件导入、SRAM、本机输入和音频；最后检查 iOS 真机及严格无解释器路径。当前无 App、IPA 或真机运行结果。

上游主仓库及重编译器使用 PolyForm Noncommercial 1.0.0；游戏 ROM 与资源版权需要单独确认。未推送或公开 ROM。
