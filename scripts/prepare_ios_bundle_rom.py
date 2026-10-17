#!/usr/bin/env python3
"""Stage a verified, locally held ROM as an optional Xcode bundle resource."""
import argparse
import hashlib
import os
from pathlib import Path

EXPECTED = "e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9"
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "apps/ios/BawangSanguozhi/Resources/bawang_sanguozhi.bin"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, nargs="?", help="verified standard BIN")
    parser.add_argument("--clear", action="store_true", help="remove optional bundled ROM")
    args = parser.parse_args()
    if args.clear:
        DEST.unlink(missing_ok=True)
        return
    if args.source is None:
        parser.error("source BIN is required unless --clear is specified")
    binary = args.source.read_bytes()
    if len(binary) != 0x100000 or hashlib.sha256(binary).hexdigest() != EXPECTED:
        parser.error("source ROM size or SHA256 does not match this game")
    DEST.parent.mkdir(parents=True, exist_ok=True)
    temporary = DEST.with_suffix(".bin.tmp")
    temporary.write_bytes(binary)
    os.replace(temporary, DEST)
    print(f"Staged verified optional app resource at {DEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
