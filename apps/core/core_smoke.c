#include "bawang_core.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

/* Diagnostic host path. The iOS host supplies its own sandbox location. */
const char *exe_relative(const char *name)
{
    static char path[1024];
    snprintf(path, sizeof(path), "apps/core/build-macos/%s", name);
    return path;
}

int main(int argc, char **argv)
{
    if (argc != 2 && argc != 3) return 2;
    FILE *file = fopen(argv[1], "rb");
    if (!file) return 2;
    uint8_t *rom = malloc(0x100000u);
    if (!rom || fread(rom, 1, 0x100000u, file) != 0x100000u) return 2;
    fclose(file);
    if (!bawang_core_start(rom, 0x100000u, NULL, 0)) return 3;
    uint32_t *pixels = calloc(320u * 240u, sizeof(uint32_t));
    if (!pixels) return 3;
    int16_t sound[1024 * 2];
    size_t nonzero_audio_samples = 0;
    for (int i = 0; i < 600; ++i) {
        if (!bawang_core_frame(0, pixels, 320)) return 4;
        size_t audio_frames = bawang_core_audio(sound, 1024);
        if (audio_frames < 790 || audio_frames > 810) return 6;
        for (size_t j = 0; j < audio_frames * 2; ++j)
            nonzero_audio_samples += sound[j] != 0;
        if (i == 179 || i == 599) {
            uint64_t hash = 0xcbf29ce484222325ULL;
            for (size_t j = 0; j < 320u * 224u; ++j) {
                hash ^= pixels[j]; hash *= 0x100000001b3ULL;
            }
            printf("frame %d fnv64=%016llX native=%llu\n", i + 1,
                   (unsigned long long)hash,
                   (unsigned long long)bawang_core_native_instructions());
        }
    }
    printf("audio_nonzero_samples=%zu raw_dispatch_misses=%llu interpreted_instructions=%llu\n",
           nonzero_audio_samples,
           (unsigned long long)bawang_core_raw_dispatch_misses(),
           (unsigned long long)bawang_core_interpreted_instructions());
    if (argc == 3) {
        FILE *image = fopen(argv[2], "wb");
        if (!image) return 5;
        fprintf(image, "P6\n320 224\n255\n");
        for (size_t j = 0; j < 320u * 224u; ++j) {
            uint32_t pixel = pixels[j];
            fputc((pixel >> 16) & 255, image);
            fputc((pixel >> 8) & 255, image);
            fputc(pixel & 255, image);
        }
        fclose(image);
    }
    bawang_core_stop();
    free(pixels);
    free(rom);
    return 0;
}
