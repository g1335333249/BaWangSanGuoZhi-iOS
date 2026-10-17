#include "bawang_core.h"
#include "bawang_font_overlay.h"
#include <stdatomic.h>
#include "glue.h"
#include "m68k_interp.h"
#include "genesis_runtime.h"
#include "sim_step.h"
#include "audio/mixer.h"
#include "video/genesis_bus.h"
#include "video/genesis_machine.h"
#include "genesis_clocks.h"
#include "rb_state.h"
#include <stdlib.h>
#include <string.h>

static int running;
static _Atomic int requested_simplified;
static int applied_simplified;
/* Source ROM stays unchanged; glue_init copies verified bytes to g_rom. */
extern uint8_t g_rom[0x400000];

void bawang_core_set_simplified(int enabled)
{
    atomic_store(&requested_simplified, enabled ? 1 : 0);
}

static uint8_t saved_sram[BAWANG_SRAM_SIZE];
static int frame_width = 256;
static int16_t fm_frame[4096 * 2];
static int16_t psg_frame[16384];
static int16_t pcm_frame[1024 * 2];
static size_t pcm_count;
static uint64_t pcm_phase;
extern uint64_t glue_miss_count_any(void);

int bawang_core_start(const uint8_t *rom, size_t rom_size,
                      const uint8_t *sram, size_t sram_size)
{
    if (running || !rom || rom_size != BAWANG_ROM_SIZE) return 0;
    g_m68ki_total_insn_count = 0;
    if (!bawang_rom_normalize(rom, rom_size, NULL, 0)) return 0;
    machine_init();
    glue_init(rom, (cc_u32l)rom_size);
    /* Apply glyph-only overlay AFTER original ROM verification and copy,
     * but BEFORE the first game frame. No ROM file/SRAM writes. */
    int language = atomic_load(&requested_simplified);
    if (!bawang_font_overlay_apply(g_rom, BAWANG_ROM_SIZE, language)) {
        glue_shutdown();
        return 0;
    }
    applied_simplified = language;
    audio_mixer_init();
    gbus_sram_setup(&g_machine.bus);
    if (gbus_sram_size(&g_machine.bus) != 0x10000u) return 0;
    if (sram && sram_size == gbus_sram_size(&g_machine.bus))
        memcpy(gbus_sram_buffer(&g_machine.bus), sram, sram_size);
    memcpy(saved_sram, gbus_sram_buffer(&g_machine.bus), BAWANG_SRAM_SIZE);
    pcm_count = 0;
    pcm_phase = 0;
    running = 1;
    return 1;
}

int bawang_core_start_file(const char *rom_path, const char *sram_path)
{
    uint8_t *rom = malloc(BAWANG_ROM_SIZE);
    uint8_t *sram = malloc(BAWANG_SRAM_SIZE);
    if (!rom || !sram) { free(rom); free(sram); return 0; }
    int ok = bawang_rom_load_file(rom_path, rom, BAWANG_ROM_SIZE);
    int have_save = sram_path && bawang_sram_read_file(sram_path, sram, BAWANG_SRAM_SIZE);
    if (ok) ok = bawang_core_start(rom, BAWANG_ROM_SIZE,
                                   have_save ? sram : NULL,
                                   have_save ? BAWANG_SRAM_SIZE : 0);
    free(rom);
    free(sram);
    return ok;
}

int bawang_core_save_sram_file(const char *path)
{
    if (!running || !path) return 0;
    if (!bawang_sram_write_file(path, gbus_sram_buffer(&g_machine.bus),
                                gbus_sram_size(&g_machine.bus))) return 0;
    memcpy(saved_sram, gbus_sram_buffer(&g_machine.bus), BAWANG_SRAM_SIZE);
    return 1;
}

int bawang_core_save_sram_if_changed(const char *path)
{
    if (!running || !path) return 0;
    if (memcmp(saved_sram, gbus_sram_buffer(&g_machine.bus), BAWANG_SRAM_SIZE) == 0)
        return 1;
    return bawang_core_save_sram_file(path) ? 2 : 0;
}

void bawang_core_stop(void)
{
    if (!running) return;
    glue_shutdown();
    running = 0;
}

typedef struct FrameSink { uint32_t *pixels; size_t stride; int width; } FrameSink;
static void receive_scanline(void *ctx, int line, const uint32_t *argb, int width)
{
    FrameSink *sink = (FrameSink *)ctx;
    if (line < 0 || line >= 224 || width < 0 || width > 320) return;
    memcpy(sink->pixels + (size_t)line * sink->stride, argb,
           (size_t)width * sizeof(uint32_t));
    if (width > sink->width) sink->width = width;
}

int bawang_core_frame(uint16_t buttons, uint32_t *argb, size_t stride_pixels)
{
    if (!running || !argb || stride_pixels < 320) return 0;
    /* UI may select language while a game runs. Apply at the safe frame
     * boundary rather than from the UI callback while the CPU reads ROM. */
    int language = atomic_load(&requested_simplified);
    if (language != applied_simplified) {
        if (!bawang_font_overlay_apply(g_rom, BAWANG_ROM_SIZE, language)) return 0;
        applied_simplified = language;
    }
    memset(argb, 0, stride_pixels * 224u * sizeof(uint32_t));
    FrameSink sink = { argb, stride_pixels, 0 };
    GenesisSimInput input = {0};
    input.pad[0] = buttons;
    input.human_mask = 1;
    GenesisSimHooks hooks = {0};
    hooks.sink = receive_scanline;
    hooks.sink_user = &sink;
    size_t fm_count = 0, psg_count = 0;
    GenesisSimAudio audio = { fm_frame, 4096, &fm_count,
                              psg_frame, 16384, &psg_count };
    int ok = genesis_sim_step(&input, &audio, &hooks);
    /* Keep output cadence tied to the machine's NTSC master clock. The
     * runtime produces FM/PSG at different chip sample rates; both are
     * resampled to one host frame before the iOS audio device sees them. */
    pcm_phase += 48000ull * 895780ull;
    pcm_count = (size_t)(pcm_phase / GENESIS_MASTER_CLOCK_NTSC);
    pcm_phase %= GENESIS_MASTER_CLOCK_NTSC;
    if (pcm_count > 1024) pcm_count = 1024;
    for (size_t i = 0; i < pcm_count; ++i) {
        size_t fi = fm_count ? i * fm_count / pcm_count : 0;
        size_t pi = psg_count ? i * psg_count / pcm_count : 0;
        int psg = psg_count ? psg_frame[pi] : 0;
        for (size_t ch = 0; ch < 2; ++ch) {
            int fm = fm_count ? fm_frame[fi * 2 + ch] : 0;
            int mixed = fm + psg / 2;
            if (mixed > 32767) mixed = 32767;
            if (mixed < -32768) mixed = -32768;
            pcm_frame[i * 2 + ch] = (int16_t)mixed;
        }
    }
    if (sink.width) frame_width = sink.width;
    return ok;
}

size_t bawang_core_audio(int16_t *dst, size_t capacity_frames)
{
    if (!running || !dst || capacity_frames < pcm_count) return 0;
    memcpy(dst, pcm_frame, pcm_count * 2 * sizeof(int16_t));
    return pcm_count;
}

size_t bawang_core_sram(uint8_t *dst, size_t capacity)
{
    size_t size = gbus_sram_size(&g_machine.bus);
    if (!running || !dst || capacity < size) return 0;
    memcpy(dst, gbus_sram_buffer(&g_machine.bus), size);
    return size;
}

uint64_t bawang_core_native_instructions(void) { return g_native_insn_count; }
uint64_t bawang_core_interpreted_instructions(void) { return g_m68ki_total_insn_count; }
uint64_t bawang_core_frames(void) { return g_frame_count; }
uint64_t bawang_core_raw_dispatch_misses(void) { return glue_miss_count_any(); }
int bawang_core_width(void) { return frame_width; }

/* Save-state fast path: valid only while the SAME game fiber remains alive.
 * In particular, NEVER persist these exec/stack bytes and load them after an
 * app restart: they contain native host pointers. Disk persistence is handled
 * separately using verified deterministic input replay. */
size_t bawang_core_checkpoint_bound(void)
{
    return running ? genesis_rb_bound() : 0;
}
size_t bawang_core_checkpoint_save(void *dst, size_t capacity)
{
    if (!running || !dst) return 0;
    return genesis_rb_save(dst, capacity);
}
int bawang_core_checkpoint_load(const void *data, size_t length)
{
    if (!running || !data || !length) return 0;
    if (!genesis_rb_load(data, length)) return 0;
    pcm_count = 0;
    pcm_phase = 0;
    return 1;
}

/* Stable *guest* state fingerprint for cross-process replay validation.
 * Exclude exec (host process address dependent) and the host output buffers.
 * The reference includes guest CPU, RAM, VDP, bus/SRAM, Z80 and audio chips.
 * This is a consistency check, not a substitute for a runtime correctness test. */
uint64_t bawang_core_state_fingerprint(void)
{
    if (!running) return 0;
    GenesisRbDigest digest;
    genesis_rb_digest(&digest);
    static const int guest_parts[] = {
        GENESIS_RB_PART_CPU, GENESIS_RB_PART_RAM, GENESIS_RB_PART_VDP,
        GENESIS_RB_PART_BUS, GENESIS_RB_PART_Z80,
        GENESIS_RB_PART_FM, GENESIS_RB_PART_PSG
    };
    uint64_t h = UINT64_C(0xcbf29ce484222325);
    for (size_t i = 0; i < sizeof(guest_parts) / sizeof(guest_parts[0]); i++) {
        uint64_t v = digest.part[guest_parts[i]];
        for (int byte = 0; byte < 8; byte++) {
            h ^= (uint8_t)(v >> (8 * byte));
            h *= UINT64_C(0x100000001b3);
        }
    }
    return h;
}
