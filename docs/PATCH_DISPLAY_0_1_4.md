# 《霸王三国志》显示兼容补丁 0.1.4 Build 12

基线：GitHub `g1335333249/BaWangSanGuoZhi-iOS` 的 `548183aa8ec11ecbf9eff3902b3a9a4ce2d5c88e`。

## 变更范围

- `GameMetalView.swift`：三缓冲 Metal 纹理防止 CPU/GPU 资源争用；源分辨率 256/320×224 不变，用浮点**等比**缩放按可用屏幕尺寸最大化画面。显示分配会为左右按键保留空间。
- `GameDisplayGeometry.swift`：独立、可测试的显示尺寸计算，无全屏强制拉伸。
- `VirtualPad.swift`：按钮直径由 48pt 调整为 52–68pt（依横屏宽度自适应）；默认未按下时深灰底 alpha=0.43，按下时橙色 alpha=0.72；保留此前 UIKit `UIControl` 按下/抬起、多点触摸的实现。
- `GameFramePresentationFilter.swift`：**显示层**减轻两种已观察到/描述的画面问题：
  1. 章节确认后、只有菜单第一行瞬时异常而下方稳定时，最多保留此前正确画面 8 个渲染帧；整个场景切黑时立即显示新帧。
  2. 地图亮色背景上，局部 8×8 色块突然变为近乎纯黑、其余画面几乎稳定时，暂时复原上一帧亮色像素（最长 36 帧）。允许正常黑字和大面积淡出，不永久隐藏真正的黑画面。
- `BawangApp.swift`：右上角齿轮按钮，添加两个可独立关闭的显示补偿开关；意外隐藏正常动画可直接关闭。默认开启。
- `project.yml`、`package_unsigned_ipa.py`、GitHub Actions：版本升级为 0.1.4 Build 12，修正 Artifact 文件名；工作流保持仅 `workflow_dispatch`。
- `tests/test_ios_presentation_filter.swift`：无 iOS SDK 依赖的显示层逻辑测试。

## 关于“修复”的边界

上述章节乱码和地图黑块的两项改动属于**呈现层异常帧补偿**，不是对 VDP/ROM 错误根因的证明性修复。目前无法运行带上游子模块的完整游戏和 iOS 真机，**不承诺所有剧情过场/所有骑马动画都已根治**。马动画真实黑块形状如果不满足保守过滤条件，仍可能出现。后续应在可复现场景对照参考解释器的 VRAM/CRAM/SAT、VDP 逐行输出，再修上游 `genesis_vdp.c` 对应的实际语义错误，不能盲改透明色或中断投递。

## 已执行验证

- Swift `-frontend -parse`：UIKit/SwiftUI 更新文件均通过语法检查（**非** iOS SDK 类型检查）。
- Swift `-typecheck`：`GameFramePresentationFilter.swift` + `GameDisplayGeometry.swift` 通过。
- Swift 本地可执行回归测试：菜单单行乱码、真黑场、局部黑块、持久黑块、正常黑色文字、4 种横屏尺寸/H32-H40 画面等比检查通过。
- 真正录屏的第 85 帧 → 第 86 帧：过滤器将其判断为局部菜单乱码并保留正常第 85 帧；第 89 帧整屏黑过渡显示不受阻。
- 验证打包脚本为语法合法的 Python，Actions YAML 语法可解析。
- 补丁合入项目后，iphoneos ARM64 Release 无签名 Xcode 构建通过；带内置 ROM 的同目标构建和 IPA 校验通过。**未执行**真实马动画 VDP 对照测试、真机 FPS / GPU 竞争测试。

## 用户安装后必测

1. 章节菜单确认 189 年和其他剧本，观察顶部文字是否还有异常、黑场是否正常衔接。
2. 189 年或 194 年地图，观察马动画经过国家图标时是否还变黑；如仍有异常请再次录屏并在右上角“显示设置”暂时关闭“修补地图小面积黑块”，对比两次表现。
3. 检查左下方向键与右下 A/B/C/START，轻触、长按、多点触摸；字体/菜单不能被新按钮严重遮挡。
4. 实测 256×224 / 320×224 菜单/地图宽度切换和 iPhone 横屏安全区域。
5. 退出 / 重新进入、继续游戏、原版 SRAM 读写不回退。

## Mac 安装方式

在仓库根目录应用 `霸王三国志_iOS_0.1.4_Build12_整合补丁.patch`：

```sh
git apply --check /path/to/霸王三国志_iOS_0.1.4_Build12_整合补丁.patch
git apply /path/to/霸王三国志_iOS_0.1.4_Build12_整合补丁.patch
xcodegen generate --spec apps/ios/project.yml
```

此后正常运行项目原有的本地 iOS 构建流程，或将修改提交、推送 `main` 后手动运行 GitHub Actions。**工作流未增加自动触发。**

测试命令（Mac 安装 Swift 时）：

```sh
swiftc -O \
  apps/ios/BawangSanguozhi/GameView/GameFramePresentationFilter.swift \
  apps/ios/BawangSanguozhi/GameView/GameDisplayGeometry.swift \
  tests/test_ios_presentation_filter.swift -o /tmp/bawang-display-tests
/tmp/bawang-display-tests
```
