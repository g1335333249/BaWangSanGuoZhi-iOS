#include "game_spec.h"
#include "genesis_runtime.h"
#include <stdio.h>
#include <stdlib.h>
extern int bawang_ram_dispatch(uint32_t addr);

static int bawang_dispatch_override(uint32_t addr) {
    if (addr < 0xff0000u) return 0;
    if (bawang_ram_dispatch(addr)) return 1;
    fprintf(stderr, "[BAWANG][RAM] no static translation for $%06X\n", addr & 0xffffffu);
    exit(2);
}

static void bawang_entry(void) {
    recomp_call_addr(0x000200u);
    fprintf(stderr, "[BAWANG] entry returned PC=%06X A7=%08X A6=%08X SR=%04X D0=%08X A0=%08X native=%llu rte=%d\n",
            g_cpu.PC & 0xFFFFFFu, g_cpu.A[7], g_cpu.A[6], g_cpu.SR, g_cpu.D[0], g_cpu.A[0],
            (unsigned long long)g_native_insn_count, g_rte_pending);
}
static void bawang_vblank(void) { recomp_call_addr(0x001130u); }
static void bawang_hblank(void) { recomp_call_addr(0x00112Cu); }

const GameSpec g_game_spec = {
    .display_name = "霸王三国志",
    .short_name = "BawangSanguozhi",
    .expected_rom_crc32 = 0xBF7CEBE7u,
    .expected_rom_size = 0x100000u,
    .tier3_floor_default = 0,
    .dispatch_override = bawang_dispatch_override,
    .call_entry_point = bawang_entry,
    .call_vblank = bawang_vblank,
    .call_hblank = bawang_hblank,
};
