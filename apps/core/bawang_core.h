#ifndef BAWANG_CORE_H
#define BAWANG_CORE_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

enum { BAWANG_ROM_SIZE = 0x100000, BAWANG_SRAM_SIZE = 0x10000,
       BAWANG_VIDEO_WIDTH = 320, BAWANG_VIDEO_HEIGHT = 224 };
enum { BAWANG_PAD_UP = 0x01, BAWANG_PAD_DOWN = 0x02,
       BAWANG_PAD_LEFT = 0x04, BAWANG_PAD_RIGHT = 0x08,
       BAWANG_PAD_B = 0x10, BAWANG_PAD_C = 0x20,
       BAWANG_PAD_A = 0x40, BAWANG_PAD_START = 0x80 };
/* Shared resource API: BIN or headered SMD input; output is verified BIN. */
int bawang_rom_normalize(const uint8_t *source, size_t size,
                         uint8_t *bin, size_t capacity);
int bawang_rom_import_file(const char *source, const char *verified_bin_path);
int bawang_rom_load_file(const char *path, uint8_t *bin, size_t capacity);
/* File path is supplied by the platform; format/atomicity are core-owned. */
int bawang_sram_read_file(const char *path, uint8_t *dst, size_t capacity);
int bawang_sram_write_file(const char *path, const uint8_t *bytes, size_t size);
int bawang_core_save_sram_file(const char *path);
/* 0=error, 1=unchanged, 2=saved. */
int bawang_core_save_sram_if_changed(const char *path);
/* The caller owns platform file locations. No executable data is downloaded or JITed. */
int bawang_core_start(const uint8_t *rom, size_t rom_size,
                      const uint8_t *sram, size_t sram_size);
int bawang_core_start_file(const char *rom_path, const char *sram_path);
/* Language switches replace only two glyphs in the in-memory ROM copy.
 * The selected mode is also applied when the next game session starts.
 * Already-uploaded VDP tiles update when the game redraws the text. */
void bawang_core_set_simplified(int enabled);
void bawang_core_stop(void);
/* In-process fast checkpoints; NEVER deserialize these after restart. */
size_t bawang_core_checkpoint_bound(void);
size_t bawang_core_checkpoint_save(void *dst, size_t capacity);
int bawang_core_checkpoint_load(const void *data, size_t length);
/* Guest-state digest for replay verification (0 = unavailable). */
uint64_t bawang_core_state_fingerprint(void);

int bawang_core_frame(uint16_t buttons, uint32_t *argb, size_t stride_pixels);
/* 48 kHz interleaved stereo PCM for the most recent frame; caller owns copy. */
size_t bawang_core_audio(int16_t *dst, size_t capacity_frames);
size_t bawang_core_sram(uint8_t *dst, size_t capacity);
uint64_t bawang_core_native_instructions(void);
uint64_t bawang_core_interpreted_instructions(void);
uint64_t bawang_core_frames(void);
uint64_t bawang_core_raw_dispatch_misses(void);
int bawang_core_width(void);

#ifdef __cplusplus
}
#endif

#endif
