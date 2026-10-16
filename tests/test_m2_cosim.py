#!/usr/bin/env python3
"""ROM-backed M2 co-simulation regressions for the macOS diagnostic runner."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "third_party/segagenesisrecomp/tools/genesis_cosim.py"
EXE = ROOT / "apps/macos/build-cosim/BawangMac_cosim"
CONFIG = ROOT / "games/bawang_sanguozhi/cosim.json"


def run(name, a, b, stride, count, *, inject=False, start=0):
    ports = 4700 + run.serial * 2
    run.serial += 1
    cmd = [sys.executable, str(TOOL), "--game-config", str(CONFIG),
           "--exe", str(EXE), "--a", a, "--b", b, "--clock", "cycle",
           "--stride", str(stride), "--max", str(count),
           "--porta", str(ports), "--portb", str(ports + 1)]
    if inject:
        cmd += ["--inject-at", "5", "--inject", "reg:0:1"]
    env = os.environ.copy()
    if start:
        env["GENESIS_COSIM_START_CYCLE"] = str(start)
    p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True,
                       timeout=90)
    output = p.stdout + p.stderr
    expected = (
        p.returncode == 1 and "cpu68k" in output and "FIRST DIVERGENCE" in output
    ) if inject else (p.returncode == 0 and "ZERO divergence" in output)
    if not expected:
        print(f"FAIL {name}:\n{output[-4000:]}", file=sys.stderr)
        raise SystemExit(1)
    print(f"PASS {name}")


run.serial = 0


if __name__ == "__main__":
    assert EXE.is_file(), "Build BawangMac_cosim first"
    assert (EXE.parent / "bawang_sanguozhi.bin").is_file(), "Link local ROM next to runner"
    run("native determinism", "recomp", "recomp", 1000, 20)
    run("interpreter determinism", "interp", "interp", 1000, 20)
    run("difference injection", "recomp", "recomp", 1000, 20, inject=True)
    run("native/interpreter boot and copied RAM helper", "recomp", "interp",
        1, 1200, start=1195000)
