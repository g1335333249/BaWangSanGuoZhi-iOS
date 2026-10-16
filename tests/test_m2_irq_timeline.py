#!/usr/bin/env python3
"""Compare V-int delivery on the scheduler's hardware time axis."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "apps/macos/build-cosim/BawangMac_cosim"
ROM = ROOT / "input/bawang_sanguozhi.bin"
SCRIPT = ROOT / "tests/bawang_one_player_long_probe.input"


def run(interp):
    env = os.environ.copy()
    env.update(GENESIS_M2_IRQ_TRACE_START_FRAME="13262",
               GENESIS_M2_IRQ_TRACE_END_FRAME="13264",
               GENESIS_COSIM_START_FRAME="20000", GENESIS_FLOOR="0")
    env.pop("GENESIS_FORCE_INTERP", None)
    if interp:
        env["GENESIS_FORCE_INTERP"] = "1"
    result = subprocess.run(
        [str(EXE), str(ROM), "--benchmark", "13265", "--input-script", str(SCRIPT)],
        cwd=ROOT, env=env, capture_output=True, text=True, timeout=90)
    log = result.stdout + result.stderr
    assert result.returncode == 0 and "[DONE] 13265 frames completed" in log, log[-3000:]
    rows = [line.split("\t") for line in log.splitlines()
            if line.startswith("[M2IRQ]\t")]
    assert rows, "opt-in IRQ trace emitted no events"
    assert not any(row[1] == "fiber_yield" and row[11] == "5" for row in rows), \
        "unexpected IRQ-poll yield (formerly emitted in the $004E96 data scan)"
    # g_cpu.PC is a block entry in compiled C, while interpreter PC is the
    # next instruction. Compare hardware time, diagnostic instruction time,
    # budget, architectural SR/A7 and game flags at the same IRQ event.
    fields = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 17, 20, 21, 22, 23)
    events = [tuple(row[n] for n in fields) for row in rows
              if row[1] in ("vint_assert", "vint_accept", "vint_entry",
                            "vint_body_exit", "vint_restore",
                            "wait_938_enter", "wait_938_resume")]
    accepts = [row for row in rows if row[1] == "vint_accept"]
    assert [(row[2], row[3]) for row in accepts] == \
        [(str(frame), "224") for frame in range(13262, 13265)]
    return events


if __name__ == "__main__":
    assert EXE.is_file() and ROM.is_file() and SCRIPT.is_file()
    native = run(False)
    interp = run(True)
    assert native == interp, next(((a, b) for a, b in zip(native, interp)
                                   if a != b), (len(native), len(interp)))
    print(f"PASS V-int hardware timeline: {len(native)} matching events, frames 13262-13264")
