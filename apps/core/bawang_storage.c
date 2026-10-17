#include "bawang_core.h"
#include "netplay/genesis_netplay_identity.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const uint8_t expected_sha256[32] = {
    0xe7,0x0f,0x0a,0x92,0xc2,0x05,0xea,0x43,0x20,0x80,0xcc,0x48,0xc1,0x8d,0x1d,0x43,
    0xb7,0xfc,0x4d,0x45,0x46,0x4e,0xd7,0xfb,0x21,0x8b,0x11,0x90,0x96,0xe7,0xcd,0xd9
};

int bawang_rom_normalize(const uint8_t *source, size_t size,
                         uint8_t *bin, size_t capacity)
{
    if (!source || (size != BAWANG_ROM_SIZE && size != BAWANG_ROM_SIZE + 512))
        return 0;
    if (bin && capacity < BAWANG_ROM_SIZE) return 0;
    if (size == BAWANG_ROM_SIZE + 512 && !bin) return 0;
    const uint8_t *verified = source;
    if (size == BAWANG_ROM_SIZE + 512) {
        for (size_t block = 0; block < BAWANG_ROM_SIZE / 16384; ++block) {
            size_t from = 512 + block * 16384, to = block * 16384;
            for (size_t i = 0; i < 8192; ++i) {
                bin[to + 2*i] = source[from + 8192 + i];
                bin[to + 2*i + 1] = source[from + i];
            }
        }
        verified = bin;
    }
    uint8_t digest[32];
    genesis_identity_sha256(verified, BAWANG_ROM_SIZE, digest);
    if (memcmp(digest, expected_sha256, sizeof digest) != 0) return 0;
    if (bin && verified != bin) memcpy(bin, verified, BAWANG_ROM_SIZE);
    return 1;
}

static int read_exact(const char *path, uint8_t *dst, size_t size)
{
    if (!path || !dst) return 0;
    FILE *file = fopen(path, "rb");
    if (!file) return 0;
    int ok = fread(dst, 1, size, file) == size && fgetc(file) == EOF && !ferror(file);
    if (fclose(file) != 0) ok = 0;
    return ok;
}

static char *suffix_path(const char *path, const char *suffix)
{
    size_t n = strlen(path), m = strlen(suffix);
    char *result = malloc(n + m + 1);
    if (result) { memcpy(result, path, n); memcpy(result + n, suffix, m + 1); }
    return result;
}

static int write_atomic(const char *path, const uint8_t *bytes, size_t size)
{
    char *tmp = suffix_path(path, ".tmp");
    if (!tmp) return 0;
    FILE *file = fopen(tmp, "wb");
    int ok = file && fwrite(bytes, 1, size, file) == size;
    if (file && fclose(file) != 0) ok = 0;
    if (ok && rename(tmp, path) != 0) ok = 0;
    if (!ok) remove(tmp);
    free(tmp);
    return ok;
}

int bawang_rom_load_file(const char *path, uint8_t *bin, size_t capacity)
{
    if (!path || !bin || capacity < BAWANG_ROM_SIZE) return 0;
    FILE *file = fopen(path, "rb");
    if (!file) return 0;
    uint8_t *source = malloc(BAWANG_ROM_SIZE + 513);
    size_t count = source ? fread(source, 1, BAWANG_ROM_SIZE + 513, file) : 0;
    int ok = source && !ferror(file) &&
             (count == BAWANG_ROM_SIZE || count == BAWANG_ROM_SIZE + 512);
    /* Distinguish exact BIN/SMD lengths; reject trailing bytes. */
    if (fclose(file) != 0) ok = 0;
    if (ok) ok = bawang_rom_normalize(source, count, bin, capacity);
    free(source);
    return ok;
}

int bawang_rom_import_file(const char *source, const char *verified_bin_path)
{
    if (!verified_bin_path) return 0;
    uint8_t *bin = malloc(BAWANG_ROM_SIZE);
    if (!bin) return 0;
    int ok = bawang_rom_load_file(source, bin, BAWANG_ROM_SIZE);
    if (ok) ok = write_atomic(verified_bin_path, bin, BAWANG_ROM_SIZE);
    free(bin);
    return ok;
}

int bawang_sram_read_file(const char *path, uint8_t *dst, size_t capacity)
{
    if (!path || !dst || capacity < BAWANG_SRAM_SIZE) return 0;
    if (read_exact(path, dst, BAWANG_SRAM_SIZE)) return 1;
    char *backup = suffix_path(path, ".bak");
    int ok = backup && read_exact(backup, dst, BAWANG_SRAM_SIZE);
    free(backup);
    return ok;
}

int bawang_sram_write_file(const char *path, const uint8_t *bytes, size_t size)
{
    if (!path || !bytes || size != BAWANG_SRAM_SIZE) return 0;
    uint8_t *old = malloc(BAWANG_SRAM_SIZE);
    if (!old) return 0;
    if (read_exact(path, old, BAWANG_SRAM_SIZE)) {
        char *backup = suffix_path(path, ".bak");
        int backed_up = backup && write_atomic(backup, old, BAWANG_SRAM_SIZE);
        free(backup);
        if (!backed_up) { free(old); return 0; }
    }
    free(old);
    return write_atomic(path, bytes, size);
}
