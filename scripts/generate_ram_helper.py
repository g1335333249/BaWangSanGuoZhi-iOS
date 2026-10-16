#!/usr/bin/env python3
"""Generate the verified 0xFFF000 RAM helper from the user's local ROM.

Boot copies ten bytes at ROM 0x34e into WRAM 0xfff000. Only the decoded
MOVE.W d16(A5),(A4) x2 / RTS variant is accepted; other bytes fail closed.
"""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
rom = (ROOT / "input/bawang_sanguozhi.bin").read_bytes()
assert hashlib.sha256(rom).hexdigest() == "e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9"
blob = rom[0x34e:0x358]
assert len(blob) == 10
assert blob[0:2] == b"\x38\xad" and blob[4:6] == b"\x38\xad" and blob[8:10] == b"\x4e\x75"
disp1 = int.from_bytes(blob[2:4], "big", signed=True)
disp2 = int.from_bytes(blob[6:8], "big", signed=True)
bytes_c = ", ".join(f"0x{byte:02x}" for byte in blob)
out = ROOT / "games/bawang_sanguozhi/build/generated/bawang_ram_helper.c"
out.write_text(f'''/* AUTO-GENERATED from ROM 0x034e; do not edit. */
#include "genesis_runtime.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int bawang_ram_dispatch(uint32_t addr) {{
    if ((addr & 0xffffffu) != 0xfff000u) return 0;
    static const uint8_t source[10] = {{{bytes_c}}};
    if (memcmp(&g_ram[0xf000], source, sizeof source) != 0) {{
        fprintf(stderr, "[BAWANG][RAM] code bytes changed at $FFF000; static variant mismatch\\n");
        exit(2); /* never silently execute this code with the interpreter */
    }}
    /* $FFF000: MOVE.W {disp1}(A5),(A4) */
    uint16_t v = m68k_read16((uint32_t)(g_cpu.A[5] + (int32_t){disp1}));
    m68k_write16(g_cpu.A[4], v);
    g_cpu.SR = (g_cpu.SR & ~0x0fu) | (v == 0 ? 4u : 0u) | (v & 0x8000u ? 8u : 0u);
    g_native_insn_count++; g_cycle_accumulator += 16; g_audio_cycle_counter += 16;
    if (g_cycle_accumulator >= g_vblank_threshold) glue_check_vblank();
    GEN_COSIM_TICK(16);
    /* $FFF004: MOVE.W {disp2}(A5),(A4) */
    v = m68k_read16((uint32_t)(g_cpu.A[5] + (int32_t){disp2}));
    m68k_write16(g_cpu.A[4], v);
    g_cpu.SR = (g_cpu.SR & ~0x0fu) | (v == 0 ? 4u : 0u) | (v & 0x8000u ? 8u : 0u);
    g_native_insn_count++; g_cycle_accumulator += 16; g_audio_cycle_counter += 16;
    if (g_cycle_accumulator >= g_vblank_threshold) glue_check_vblank();
    GEN_COSIM_TICK(16);
    /* $FFF008: RTS */
    g_cpu.PC = m68k_read32(g_cpu.A[7]); g_cpu.A[7] += 4;
    g_native_insn_count++; g_cycle_accumulator += 16; g_audio_cycle_counter += 16;
    if (g_cycle_accumulator >= g_vblank_threshold) glue_check_vblank();
    GEN_COSIM_TICK(16);
    return 1;
}}
''')
print(f"generated {out.relative_to(ROOT)} from ROM $00034E: {blob.hex()}")
