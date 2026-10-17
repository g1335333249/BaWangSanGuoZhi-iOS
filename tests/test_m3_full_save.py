#!/usr/bin/env python3
"""Full Yuan Shu 開發 -> February -> original save -> restart -> load."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT / "input/bawang_sanguozhi.bin"


def run(exe, script, extra, timeout=1200):
    env = os.environ.copy()
    env.update(GENESIS_FLOOR="0", SDL_VIDEODRIVER="dummy",
               SDL_AUDIODRIVER="dummy")
    result = subprocess.run([str(exe), str(ROM), *extra, "--input-script",
                             str(ROOT / "tests" / script)], cwd=ROOT,
                            env=env, text=True, capture_output=True,
                            timeout=timeout)
    output = result.stdout + result.stderr
    assert result.returncode == 0, output[-4000:]
    if "--benchmark" in extra:
        assert "0 unique true-miss addrs, 0 raw miss events" in output
    return output


def main():
    with tempfile.TemporaryDirectory(prefix="m3_full_save_", dir=ROOT / "apps/macos/build") as tmp:
        exe = Path(tmp) / "BawangMac"
        shutil.copy2(ROOT / "apps/macos/build/BawangMac", exe)
        output = run(exe, "bawang_m3_full_save.input", ("--no-launcher", "--turbo"))
        assert "[SRAM] flushed 65536 bytes" in output
        saved_ram = (Path(tmp) / "m3_develop_month_ram.bin").read_bytes()
        assert saved_ram[0x100C] == 1
        assert int.from_bytes(saved_ram[0x2942:0x2944], "big") == 900
        sram = (Path(tmp) / "bawang_sanguozhi.srm").read_bytes()
        assert len(sram) == 65536 and sum(v != 0 for v in sram) > 4000
        print("PASS original February save after 開發, 64 KiB SRAM persisted")

        output = run(exe, "bawang_m3_load_saved.input", ("--benchmark", "10500"))
        assert "[SRAM] loaded 65536/65536 bytes" in output
        restored = (Path(tmp) / "m3_load_later_ram.bin").read_bytes()
        assert restored[0x100C] == 1
        assert int.from_bytes(restored[0x2942:0x2944], "big") == 900
        print("PASS original game loaded February and retained 900 gold")


if __name__ == "__main__":
    main()
