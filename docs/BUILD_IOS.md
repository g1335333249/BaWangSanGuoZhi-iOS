# iOS 原生运行器构建

工程依赖当前仓库的真实 ROM 静态生成代码；ROM、生成代码、存档和截图均留在本机。上游框架许可证为 PolyForm Noncommercial 1.0.0，游戏资源权利独立存在。

## 生成核心

将用户持有的 `霸王三国志.smd` 放在 `input/` 后运行：

```sh
sh scripts/bootstrap_upstream.sh
cmake -S third_party/segagenesisrecomp/recompiler \
  -B third_party/segagenesisrecomp/build/recompiler -G Ninja
cmake --build third_party/segagenesisrecomp/build/recompiler -j8
sh scripts/generate.sh
cmake -S apps/core -B apps/core/build-macos -G Ninja
cmake --build apps/core/build-macos -j8
apps/core/build-macos/BawangCoreSmoke input/bawang_sanguozhi.bin

cmake -S apps/core -B apps/core/build-ios-simulator -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build apps/core/build-ios-simulator -j8

cmake -S apps/core -B apps/core/build-ios-device -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build apps/core/build-ios-device -j8
```

`BawangCoreSmoke` 验证真实 VDP 输出、非零音频样本、原生指令计数及解释执行次数。`BawangStorageTest` 验证 SMD/BIN 转换、SHA256、SRAM 写入及备份恢复。iOS App 不内置 ROM，运行时由用户通过「导入 ROM」选择原始 SMD 或标准 BIN；跨平台 C 核心转换并校验固定 SHA256 后只在本地沙盒保存标准 BIN。接口与宿主职责见 [CORE_API.md](CORE_API.md)。

## App

```sh
xcodegen generate --spec apps/ios/project.yml
xcodebuild -project apps/ios/BawangSanguozhi.xcodeproj \
  -scheme BawangSanguozhi -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project apps/ios/BawangSanguozhi.xcodeproj \
  -scheme BawangSanguozhi -sdk iphoneos \
  -destination 'generic/platform=iOS' ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO build
```

该 App 的重编译逻辑与 macOS 运行器共用 `games/bawang_sanguozhi/build/generated`，经 `apps/core` 链接；画面由实际 VDP 扫描线输出，经 Metal 呈现。开发中的 68000 解释器仍随框架链接以便统计诊断；App 在发现任何解释执行指令或缺失的 ROM 静态分发入口时停止游戏。Z80 音频路径仍是芯片解释执行，尚未达到整款游戏严格静态原生的最终标准。

当前版本 0.1.0 Build 8。已验证 arm64 Simulator App 安装启动与原版开场画面，以及无签名 iphoneos 构建。模拟器虚拟按钮的实际点击、真机安装和 IPA 尚未验收；机器上 iPhone 当前显示 Offline。具体游戏流程和测试结果见 [PROGRESS.md](PROGRESS.md)。
