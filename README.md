# 霸王三国志：Mega Drive 静态重编译移植

这是进行中的原生移植工程。macOS 原生运行器已能从真实 ROM 执行开场并显示 SEGA 和《霸王三国志》标志；标题菜单和新游戏尚未通过。iOS ARM64 静态库可以编译，尚无 iOS App 或真机运行结果。详见 [进度记录](docs/PROGRESS.md)。

本仓库不包含 ROM、自动生成的游戏代码、截图、用户分析附件或第三方源码。用户需将自行持有的 `霸王三国志.smd` 放入 `input/`。转换后的 BIN SHA256 必须为 `e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9`。

在 macOS 上安装 Xcode 命令行工具、CMake、Ninja、SDL2 后，从仓库根目录运行：

```sh
sh scripts/bootstrap_upstream.sh
cmake -S third_party/segagenesisrecomp/recompiler -B third_party/segagenesisrecomp/build/recompiler -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build third_party/segagenesisrecomp/build/recompiler -j 4
sh scripts/generate.sh
cmake -S apps/macos -B apps/macos/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build apps/macos/build -j 4
GENESIS_FLOOR=0 apps/macos/build/BawangMac input/bawang_sanguozhi.bin --max-frames 600 --turbo
```

协同诊断需以 `-DBAWANG_BUILD_COSIM=ON` 另建 macOS 构建目录，并将本地 BIN 链接到可执行文件同目录；运行 `python3 tests/test_m2_cosim.py`。详细命令、测试和未解决问题见进度记录。

上游 `segagenesisrecomp` 使用 PolyForm Noncommercial 1.0.0；游戏及资源版权另属权利人。本工程尚不构成可发布游戏。
