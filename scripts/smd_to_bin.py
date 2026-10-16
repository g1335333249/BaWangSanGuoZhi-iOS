#!/usr/bin/env python3
"""Convert a 512-byte-headered, 16 KiB interleaved SMD ROM to raw BIN."""
import argparse
import hashlib
from pathlib import Path

EXPECTED_SHA256 = "e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9"


def convert(source: bytes) -> bytes:
    if len(source) < 512 or (len(source) - 512) % 16384:
        raise ValueError("SMD length must be 512 + a multiple of 16 KiB")
    result = bytearray(len(source) - 512)
    for start in range(512, len(source), 16384):
        block = source[start:start + 16384]
        offset = start - 512
        result[offset:offset + 16384:2] = block[8192:]
        result[offset + 1:offset + 16384:2] = block[:8192]
    return bytes(result)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    args = parser.parse_args()
    binary = convert(args.source.read_bytes())
    digest = hashlib.sha256(binary).hexdigest()
    if digest != EXPECTED_SHA256:
        raise SystemExit(f"ROM mismatch: {digest}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(binary)
    print(f"{args.output}: {len(binary)} bytes SHA256={digest}")


if __name__ == "__main__":
    main()
