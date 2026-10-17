#!/usr/bin/env python3
"""Check the ROM-declared 64 KiB SRAM bus and desktop persistence layer.

This injects a diagnostic bus write; it does not claim the game save menu works.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "apps/macos/build/BawangMac"
ROM = ROOT / "input/bawang_sanguozhi.bin"


def run(exe, script):
    env = os.environ.copy()
    env.update(GENESIS_FLOOR="0", SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
    result = subprocess.run(
        [str(exe), str(ROM), "--no-launcher", "--turbo", "--input-script", str(script)],
        cwd=ROOT, env=env, capture_output=True, text=True, timeout=30)
    log = result.stdout + result.stderr
    assert result.returncode == 0, log[-3000:]
    return log


if __name__ == "__main__":
    assert EXE.is_file() and ROM.is_file()
    rom = ROM.read_bytes()
    assert rom[0x1B0:0x1B2] == b"RA"
    assert int.from_bytes(rom[0x1B4:0x1B8], "big") == 0x200001
    assert int.from_bytes(rom[0x1B8:0x1BC], "big") == 0x20FFFF
    with tempfile.TemporaryDirectory(prefix="bawang-sram-test-") as tmp:
        directory = Path(tmp)
        exe = directory / "BawangMac"
        shutil.copy2(EXE, exe)
        first = directory / "write.input"
        first.write_text("WAIT 2\nWRITE_RAM8 0x200001 0x5A\n"
                         "ASSERT_RAM8 0x200001 0x5A\nWAIT 60\nEXIT\n")
        log = run(exe, first)
        save = directory / "bawang_sanguozhi.srm"
        assert save.is_file() and save.stat().st_size == 0x10000, log[-3000:]
        assert save.read_bytes()[1] == 0x5A
        second = directory / "read.input"
        second.write_text("WAIT 2\nASSERT_RAM8 0x200001 0x5A\nEXIT\n")
        log = run(exe, second)
        assert "[SRAM] loaded 65536/65536 bytes" in log, log[-3000:]
    print("PASS 64 KiB always-visible SRAM write, disk flush, reload and read")
