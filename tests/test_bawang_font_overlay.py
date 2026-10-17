#!/usr/bin/env python3
"""Standalone (no Xcode/upstream) glyph overlay regression on the verified ROM."""
import argparse
import ctypes
import hashlib
import shutil
import subprocess
import tempfile
from pathlib import Path

EXPECTED = "e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9"
SLOTS = ((0x5B0C0, 32), (0x56356, 32))


def run(rom: Path, source: Path):
    assert shutil.which("cc"), "C compiler is required"
    original = rom.read_bytes()
    assert len(original) == 0x100000 and hashlib.sha256(original).hexdigest() == EXPECTED
    with tempfile.TemporaryDirectory(prefix="bawang-font-") as folder:
        so = Path(folder) / "libfont.so"
        subprocess.run(["cc", "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror",
                        "-shared", "-fPIC", str(source), "-o", str(so)], check=True)
        library = ctypes.CDLL(str(so))
        apply = library.bawang_font_overlay_apply
        apply.argtypes = (ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int)
        apply.restype = ctypes.c_int
        buf = ctypes.create_string_buffer(original, len(original))
        assert apply(buf, len(original), 1) == 1
        simplified = buf.raw
        changed = {i for i, (a,b) in enumerate(zip(original, simplified)) if a != b}
        allow = set().union(*(range(offset,offset+count) for offset,count in SLOTS))
        assert changed and changed.issubset(allow), "ROM bytes outside font slots were touched"
        assert len(changed) >= 24, "expected meaningful glyph changes"
        assert apply(buf, len(original), 1) == 1
        assert buf.raw == simplified, "applying same language must be idempotent"
        assert apply(buf, len(original), 0) == 1
        assert buf.raw == original, "switching back must exactly restore original ROM"
        assert apply(buf, len(original), 0) == 1
        assert buf.raw == original
        # Invalid input: transactional failure, no partial byte changes.
        broken = bytearray(original)
        broken[SLOTS[1][0]] ^= 0x20
        buf2 = ctypes.create_string_buffer(bytes(broken), len(broken))
        assert apply(buf2, len(broken), 1) == 0
        assert buf2.raw == broken, "verification failure mutated unrelated bytes"
        assert apply(buf, 0x5000, 1) == 0
        assert buf.raw == original
    print(f"PASS 2 glyphs, {len(changed)} modified bytes within two 32-byte slots; reversible; negative cases")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--rom", type=Path, default=Path("input/bawang_sanguozhi.bin"))
    p.add_argument("--source", type=Path, default=Path("apps/core/bawang_font_overlay.c"))
    a = p.parse_args()
    run(a.rom, a.source)
