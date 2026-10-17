#include "bawang_core.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char *exe_relative(const char *name) { return name; }

int main(int argc, char **argv)
{
    if (argc != 4) return 2;
    uint8_t *bin = malloc(BAWANG_ROM_SIZE), *smd = malloc(BAWANG_ROM_SIZE),
            *saved = malloc(BAWANG_SRAM_SIZE), *readback = malloc(BAWANG_SRAM_SIZE);
    if (!bin || !smd || !saved || !readback) return 2;
    if (!bawang_rom_load_file(argv[1], bin, BAWANG_ROM_SIZE) ||
        !bawang_rom_load_file(argv[2], smd, BAWANG_ROM_SIZE) ||
        memcmp(bin, smd, BAWANG_ROM_SIZE) != 0) return 3;
    if (!bawang_rom_import_file(argv[2], argv[3]) ||
        !bawang_rom_load_file(argv[3], smd, BAWANG_ROM_SIZE) ||
        memcmp(bin, smd, BAWANG_ROM_SIZE) != 0) return 4;
    smd[100] ^= 1;
    if (bawang_rom_normalize(smd, BAWANG_ROM_SIZE, NULL, 0)) return 5;
    for (size_t i = 0; i < BAWANG_SRAM_SIZE; ++i) saved[i] = (uint8_t)(i * 37 + 11);
    if (!bawang_sram_write_file(argv[3], saved, BAWANG_SRAM_SIZE) ||
        !bawang_sram_read_file(argv[3], readback, BAWANG_SRAM_SIZE) ||
        memcmp(saved, readback, BAWANG_SRAM_SIZE) != 0) return 6;
    memset(saved, 0x5a, BAWANG_SRAM_SIZE);
    if (!bawang_sram_write_file(argv[3], saved, BAWANG_SRAM_SIZE) ||
        !bawang_sram_read_file(argv[3], readback, BAWANG_SRAM_SIZE) ||
        memcmp(saved, readback, BAWANG_SRAM_SIZE) != 0) return 7;
    FILE *bad = fopen(argv[3], "wb");
    if (!bad || fputc(0, bad) == EOF || fclose(bad) != 0) return 8;
    if (!bawang_sram_read_file(argv[3], readback, BAWANG_SRAM_SIZE) ||
        readback[0] != 11 || readback[1] != 48) return 9;
    free(bin); free(smd); free(saved); free(readback);
    puts("PASS shared C ROM/SMD SHA256, file import, SRAM atomic write and backup recovery");
    return 0;
}
