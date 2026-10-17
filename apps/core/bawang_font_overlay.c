#include "bawang_font_overlay.h"
#include <string.h>

/* These are exact 16x16 monochrome glyphs from the fixed SHA256-verified
 * ROM. 32 bytes each: upper-left, upper-right, lower-left, lower-right 8x8.
 * Data strings and SRAM are not modified. No firmware font dependency. */
typedef struct FontEntry {
    size_t offset;
    const uint8_t *original;
    const uint8_t *simplified;
} FontEntry;

/* 劉 -> 刘, custom code and ROM offset corroborated by source string. */
static const uint8_t glyph_05b0c0_original[32] = {
    0x47, 0x82, 0x92, 0xF4, 0x1C, 0x22, 0x41, 0xBE,
    0xC2, 0x42, 0x52, 0x52, 0x92, 0x12, 0x12, 0x92,
    0x08, 0x7F, 0x49, 0x2A, 0x1C, 0xFF, 0x00, 0x00,
    0x12, 0x12, 0x02, 0x02, 0x0A, 0x84, 0x00, 0x00,
};
static const uint8_t glyph_05b0c0_simplified[32] = {
    0x04, 0x04, 0x3F, 0x3F, 0x13, 0x33, 0x1E, 0x0E,
    0x0C, 0x0C, 0x6C, 0x6C, 0x6C, 0x6C, 0x6C, 0x6C,
    0x06, 0x0F, 0x0F, 0x30, 0x20, 0x00, 0x00, 0x00,
    0x6C, 0x4C, 0x0C, 0x3C, 0x38, 0x00, 0x00, 0x00,
};

/* 備 -> 备, custom code and ROM offset corroborated by source string. */
static const uint8_t glyph_056356_original[32] = {
    0x21, 0x27, 0x41, 0xCF, 0x42, 0x47, 0x4A, 0x53,
    0x10, 0xFC, 0x10, 0xFE, 0x00, 0xFC, 0x44, 0xFC,
    0x42, 0x43, 0x42, 0x42, 0x44, 0x40, 0x00, 0x00,
    0x44, 0xFC, 0x44, 0x44, 0x54, 0x08, 0x00, 0x00,
};
static const uint8_t glyph_056356_simplified[32] = {
    0x00, 0x03, 0x0F, 0x3E, 0x37, 0x03, 0x3F, 0x1F,
    0x00, 0x00, 0xF0, 0x60, 0xC0, 0xC0, 0xFC, 0xF8,
    0x1F, 0x19, 0x1F, 0x18, 0x1F, 0x00, 0x00, 0x00,
    0xF8, 0xB8, 0xF8, 0x18, 0xF8, 0x00, 0x00, 0x00,
};

static const FontEntry entries[] = {
    {0x05B0C0u, glyph_05b0c0_original, glyph_05b0c0_simplified},
    {0x056356u, glyph_056356_original, glyph_056356_simplified},
};

int bawang_font_overlay_apply(uint8_t *rom, size_t rom_size, int simplified)
{
    if (!rom) return 0;
    /* Validate both glyphs before any write: failed verification must not
     * leave a half-patched ROM image. Accept either language as input so
     * switching traditional <-> simplified is symmetric. */
    for (size_t i = 0; i < sizeof(entries) / sizeof(entries[0]); ++i) {
        const FontEntry *entry = &entries[i];
        if (entry->offset > rom_size || rom_size - entry->offset < 32) return 0;
        const uint8_t *actual = rom + entry->offset;
        if (memcmp(actual, entry->original, 32) != 0 &&
            memcmp(actual, entry->simplified, 32) != 0) return 0;
    }
    for (size_t i = 0; i < sizeof(entries) / sizeof(entries[0]); ++i) {
        const FontEntry *entry = &entries[i];
        memcpy(rom + entry->offset,
               simplified ? entry->simplified : entry->original, 32);
    }
    return 1;
}
