#!/usr/bin/env python3
"""Exercise Yuan Shu's two provinces and compare the next-month state."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "apps/macos/build/BawangMac"
COSIM_EXE = ROOT / "apps/macos/build-cosim/BawangMac_cosim"
ROM = ROOT / "input/bawang_sanguozhi.bin"
SCRIPT = ROOT / "tests/bawang_m3_month_probe.input"
COSIM = ROOT / "third_party/segagenesisrecomp/tools/genesis_cosim.py"
CONFIG = ROOT / "games/bawang_sanguozhi/cosim.json"


def execute(command, env):
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            capture_output=True, timeout=150)
    output = result.stdout + result.stderr
    assert result.returncode == 0, output[-4000:]
    return output


def main():
    assert EXE.is_file() and COSIM_EXE.is_file() and ROM.is_file()
    env = os.environ.copy()
    env.update(GENESIS_FLOOR="0", SDL_VIDEODRIVER="dummy",
               SDL_AUDIODRIVER="dummy")
    output = execute([str(EXE), str(ROM), "--benchmark", "28500",
                      "--input-script", str(SCRIPT)], env)
    assert "[DONE] 28500 frames completed" in output
    assert "0 unique true-miss addrs, 0 raw miss events" in output
    ram = (ROOT / "apps/macos/build/m3_month_end_ram.bin").read_bytes()
    assert len(ram) == 65536 and ram[0x100C] == 1
    print("PASS native January-to-February path, 0 raw misses and 0 fallback")

    env["GENESIS_COSIM_START_FRAME"] = "17000"
    output = execute([
        sys.executable, str(COSIM), "--game-config", str(CONFIG),
        "--exe", str(COSIM_EXE), "--a", "recomp", "--b", "interp",
        "--clock", "frame", "--stride", "1", "--max", "11000",
        "--porta", "4950", "--portb", "4951",
        "--subs", "cpu68k,timing,vdp", "--input-script", str(SCRIPT),
        "--runner-benchmark"], env)
    assert "11000 checkpoints, ZERO divergence" in output, output[-4000:]
    print("PASS native/interpreter 11000 CPU, timing and VDP checkpoints")


if __name__ == "__main__":
    main()
