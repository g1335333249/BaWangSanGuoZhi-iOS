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


def run(name, a, b, stride, count, *, inject=False, start=0,
        start_frame=0, clock="cycle", subs=None, input_script=None,
        benchmark=False):
    ports = 4700 + run.serial * 2
    run.serial += 1
    cmd = [sys.executable, str(TOOL), "--game-config", str(CONFIG),
           "--exe", str(EXE), "--a", a, "--b", b, "--clock", clock,
           "--stride", str(stride), "--max", str(count),
           "--porta", str(ports), "--portb", str(ports + 1)]
    if inject:
        cmd += ["--inject-at", "5", "--inject", "reg:0:1"]
    if subs:
        cmd += ["--subs", subs]
    if input_script:
        cmd += ["--input-script", str(ROOT / input_script)]
    if benchmark:
        cmd += ["--runner-benchmark"]
    env = os.environ.copy()
    if start:
        env["GENESIS_COSIM_START_CYCLE"] = str(start)
    if start_frame:
        env["GENESIS_COSIM_START_FRAME"] = str(start_frame)
    p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True,
                       timeout=120)
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
    # $03D7FA CLR.L -(SP) runs in a loop. Missing generator stack accounting
    # accumulated a false 65-level return skip at $03D82C and skipped $03DB28.
    # IRQ exception-frame PC bytes still differ while native PC is block-level;
    # compare architectural CPU, timing, and rendered VDP state here.
    run("CLR stack accounting at late intro", "recomp", "interp",
        1, 300, start=165975000, subs="cpu68k,timing,vdp")
    run("dynamic $00194A entry and continuing intro", "recomp", "interp",
        1, 120, start_frame=1330, clock="frame", subs="cpu68k,timing,vdp")
    run("Start/Down/C scenario selection", "recomp", "interp",
        1, 180, start_frame=7080, clock="frame", subs="cpu68k,timing,vdp",
        input_script="tests/bawang_menu_c_only.input", benchmark=True)
    run("player count and ruler selection", "recomp", "interp",
        1, 820, start_frame=7680, clock="frame", subs="cpu68k,timing,vdp",
        input_script="tests/bawang_player_count_only.input", benchmark=True)
    # $039A7A MOVE.L (SP)+,D2 consumes a data argument, not the JSR return.
    # The old wrapper propagated _sp_popped and resumed at the wrong PC.
    run("data stack pop and JSR return", "recomp", "interp",
        1, 500, start=1858657800, subs="cpu68k,timing,vdp",
        input_script="tests/bawang_one_player_command_probe.input", benchmark=True)
    # Includes the former $004E96 false IRQ-poll yield, the first turn,
    # command-category navigation, and the country-information report.
    run("Yuan Shu turn and command", "recomp", "interp",
        1, 8800, start_frame=14330, clock="frame", subs="cpu68k,timing,vdp",
        input_script="tests/bawang_one_player_command_probe.input", benchmark=True)
