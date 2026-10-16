#!/usr/bin/env python3
"""Exercise the original Yuan Shu command menu with compiled 68K code."""
from pathlib import Path
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "apps/macos/build/BawangMac"
ROM = ROOT / "input/bawang_sanguozhi.bin"
SCRIPT = ROOT / "tests/bawang_one_player_command_probe.input"
CAPTURES = ["bawang_yuanshu_info_category.png",
            "bawang_yuanshu_country_report.png"]


def run(interp):
    env = os.environ.copy()
    env["GENESIS_FLOOR"] = "0"  # a missing native entry must fail visibly
    env.pop("GENESIS_FORCE_INTERP", None)
    if interp:
        env["GENESIS_FORCE_INTERP"] = "1"
    result = subprocess.run(
        [str(EXE), str(ROM), "--benchmark", "23100", "--input-script", str(SCRIPT),
         "--hash-frames", "1000"], cwd=ROOT, env=env,
        capture_output=True, text=True, timeout=90)
    log = result.stdout + result.stderr
    assert result.returncode == 0 and "[DONE] 23100 frames completed" in log, log[-3000:]
    assert "0 raw miss events" in log and "0 unique true-miss addrs" in log, log[-3000:]
    assert all(any(line.startswith("[SCREENSHOT] wrote ") and line.endswith("/" + name)
                   for line in log.splitlines())
               for name in CAPTURES), log[-3000:]
    images = tuple((EXE.parent / name).read_bytes() for name in CAPTURES)
    assert all(image.startswith(b"\x89PNG\r\n\x1a\n") and len(image) > 1000
               for image in images)
    assert images[0] != images[1], "command input did not change the rendered game screen"
    hashes = dict(re.findall(r"\[FBHASH\] frame=(\d+) .* hash=(0x[0-9A-F]+)", log))
    return images, hashes["20000"]


if __name__ == "__main__":
    assert EXE.is_file() and ROM.is_file() and SCRIPT.is_file()
    native = run(False)
    assert native == run(False), "compiled path is not deterministic"
    interpreter = run(True)
    assert native == interpreter, "command menu or country report differs between CPUs"
    print("PASS Yuan Shu menu and 情報→他國 report: native/native and native/interp agree; "
          "0 dispatch misses, 0 interpreter fallbacks")
