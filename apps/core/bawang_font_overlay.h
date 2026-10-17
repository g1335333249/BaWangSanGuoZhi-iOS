#ifndef BAWANG_FONT_OVERLAY_H
#define BAWANG_FONT_OVERLAY_H
#include <stddef.h>
#include <stdint.h>

/* Applies two ROM glyph-only replacements to a mutable, already-verified BIN
 * memory image. 1=success, 0=invalid input or unexpected glyph bytes.
 * The function is reversible and refuses to write any unrelated ROM offset. */
int bawang_font_overlay_apply(uint8_t *rom, size_t rom_size, int simplified);
#endif
