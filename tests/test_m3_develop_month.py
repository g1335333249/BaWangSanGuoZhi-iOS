#!/usr/bin/env python3
"""One original domestic action followed by a real month transition."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT / "input/bawang_sanguozhi.bin"
SCRIPT = ROOT / "tests/bawang_m3_develop_month.input"


def run(args, env, timeout=600):
    result = subprocess.run(args, cwd=ROOT, env=env, text=True,
                            capture_output=True, timeout=timeout)
    output = result.stdout + result.stderr
    assert result.returncode == 0, output[-4000:]
    return output


def main():
    env = os.environ.copy()
    env.update(GENESIS_FLOOR="0", SDL_VIDEODRIVER="dummy",
               SDL_AUDIODRIVER="dummy")
    output = run([str(ROOT / "apps/macos/build/BawangMac"), str(ROM),
                  "--benchmark", "31000", "--input-script", str(SCRIPT)], env)
    assert "[DONE] 31000 frames completed" in output
    assert "0 unique true-miss addrs, 0 raw miss events" in output
    ram = (ROOT / "apps/macos/build/m3_develop_month_ram.bin").read_bytes()
    assert len(ram) == 65536 and ram[0x100C] == 1
    assert int.from_bytes(ram[0x2942:0x2944], "big") == 900
    print("PASS original 開發 then February menu, 900 gold, 0 raw misses")

    env["GENESIS_COSIM_START_FRAME"] = "21400"
    output = run([
        sys.executable,
        str(ROOT / "third_party/segagenesisrecomp/tools/genesis_cosim.py"),
        "--game-config", str(ROOT / "games/bawang_sanguozhi/cosim.json"),
        "--exe", str(ROOT / "apps/macos/build-cosim/BawangMac_cosim"),
        "--a", "recomp", "--b", "interp", "--clock", "frame",
        "--stride", "1", "--max", "9600", "--porta", "4954",
        "--portb", "4955", "--subs", "cpu68k,timing,vdp",
        "--input-script", str(SCRIPT), "--runner-benchmark"], env)
    assert "9600 checkpoints, ZERO divergence" in output, output[-4000:]
    print("PASS native/interpreter 9600 CPU, timing and VDP checkpoints")


if __name__ == "__main__":
    main()
