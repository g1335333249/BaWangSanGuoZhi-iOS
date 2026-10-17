#!/usr/bin/env python3
"""Exercise the optional ROM staging policy without committing game data."""
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/prepare_ios_bundle_rom.py"
ROM = ROOT / "input/bawang_sanguozhi.bin"
DEST = ROOT / "apps/ios/BawangSanguozhi/Resources/bawang_sanguozhi.bin"
EXPECTED = "e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9"


def main() -> None:
    subprocess.run([sys.executable, str(SCRIPT), str(ROM)], check=True, cwd=ROOT)
    assert hashlib.sha256(DEST.read_bytes()).hexdigest() == EXPECTED
    invalid = ROOT / "apps/core/build-macos/invalid-rom.bin"
    invalid.parent.mkdir(parents=True, exist_ok=True)
    invalid.write_bytes(b"wrong ROM")
    result = subprocess.run([sys.executable, str(SCRIPT), str(invalid)], cwd=ROOT,
                            capture_output=True, text=True)
    assert result.returncode != 0
    assert hashlib.sha256(DEST.read_bytes()).hexdigest() == EXPECTED
    subprocess.run([sys.executable, str(SCRIPT), "--clear"], check=True, cwd=ROOT)
    assert not DEST.exists()
    print("PASS valid ROM staged, invalid ROM rejected, optional resource removed")


if __name__ == "__main__":
    main()
