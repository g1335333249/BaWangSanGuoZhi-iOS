#!/usr/bin/env python3
"""Slow end-to-end original cartridge save/load test (about six minutes)."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "apps/macos/build/BawangMac"
ROM = ROOT / "input/bawang_sanguozhi.bin"


def run(exe, script, extra=()):
    env = os.environ.copy()
    env.update(GENESIS_FLOOR="0", SDL_VIDEODRIVER="dummy",
               SDL_AUDIODRIVER="dummy")
    process = subprocess.run([str(exe), str(ROM), *extra, "--input-script",
                              str(ROOT / "tests" / script)], cwd=ROOT,
                             env=env, text=True, capture_output=True,
                             timeout=900)
    output = process.stdout + process.stderr
    assert process.returncode == 0, output[-4000:]
    if "--benchmark" in extra:
        assert "0 unique true-miss addrs, 0 raw miss events" in output
    return output


def main():
    with tempfile.TemporaryDirectory(prefix="m3_save_", dir=ROOT / "apps/macos/build") as tmp:
        exe = Path(tmp) / "BawangMac"
        shutil.copy2(RUNNER, exe)
        output = run(exe, "bawang_m3_original_save.input",
                     ("--no-launcher", "--turbo"))
        assert "[SRAM] flushed 65536 bytes" in output
        save = Path(tmp) / "bawang_sanguozhi.srm"
        data = save.read_bytes()
        assert len(data) == 65536 and sum(byte != 0 for byte in data) > 4000
        print("PASS original menu saved populated 64 KiB SRAM")

        output = run(exe, "bawang_m3_load_saved.input", ("--benchmark", "10500"))
        assert "[SRAM] loaded 65536/65536 bytes" in output
        assert "[DONE] 10500 frames completed" in output
        ram = (Path(tmp) / "m3_load_later_ram.bin").read_bytes()
        assert len(ram) == 65536
        assert ram[0x100C] == 0  # original January state
        assert int.from_bytes(ram[0x2942:0x2944], "big") == 1000
        print("PASS original game loaded January Yuan Shu city with 1000 gold")


if __name__ == "__main__":
    main()
