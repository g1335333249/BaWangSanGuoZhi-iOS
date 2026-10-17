# iOS 原生运行器构建

工程依赖仓库内 `input/霸王三国志.smd` 生成的真实 ROM 静态代码。按用户本轮授权，指定 SMD 随仓库管理；转换 BIN、生成代码、存档和截图仍只留在构建目录。上游框架许可证为 PolyForm Noncommercial 1.0.0，游戏资源权利独立存在。

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

`BawangCoreSmoke` 验证真实 VDP 输出、非零音频样本、原生指令计数及解释执行次数。`BawangStorageTest` 验证 SMD/BIN 转换、SHA256、SRAM 写入及备份恢复。默认公开源码构建不内置 ROM，用户可通过「导入 ROM」选择原始 SMD 或标准 BIN；跨平台 C 核心转换并校验固定 SHA256 后保存在沙盒。可选私有 ROM 内置构建见下文。接口与宿主职责见 [CORE_API.md](CORE_API.md)。

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

当前版本 **0.1.4 Build 12**。虚拟手柄改用 UIKit 按下/抬起事件和逐帧短触保留；本地输入状态测试通过，真机触控仍待新包复验。显示补偿与适配说明见 [PATCH_DISPLAY_0_1_4.md](PATCH_DISPLAY_0_1_4.md)。具体游戏流程和测试结果见 [PROGRESS.md](PROGRESS.md)。

## 可选内置 ROM 与本机未签名 IPA

`apps/ios/BawangSanguozhi/Resources/bawang_sanguozhi.bin` 被 Git 忽略；缺少它时 XcodeGen 仍能生成可手动导入 ROM 的 App。手动 CI 构建会从仓库中检出的指定 SMD 生成 BIN 并放入该资源位置。

```sh
python3 scripts/smd_to_bin.py input/霸王三国志.smd -o input/bawang_sanguozhi.bin
python3 scripts/prepare_ios_bundle_rom.py input/bawang_sanguozhi.bin
xcodegen generate --spec apps/ios/project.yml
cmake --build apps/core/build-ios-device -j8
xcodebuild -project apps/ios/BawangSanguozhi.xcodeproj \
  -scheme BawangSanguozhi -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -derivedDataPath apps/ios/build-device build
python3 scripts/package_unsigned_ipa.py \
  --app apps/ios/build-device/Build/Products/Release-iphoneos/BawangSanguozhi.app \
  --output-dir apps/ios/build-device/ipa
```

打包器检查实际 `Payload/BawangSanguozhi.app`、iOS ARM64 Mach-O、版本、Bundle ID、原生核心符号和 ROM SHA256。SRAM 始终保存在 Application Support，不写入 Bundle。构建普通无 ROM 版本前运行 `python3 scripts/prepare_ios_bundle_rom.py --clear`，然后重新执行 `xcodegen generate` 与 `xcodebuild`。**未签名 IPA 需要有效签名后才能安装到普通 iPhone。**

## GitHub Actions 一键构建

`.github/workflows/build-unsigned-ipa.yml` 仅支持手动 `workflow_dispatch`。在仓库的 Actions 页面选择 **Build Bawang Sanguozhi Unsigned IPA → Run workflow**；无需 ROM 链接、Secret 或私有 Release。工作流直接校验检出的 `input/霸王三国志.smd` SHA256，使用 `scripts/generate.sh` 转换标准 BIN 并重生 32 个 C 分片，然后构建 iphoneos ARM64 核心和 App、校验 Payload/ROM，并上传 `BawangSanguozhi-iOS-0.1.4-Build12` Artifact，保留 7 天。

Runner 使用 `macos-26` ARM64，并明确选择 Xcode 26.6；GitHub Runner [镜像清单](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)列有该版本。未签名 IPA 下载后仍需有效签名才可在普通 iPhone 安装。GitHub Actions 的实际执行记录与 Artifact 地址应以本次手动运行结果为准。
