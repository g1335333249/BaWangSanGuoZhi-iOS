#!/usr/bin/env python3
"""Verify that the generator patches apply in bootstrap order to a clean file."""

from pathlib import Path
import subprocess
import tempfile


root = Path(__file__).resolve().parents[1]
core = root / "third_party/segagenesisrecomp/external/m68k-recomp-core"
source = Path("profiles/genesis/code_generator.c")

with tempfile.TemporaryDirectory() as directory:
    checkout = Path(directory)
    target = checkout / source
    target.parent.mkdir(parents=True)
    target.write_bytes(
        subprocess.check_output(["git", "-C", str(core), "show", f"HEAD:{source}"])
    )
    for name in ("m68k-rtr-return.patch", "m68k-m2-codegen.patch"):
        patch = root / "scripts/patches" / name
        subprocess.run(["git", "-C", str(checkout), "apply", "--check", str(patch)], check=True)
        subprocess.run(["git", "-C", str(checkout), "apply", str(patch)], check=True)
    assert target.read_bytes() == (core / source).read_bytes(), "unexpected generator patch result"

print("PASS clean RTR then M2 generator patch application")
