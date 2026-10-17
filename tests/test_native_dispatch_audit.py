#!/usr/bin/env python3
"""Fast offline regression for the checked-in pointer audit and generated AOT map."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = root / "scripts/audit_native_dispatch.py"

with tempfile.TemporaryDirectory() as directory:
    prefix = Path(directory) / "audit"
    command = [sys.executable, str(script), "--output", str(prefix)]
    subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
    first = {suffix: prefix.with_suffix(suffix).read_bytes()
             for suffix in (".json", ".csv", ".md")}
    subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
    assert all(prefix.with_suffix(suffix).read_bytes() == data for suffix, data in first.items())
    report = json.loads(first[".json"])
    assert report["pointer_records"] == 291
    assert report["unique_targets"] == 142
    assert report["counts"] == {"AMBIGUOUS": 11, "COVERED": 131}
    for address in ("0x01FC7C", "0x01FED6", "0x01FF04", "0x020326", "0x0215F4"):
        entry = next(row for row in report["targets"] if row["address"] == address)
        assert entry["status"] == "COVERED", entry

print("PASS deterministic offline audit: 291 records, 142 targets, 131 covered, 11 ambiguous")
