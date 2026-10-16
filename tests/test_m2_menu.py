#!/usr/bin/env python3
"""Compare ROM-rendered scenario selection and new game under both CPUs."""
from pathlib import Path
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "apps/macos/build/BawangMac"
ROM = ROOT / "input/bawang_sanguozhi.bin"
SCRIPT = ROOT / "tests/bawang_one_player_probe.input"
SCREENSHOTS = [EXE.parent / line.split(maxsplit=1)[1]
               for line in SCRIPT.read_text().splitlines()
               if line.startswith("SCREENSHOT ")]


def run(interp):
    env = os.environ.copy()
    env["GENESIS_FLOOR"] = "0"
    env.pop("GENESIS_FORCE_INTERP", None)
    if interp:
        env["GENESIS_FORCE_INTERP"] = "1"
    result = subprocess.run(
        [str(EXE), str(ROM), "--benchmark", "16000", "--input-script",
         str(SCRIPT), "--hash-frames", "100"],
        cwd=ROOT, env=env, capture_output=True, text=True, timeout=90)
    log = result.stdout + result.stderr
    assert result.returncode == 0 and "[DONE] 16000 frames completed" in log, log[-3000:]
    assert all(path.is_file() for path in SCREENSHOTS), log[-3000:]
    assert log.count("[SCREENSHOT] wrote") == len(SCREENSHOTS), log[-3000:]
    assert "raw miss events" in log and "0 raw miss events" in log, log[-3000:]
    if not interp:
        assert "[dispatch]" not in log and "entry returned" not in log, log[-3000:]
    hashes = re.findall(r"\[FBHASH\] frame=(\d+) .* hash=(0x[0-9A-F]+)", log)
    return hashes, [path.read_bytes() for path in SCREENSHOTS]


if __name__ == "__main__":
    assert EXE.is_file() and ROM.is_file() and SCRIPT.is_file()
    native = run(False)
    native_repeat = run(False)
    assert native == native_repeat, "native benchmark/input run is nondeterministic"
    interp = run(True)
    if native != interp:
        differing_pngs = [path.name for path, a, b in
                          zip(SCREENSHOTS, native[1], interp[1]) if a != b]
        print(f"Different screenshots: {differing_pngs}", flush=True)
        for index, (a, b) in enumerate(zip(native[0], interp[0])):
            if a != b:
                raise AssertionError(f"first frame-hash difference at sample {index}: "
                                     f"native={a}, interpreter={b}")
        for path, a, b in zip(SCREENSHOTS, native[1], interp[1]):
            if a != b:
                raise AssertionError(f"first screenshot difference: {path.name}")
        raise AssertionError("native and interpreter capture lengths differ")
    print(f"PASS scenario/new game: {len(native[0])} frame hashes and "
          f"{len(SCREENSHOTS)} PNGs identical")
