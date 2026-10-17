#!/usr/bin/env python3
"""Run the original 開發 command and compare its SRAM backed native path."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "apps/macos/build/BawangMac"
COSIM_EXE = ROOT / "apps/macos/build-cosim/BawangMac_cosim"
ROM = ROOT / "input/bawang_sanguozhi.bin"
SCRIPT = ROOT / "tests/bawang_m3_develop.input"
COSIM = ROOT / "third_party/segagenesisrecomp/tools/genesis_cosim.py"
CONFIG = ROOT / "games/bawang_sanguozhi/cosim.json"


def execute(command, env, timeout=180):
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            capture_output=True, timeout=timeout)
    output = result.stdout + result.stderr
    assert result.returncode == 0, output[-4000:]
    return output


def main():
    env = os.environ.copy()
    env.update(GENESIS_FLOOR="0", SDL_VIDEODRIVER="dummy",
               SDL_AUDIODRIVER="dummy")
    output = execute([str(EXE), str(ROM), "--benchmark", "25100",
                      "--input-script", str(SCRIPT)], env)
    assert "[DONE] 25100 frames completed" in output
    assert "0 unique true-miss addrs, 0 raw miss events" in output
    before = (ROOT / "apps/macos/build/m3_domestic_before_ram.bin").read_bytes()
    after = (ROOT / "apps/macos/build/m3_develop_value_ram.bin").read_bytes()
    assert len(before) == len(after) == 65536
    # Gold is the big endian city field observed changing with the on-screen
    # 1000 -> 900 value. No test writes or patches the game RAM.
    assert int.from_bytes(before[0x2942:0x2944], "big") == 1000
    assert int.from_bytes(after[0x2942:0x2944], "big") == 900
    print("PASS native original 開發 command spends 100 gold, 0 raw misses")

    env["GENESIS_COSIM_START_FRAME"] = "21400"
    output = execute([
        sys.executable, str(COSIM), "--game-config", str(CONFIG),
        "--exe", str(COSIM_EXE), "--a", "recomp", "--b", "interp",
        "--clock", "frame", "--stride", "1", "--max", "4000",
        "--porta", "4952", "--portb", "4953", "--subs", "cpu68k,timing,vdp",
        "--input-script", str(SCRIPT), "--runner-benchmark"], env, 240)
    assert "4000 checkpoints, ZERO divergence" in output, output[-4000:]
    print("PASS native/interpreter 4000 CPU, timing and VDP checkpoints")


if __name__ == "__main__":
    main()
