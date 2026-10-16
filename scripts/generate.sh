#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/smd_to_bin.py input/霸王三国志.smd -o input/bawang_sanguozhi.bin
third_party/segagenesisrecomp/build/recompiler/GenesisRecomp \
  input/bawang_sanguozhi.bin \
  --game games/bawang_sanguozhi/game.toml \
  --output-dir games/bawang_sanguozhi/build/generated
python3 scripts/generate_ram_helper.py
