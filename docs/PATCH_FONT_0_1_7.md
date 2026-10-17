# v0.1.7 Build 15：内存字库级“劉備→刘备”试验

## 改动

- **不再使用 OCR / 手动框选字形**。删除 iOS 菜单中的旧“字形校准”入口，运行渲染时不再执行 `GameTextLocalization` 的后处理。旧的辅助 Swift 源文件可暂时保留，但不会被调用。
- 先严格校验用户已持有的原版标准 BIN；游戏运行时 `glue_init` 将该 ROM 复制到 `g_rom` 后，修改**内存副本**的两个 16×16 单色字模，ROM 磁盘文件保持不变：

  | 原字 | 字码 | ROM 偏移 | 简体字形 |
  |---|---|---|---|
  | 劉 | `83A4` | `05B0C0` | 刘 |
  | 備 | `8196` | `056356` | 备 |

- 两个字模各 32 字节，整个改动严格限于这两个槽位；不修改文字指针、游戏逻辑、原版 SRAM 或存档格式。替换数据基于上次字库提取工具输出。
- 设置 → 游戏文字：**繁体原版 / 简体·字库测试**。设置值延用 `BawangGameLanguage`，升级后保留之前选择。
- **切换后不是即时全屏重绘**：已经传入 MD VDP 显存的汉字图块要等游戏自身重新从 ROM 取字模，才会变成新语言。最可靠的对照方法是在主菜单选择语言，然后重新进入“选择剧本/君主”页面，或在打开应用前选好语言。运行中不会自动重启或重载存档。

## 验证边界

已执行：C11 编译；两个字模限定范围、可重复应用、繁简可逆、非法输入无副作用；macOS 与 iphoneos ARM64 核心构建、iphoneos Release 无签名 App 构建及内置 ROM 的 IPA 校验。**未执行：iPhone 真机画面测试。**

“劉備”两个字形可能在部分已有的 VDP 图块中保留原样，这是 VRAM 缓存行为，不表示字库 offset 错。若重新进入界面后仍未改变，需要对 ROM 字码选择器与实际字模上传路径做动态追踪。

## 安装前

当前补丁以用户已应用的 **0.1.6 Build14** 为基础。先运行 `git apply --check`，无误再应用。不要清理用户 SRAM 或卸载 App，保持 Bundle ID 并直接覆盖安装。工作流依旧仅 `workflow_dispatch`，IPA 输出更新为 **0.1.7 Build15**。

## 测试命令

```bash
python3 tests/test_bawang_font_overlay.py --rom input/bawang_sanguozhi.bin
xcodegen generate --spec apps/ios/project.yml
```

C 库新源文件 `apps/core/bawang_font_overlay.c` 已加入 `apps/core/CMakeLists.txt`；其余新旧核心 API 完全保留。

## 字库索引

另附一份不包含整份 ROM 的“974 字模目录”：独立 HTML 浏览器可以看到每个字形、4 位自定义字码、ROM 地址；CSV、Excel 及 8 张图谱可交叉查询。只有 **劉、備、董、卓** 四个字符完成 Unicode 可靠映射，剩余 970 个仅精确识别其字模位置，字符文字标签待核对。不要将内部字码误当成 Unicode/Big5/GBK。
