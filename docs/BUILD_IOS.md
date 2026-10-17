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

当前版本 **0.1.1 Build 9**。模拟器虚拟按钮的实际点击与真机安装尚未验收；机器上 iPhone 当前显示 Offline。具体游戏流程和测试结果见 [PROGRESS.md](PROGRESS.md)。

## 可选内置 ROM 与本机未签名 IPA

只有在私有测试环境使用用户持有的 ROM。`apps/ios/BawangSanguozhi/Resources/bawang_sanguozhi.bin` 被 Git 忽略；缺少它时 XcodeGen 仍能生成可手动导入 ROM 的 App。

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

## 私有 GitHub Actions 构建

`.github/workflows/build-unsigned-ipa.yml` 仅支持手动 `workflow_dispatch`，在公开仓库会于读取 ROM 前拒绝执行。请另建**私有**代码镜像仓库，并在该私有仓库的 `private-rom` Release 上传名为 `bawang_sanguozhi.smd` 的用户持有 ROM。示例命令（将仓库名替换成自己的私有仓库；下列命令不会自动执行）：

```sh
gh repo create YOUR_ACCOUNT/BaWangSanGuoZhi-iOS-private --private
git remote add private git@github.com:YOUR_ACCOUNT/BaWangSanGuoZhi-iOS-private.git
git push private main
cp input/霸王三国志.smd input/bawang_sanguozhi.smd
gh release create private-rom input/bawang_sanguozhi.smd \
  --repo YOUR_ACCOUNT/BaWangSanGuoZhi-iOS-private \
  --title 'Private ROM input' --notes 'Private build input' --latest=false
```

确认私有仓库及 Release Asset 的权限后，在私有仓库 Actions 页面手动运行 **Build Bawang Sanguozhi Unsigned IPA**。工作流用该仓库的 `GITHUB_TOKEN`（`contents: read`）下载 Release Asset，构建并验证后仅在私有仓库上传 `BawangSanguozhi-iOS-Unsigned-v0.1.1-build9`，保留 7 天。当前公开仓库不能安全运行含 ROM 的构建，也不会上传该 IPA。Runner 采用 `macos-26` ARM64 并明确选择 Xcode 26.6；GitHub Runner [镜像清单](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)列有该版本。实际 Actions 运行结果需在私有仓库设置后验证。
