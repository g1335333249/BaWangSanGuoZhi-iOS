#!/usr/bin/env python3
"""Verify the portable core's VDP/audio and interpreted-instruction meter."""
from pathlib import Path
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "apps/core/build-macos/BawangCoreSmoke"
ROM = ROOT / "input/bawang_sanguozhi.bin"


def run(force_interp=False):
    env = os.environ.copy()
    env.pop("GENESIS_FORCE_INTERP", None)
    if force_interp:
        env["GENESIS_FORCE_INTERP"] = "1"
    result = subprocess.run([str(EXE), str(ROM)], cwd=ROOT, env=env,
                            text=True, capture_output=True, timeout=90)
    output = result.stdout + result.stderr
    assert result.returncode == 0, output[-3000:]
    hashes = re.findall(r"frame (180|600) fnv64=([0-9A-F]{16})", output)
    metrics = re.search(r"audio_nonzero_samples=(\d+) raw_dispatch_misses=(\d+) "
                        r"interpreted_instructions=(\d+)", output)
    assert len(hashes) == 2 and metrics, output[-3000:]
    return hashes, tuple(int(v) for v in metrics.groups())


def main():
    native_hashes, (audio, misses, interpreted) = run()
    assert audio > 0 and misses == interpreted == 0
    oracle_hashes, (oracle_audio, oracle_misses, oracle_interpreted) = run(True)
    assert oracle_hashes == native_hashes
    assert oracle_audio == audio and oracle_misses == 0 and oracle_interpreted > 0
    print("PASS 600 real VDP/audio frames; native 0 interpreter instructions;")
    print(f"PASS diagnostic interpreter meter detects {oracle_interpreted} instructions")


if __name__ == "__main__":
    main()
